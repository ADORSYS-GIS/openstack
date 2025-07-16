#!/bin/sh
set -e

ARCH=$(uname -m)
OS=$(lsb_release -cs)
PROVIDER="libvirt"  # default

echo "[CI] Detected architecture: $ARCH"

# 1. Install required base tools
echo "[CI] Installing basic dependencies..."
sudo apt-get update -y
sudo apt-get install -y curl gnupg software-properties-common

# 2. Install Vagrant if missing
if ! command -v vagrant &> /dev/null; then
    echo "[CI] Installing Vagrant..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $OS main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y vagrant
else
    echo "[CI] Vagrant already installed."
fi

# 3. Architecture-specific setup
if [ "$ARCH" = "x86_64" ]; then
    echo "[CI] Setting up virtualization for x86_64..."

    sudo apt-get install -y cpu-checker
    if ! kvm-ok | grep -q 'can be used'; then
        echo "[WARN] KVM not available. Falling back to VirtualBox."
        PROVIDER="virtualbox"
    else
        # Install libvirt for x86_64
        echo "[CI] Installing libvirt and KVM packages..."
        sudo apt-get install -y \
            libvirt-daemon-system \
            libvirt-clients \
            libvirt-dev \
            qemu-kvm \
            qemu-system-x86 \
            bridge-utils \
            virt-manager \
            libosinfo-bin

        echo "[CI] Enabling libvirtd..."
        sudo systemctl enable --now libvirtd

        echo "[CI] Adding '$USER' to libvirt and libvirt-qemu groups..."
        sudo usermod -aG libvirt "$USER"
        sudo usermod -aG libvirt-qemu "$USER"
    fi

elif [ "$ARCH" = "aarch64" ]; then
    echo "[CI] Setting up virtualization for ARM64..."

    sudo apt-get install -y \
        qemu-system-arm \
        qemu-efi-aarch64 \
        libvirt-daemon-system \
        libvirt-clients \
        libvirt-dev \
        bridge-utils \
        virt-manager \
        libosinfo-bin

    echo "[CI] Enabling libvirtd..."
    sudo systemctl enable --now libvirtd

    echo "[CI] Adding '$USER' to libvirt and libvirt-qemu groups..."
    sudo usermod -aG libvirt "$USER"
    sudo usermod -aG libvirt-qemu "$USER"
    PROVIDER="libvirt"
else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi


# 4. Install Vagrant plugin
if ! vagrant plugin list | grep -q vagrant-libvirt; then
    echo "[CI] Installing vagrant-libvirt plugin dependencies..."
    sudo apt-get install -y libxslt-dev libxml2-dev zlib1g-dev ruby-dev build-essential

    echo "[CI] Installing vagrant-libvirt plugin..."
    vagrant plugin install vagrant-libvirt
else
    echo "[CI] vagrant-libvirt plugin already installed."
fi

# 5. Start Vagrant VM
echo "[CI] Starting Vagrant VM using provider: $PROVIDER..."
vagrant up --provider=$PROVIDER

# 6. Get VM IP address
VM_IP=$(vagrant ssh -c "hostname -I | awk '{print \$1}'" | tr -d '\r')
echo "[CI] VM IP: $VM_IP"

# 7[-]. Check Keystone API
echo "[CI] Verifying Keystone API..."
vagrant ssh -c "curl -sf http://localhost:5000/v3/" || {
    echo "❌ Keystone API not responding!"
    vagrant destroy -f
    exit 1
}
echo "✅ Keystone API is up!"

# 8. Cleanup
echo "[CI] Destroying Vagrant VM..."
vagrant destroy -f