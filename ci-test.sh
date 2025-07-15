#!/bin/bash
set -e

# 0. Ensure Vagrant is installed
if ! command -v vagrant &> /dev/null; then
    echo "[CI] Vagrant is not installed. Installing..."

    sudo apt-get update -y
    sudo apt-get install -y curl gnupg software-properties-common

    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y vagrant
    echo "[CI] Vagrant installed successfully."
else
    echo "[CI] Vagrant is already installed."
fi

# 0.1 Install and configure libvirt, KVM, and qemu
echo "[CI] Installing libvirt, KVM, and qemu..."
sudo apt-get install -y \
    libvirt-dev \
    libvirt-daemon-system \
    libvirt-clients \
    qemu-system-x86 \
    qemu-utils \
    virt-manager \
    bridge-utils \
    libosinfo-bin \
    cpu-checker

# Ensure libvirtd is running
echo "[CI] Starting libvirtd service..."
sudo systemctl enable --now libvirtd

# Add current user to libvirt and kvm groups (needed for access)
echo "[CI] Adding user '$USER' to libvirt and kvm groups..."
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"

echo "[CI] Re-login or reboot may be required for group changes to apply."

# 1. Ensure KVM and Libvirt are installed
echo "[CI] Installing libvirt and QEMU tools..."
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

# Add user to libvirt group (you may need to reboot or re-login after this)
sudo usermod -aG libvirt "$(whoami)"

# 2. Install Vagrant libvirt plugin if not already installed
if ! vagrant plugin list | grep -q vagrant-libvirt; then
    echo "[CI] Installing vagrant-libvirt plugin..."
    sudo apt-get install -y libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev
    vagrant plugin install vagrant-libvirt
    echo "[CI] vagrant-libvirt plugin installed successfully."
else
    echo "[CI] vagrant-libvirt plugin already installed."
fi

# 3. Start and provision the Vagrant VM
echo "[CI] Starting Vagrant VM..."
vagrant up --provider=libvirt

# 2. Get the VM's IP address (using the default libvirt network)
VM_IP=$(vagrant ssh -c "hostname -I | awk '{print \$2}'" | tr -d '\r')
echo "[CI] VM IP: $VM_IP"

# 5. Test Keystone API endpoint
echo "[CI] Checking Keystone API..."
vagrant ssh -c "curl -sf http://localhost:5000/v3/" || {
    echo "❌ Keystone API not responding!"
    vagrant destroy -f
    exit 1
}

echo "✅ Keystone API is up!"

# 6. Clean up
echo "[CI] Destroying Vagrant VM..."
vagrant destroy -f
