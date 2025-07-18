#!/bin/bash
set -e

VM_NAME="openstack_default"
ARCH=$(uname -m)
OS=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

echo "[INFO] Architecture: $ARCH"
echo "[INFO] Operating System: $OS"

######################################
# 1. Install system dependencies
######################################

echo "[CI] Installing system dependencies..."

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt-get update -y
    sudo apt-get install -y curl gnupg2 software-properties-common

    if [[ "$ARCH" == "x86_64" ]]; then
        QEMU_PKGS="qemu-system-x86 qemu-utils"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        QEMU_PKGS="qemu-system-arm qemu-utils"
    else
        echo "[ERROR] Unsupported architecture: $ARCH"
        exit 1
    fi

    sudo apt-get install -y $QEMU_PKGS \
        libvirt-daemon-system libvirt-clients bridge-utils virtinst \
        libvirt-dev libxslt1-dev libxml2-dev zlib1g-dev ruby-dev build-essential

    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        sudo apt-get install -y cpu-checker || true
        if command -v kvm-ok >/dev/null && ! kvm-ok 2>/dev/null | grep -q 'can be used'; then
            echo "[WARN] KVM not supported on this hardware."
        fi
    fi

    PROVIDER="libvirt"
    sudo systemctl enable --now libvirtd

elif [[ "$OS" == "rhel" || "$OS" == "centos" || "$OS" == "fedora" ]]; then
    sudo dnf install -y curl
    sudo dnf install -y @virtualization libvirt libvirt-devel virt-install qemu-kvm \
        libxslt-devel libxml2-devel zlib-devel ruby-devel make gcc

    PROVIDER="libvirt"
    sudo systemctl enable --now libvirtd
else
    echo "[ERROR] Unsupported OS: $OS"
    exit 1
fi

######################################
# 2. Install Vagrant if needed
######################################

if ! command -v vagrant >/dev/null 2>&1; then
    echo "[CI] Installing Vagrant..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update -y
    sudo apt-get install -y vagrant
else
    echo "[CI] Vagrant is already installed."
fi

######################################
# 3. Ensure libvirt group membership
######################################

if ! id | grep -q libvirt; then
    echo "[CI] Adding user to 'libvirt' group..."
    sudo usermod -aG libvirt "$USER"
    echo "[CI] Re-executing script with libvirt group using sg..."
    exec sg libvirt "$0"
fi

######################################
# 4. Install Vagrant plugin
######################################

if ! vagrant plugin list | grep -q vagrant-libvirt; then
    echo "[CI] Installing vagrant-libvirt plugin..."
    vagrant plugin install vagrant-libvirt
else
    echo "[CI] vagrant-libvirt plugin already installed."
fi

######################################
# 5. Handle stale VM conflicts
######################################

echo "[CI] Checking for existing VM conflicts..."
if sudo virsh dominfo "$VM_NAME" > /dev/null 2>&1; then
    echo "[CI] Existing VM '$VM_NAME' found. Cleaning up..."
    sudo virsh destroy "$VM_NAME" > /dev/null 2>&1 || true
    sudo virsh undefine "$VM_NAME" --remove-all-storage > /dev/null 2>&1 || true
fi

######################################
# 6. Start VM and handle NFS mount errors
######################################

echo "[CI] Starting Vagrant VM with provider: $PROVIDER..."
if ! vagrant up --provider="$PROVIDER" 2>vagrant_error.log; then
    echo "[ERROR] VM failed to start. Checking for NFS mount issues..."

    if grep -q "requested NFS version on transport protocol is not supported" vagrant_error.log; then
        echo "[INFO] NFS version/transport error detected. Retrying with fallback..."
        echo "[ACTION] You may need to modify your Vagrantfile to use: nfs_version: 4 and protocol: tcp"
        echo "[INFO] Example:"
        echo "  config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: 4, nfs_udp: false"

        echo "[RETRYING] Attempting another 'vagrant up' after a brief delay..."
        sleep 5
        if ! vagrant up --provider="$PROVIDER"; then
            echo "[FAIL] Retry also failed. Check your NFS server config or fallback to rsync/smb shared folder."
            exit 1
        fi
    else
        echo "[ERROR] Vagrant up failed for another reason:"
        cat vagrant_error.log
        exit 1
    fi
fi

######################################
# 7. Get VM IP
######################################

echo "[CI] Retrieving VM IP address..."
VM_IP=$(vagrant ssh -c "hostname -I | awk '{print \$1}'" 2>/dev/null | tr -d '\r')

if [[ -z "$VM_IP" ]]; then
    echo "[ERROR] Could not retrieve VM IP."
    vagrant destroy -f
    exit 1
fi

echo "[CI] VM IP: $VM_IP"

######################################
# 8. Check Keystone API
######################################

echo "[CI] Checking Keystone API at $VM_IP..."
if ! curl -sf --connect-timeout 5 "http://$VM_IP:5000/v3/" | grep -q "identity"; then
    echo "❌ Keystone API not responding. Attempting VM reboot..."
    vagrant reload
    sleep 10
    VM_IP=$(vagrant ssh -c "hostname -I | awk '{print \$1}'" 2>/dev/null | tr -d '\r')
    echo "[RETRY] VM IP: $VM_IP"

    if ! curl -sf --connect-timeout 5 "http://$VM_IP:5000/v3/" | grep -q "identity"; then
        echo "❌ Still no response. Destroying VM and exiting."
        vagrant destroy -f
        exit 1
    fi
else
    echo "✅ Keystone API is working."
fi

######################################
# 9. Cleanup
######################################

echo "[CI] Cleaning up Vagrant VM..."
vagrant destroy -f
