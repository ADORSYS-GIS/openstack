#!/bin/sh

# 1. Detect architecture and OS
ARCH=$(uname -m)
OS=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

echo "[INFO] Architecture: $ARCH"
echo "[INFO] Operating System: $OS"

# 2. Install dependencies
echo "[CI] Installing system dependencies..."

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    sudo apt-get update -y
    sudo apt-get install -y curl gnupg2 software-properties-common

    # Install comprehensive QEMU packages for multi-architecture support
    # This ensures that an x86_64 host can emulate ARM and vice-versa.
    echo "[INFO] Installing QEMU system emulators for multi-architecture support..."
    sudo apt-get install -y \
        qemu-system-x86 \
        qemu-system-arm \
        qemu-system-aarch64 \
        qemu-utils \
        libvirt-daemon-system libvirt-clients bridge-utils virtinst \
        libvirt-dev libxslt1-dev libxml2-dev zlib1g-dev ruby-dev build-essential \
        cpu-checker # Install cpu-checker unconditionally for KVM check

    PROVIDER="libvirt"
    sudo systemctl enable --now libvirtd

elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
    sudo dnf install -y curl

    # Install comprehensive QEMU packages for multi-architecture support
    echo "[INFO] Installing QEMU system emulators for multi-architecture support..."
    sudo dnf install -y @virtualization libvirt libvirt-devel virt-install \
        qemu-kvm qemu-system-x86 qemu-system-arm qemu-system-aarch64 \
        libxslt-devel libxml2-devel zlib-devel ruby-devel make gcc

    PROVIDER="libvirt"
    sudo systemctl enable --now libvirtd
else
    echo "[ERROR] Unsupported OS: $OS"
    exit 1
fi

# Universal KVM check (relevant for any host architecture that might use KVM)
echo "[INFO] Verifying KVM support for host architecture ($ARCH)..."
if command -v kvm-ok >/dev/null 2>&1; then
    if ! kvm-ok 2>/dev/null | grep -q 'can be used'; then
        echo "[WARN] KVM acceleration is NOT enabled on this host ($ARCH)."
        echo "[WARN] Virtual machines will run in emulation mode and will be significantly slower."
        echo "[WARN] Please ensure virtualization is enabled in your system's BIOS/UEFI settings."
    else
        echo "✅ KVM acceleration can be used on this host ($ARCH)."
    fi
else
    echo "[INFO] 'kvm-ok' command not found or not applicable for this OS/environment."
    echo "[INFO] If on RHEL/CentOS/Fedora, KVM status can often be inferred by /dev/kvm existence and 'qemu-kvm' package."
    echo "[INFO] You can manually check for 'vmx' (Intel) or 'svm' (AMD) flags in /proc/cpuinfo: grep -E --color=auto 'vmx|svm' /proc/cpuinfo"
fi

# 3. Install Vagrant if missing
if ! command -v vagrant >/dev/null 2>&1; then
    echo "[CI] Vagrant not found. Installing..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update -y
    sudo apt-get install -y vagrant
else
    echo "[CI] Vagrant already installed."
fi

# 4. Ensure user is in libvirt group
if ! id | grep -q libvirt; then
    echo "[CI] Adding user to 'libvirt' group..."
    sudo usermod -aG libvirt "$USER"
    echo "[CI] Re-executing script with 'libvirt' group using 'sg'..."
    exec sg libvirt "$0"
fi

echo "[CI] User is already in 'libvirt' group."

# 5. Install vagrant-libvirt plugin
if ! vagrant plugin list | grep -q vagrant-libvirt; then
    echo "[CI] Installing vagrant-libvirt plugin..."
    vagrant plugin install vagrant-libvirt
else
    echo "[CI] vagrant-libvirt already installed."
fi

# Ensure no stale Vagrant or libvirt VM exists
echo "[CI] Checking for stale 'openstack_default' domain..."
VM_EXISTS=$(sudo virsh list --all | grep -i openstack_default)

if [ -n "$VM_EXISTS" ]; then
    echo "[WARN] 'openstack_default' exists in libvirt. Destroying..."
    sudo virsh destroy openstack_default 2>/dev/null || true
    sudo virsh undefine openstack_default --remove-all-storage 2>/dev/null || true
fi

# Clean .vagrant if exists
if [ -d ".vagrant" ]; then
    echo "[WARN] Cleaning stale Vagrant metadata..."
    rm -rf .vagrant
fi
# 6. Start VM
echo "[CI] Starting Vagrant VM with provider: $PROVIDER"

# Run vagrant up and capture output
VM_OUTPUT=$(vagrant up --provider="$PROVIDER" 2>&1) || true
echo "$VM_OUTPUT"

if echo "$VM_OUTPUT" | grep -q "requested NFS version or transport protocol is not supported"; then
    echo "[WARN] NFS mount failed due to unsupported version/protocol."
    echo "[INFO] Switching synced_folder method to rsync..."

    # Backup original Vagrantfile
    cp Vagrantfile Vagrantfile.bak

    # Replace NFS with rsync in the Vagrantfile
    sed -i 's|type: "nfs"|type: "rsync"|' Vagrantfile

    echo "[INFO] Retrying vagrant up with rsync..."
    vagrant up --provider="$PROVIDER"
else
    # Only check for a real provisioning failure
    if echo "$VM_OUTPUT" | grep -q "VM boot failed\|error while running provisioner\|A fatal error occurred"; then
        echo "[ERROR] VM provisioning failed."
        exit 1
    fi
fi


# 7. Get IP address
VM_IP=$(vagrant ssh -c "hostname -I | awk '{print \$1}'" | tr -d '\r')
echo "[CI] VM IP: $VM_IP"

# 8. Check Keystone API
echo "[CI] Checking Keystone API on the VM..."
if ! vagrant ssh -c "curl -sf http://localhost:5000/v3/"; then
    echo "❌ Keystone API not responding."
    vagrant destroy -f
    exit 1
fi
echo "✅ Keystone API is working."

# 9. Cleanup
echo "[CI] Destroying Vagrant VM..."
vagrant destroy -f

# Additional cleanup to remove 'openstack_default' domain if it still exists after destroy
if sudo virsh list --all | grep -q "openstack_default"; then
    echo "[WARN] 'openstack_default' still exists in libvirt after Vagrant destroy. Cleaning up..."
    sudo virsh destroy openstack_default 2>/dev/null || true
    sudo virsh undefine openstack_default --remove-all-storage 2>/dev/null || true
fi
