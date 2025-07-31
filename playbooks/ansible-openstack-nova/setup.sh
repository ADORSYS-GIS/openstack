#!/bin/sh

# Installs libvirt, vagrant-libvirt, performs host checks, provisions Vagrant VMs with Ansible, and optionally triggers cleanup.

set -e

# Parse arguments
CLEANUP=false
while [ "$#" -gt 0 ]; do # Use "$#" for POSIX compatibility with argument count
    case "$1" in
        --cleanup) CLEANUP=true; shift ;;
        *) echo "Error: Unknown argument: $1"; exit 1 ;;
    esac
done

echo "Starting setup..."

# Ensure USER is set
USER="${USER:-$(whoami)}"
[ -z "$USER" ] && { echo "Error: Cannot determine user. Exiting."; exit 1; }

# Detect operating system
if [ -f /etc/debian_version ]; then
    DISTRO="debian"
elif [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
else
    echo "Error: Unsupported OS. This script currently supports Debian/Ubuntu and RHEL/CentOS. Exiting."
    exit 1
fi

echo "Detected OS: $DISTRO."

# Check for package manager lock
echo "Checking for package manager lock..."
if [ "$DISTRO" = "debian" ]; then
    if sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
       sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
       sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
        echo "Error: apt is locked by another process. Please wait for it to finish or resolve manually. Exiting."
        exit 1
    fi
elif [ "$DISTRO" = "rhel" ]; then
    if sudo fuser /var/run/dnf.pid >/dev/null 2>&1; then
        echo "Error: dnf is locked by another process. Please wait for it to finish or resolve manually. Exiting."
        exit 1
    fi
fi
echo "No package manager lock detected."

# Install host system dependencies for libvirt and vagrant-libvirt
echo "Installing host system dependencies for libvirt and vagrant-libvirt..."
if [ "$DISTRO" = "debian" ]; then
    for i in 1 2 3; do # POSIX: Replaced {1..3} with explicit list
        sudo apt-get update && break || { echo "Retry $i: apt-get update failed. Retrying in 2 seconds..."; sleep 2; }
    done
    sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager dnsmasq-base ruby-full build-essential libxml2-dev libxslt1-dev libvirt-dev zlib1g-dev || \
        { echo "Error: Failed to install Debian/Ubuntu host dependencies. Exiting."; exit 1; }
elif [ "$DISTRO" = "rhel" ]; then
    for i in 1 2 3; do # POSIX: Replaced {1..3} with explicit list
        sudo dnf install -y qemu-kvm libvirt virt-install bridge-utils virt-manager libguestfs-tools ruby-devel gcc libxml2-devel libxslt-devel libvirt-devel zlib-devel make && break || { echo "Retry $i: dnf install failed. Retrying in 2 seconds..."; sleep 2; }
    done
    sudo dnf install -y qemu-kvm libvirt virt-install bridge-utils virt-manager libguestfs-tools ruby-devel gcc libxml2-devel libxslt-devel libvirt-devel zlib-devel make || \
        { echo "Error: Failed to install RHEL host dependencies. Exiting."; exit 1; }
fi
echo "Host dependencies installed."

# Start and enable libvirtd
echo "Ensuring libvirtd service is running and enabled..."
sudo systemctl enable libvirtd || { echo "Error: Failed to enable libvirtd. Exiting."; exit 1; }
sudo systemctl start libvirtd || { echo "Error: Failed to start libvirtd. Check logs with 'journalctl -u libvirtd -n 50'. Exiting."; exit 1; }
systemctl is-active --quiet libvirtd || { echo "Error: libvirtd not running after start attempt. Exiting."; exit 1; }
echo "libvirtd is running."

# Add user to libvirt group
echo "Adding user '$USER' to 'libvirt' group if not already a member..."
getent group libvirt >/dev/null || { echo "Error: 'libvirt' group does not exist. Exiting."; exit 1; }
if ! id -nG "$USER" | grep -qw libvirt; then
    sudo usermod -aG libvirt "$USER" || { echo "Error: Failed to add user '$USER' to 'libvirt' group. Exiting."; exit 1; }
    echo "User '$USER' added to 'libvirt' group. IMPORTANT: Please log out and log back in for group changes to take full effect."
else
    echo "User '$USER' is already in 'libvirt' group."
fi

# Verify vagrant installation
echo "Verifying Vagrant installation..."
command -v vagrant >/dev/null || { echo "Error: Vagrant is not installed. Please install it from vagrantup.com. Exiting."; exit 1; }
echo "Vagrant is installed."

# Install vagrant-libvirt plugin
echo "Checking for vagrant-libvirt plugin..."
if ! vagrant plugin list | grep -q "vagrant-libvirt"; then
    echo "Installing vagrant-libvirt plugin (this may take a moment)..."
    for i in 1 2 3; do # POSIX: Replaced {1..3} with explicit list
        vagrant plugin install vagrant-libvirt && break || { echo "Retry $i: vagrant-libvirt plugin install failed. Retrying in 2 seconds..."; sleep 2; }
    done
    vagrant plugin list | grep -q "vagrant-libvirt" || { echo "Error: Failed to install vagrant-libvirt plugin. Exiting."; exit 1; }
fi
echo "vagrant-libvirt plugin is installed."

# Verify virsh connectivity
echo "Verifying virsh connectivity to libvirt..."
sleep 2 # Give libvirtd a moment to fully initialize
if ! virsh -c qemu:///system list --all >/dev/null 2>virsh_error.log; then
    echo "Error: virsh cannot connect to libvirt. This might be due to permissions (check 'id -nG $USER' and re-login) or libvirtd issues."
    echo "virsh error log:"
    cat virsh_error.log
    rm -f virsh_error.log
    exit 1
fi
rm -f virsh_error.log # Clean up temp log file
echo "libvirt is accessible via virsh."

# Check nested virtualization on host CPU and KVM module
echo "Checking host CPU for virtualization support and KVM nested virtualization enablement..."
if ! lscpu | grep -E -q "Virtualization:.*VT-x|AMD-V"; then # Used grep -E for extended regex |
    echo "Error: Host CPU does NOT support virtualization (VT-x/AMD-V flags not found). Enable in BIOS/UEFI. Exiting."
    exit 1
fi

KVM_NESTED_ENABLED=false
if [ -f /sys/module/kvm_intel/parameters/nested ]; then
    if [ "$(cat /sys/module/kvm_intel/parameters/nested)" = "Y" ]; then # POSIX: Used = instead of ==
        KVM_NESTED_ENABLED=true
        echo "Intel KVM nested virtualization is enabled."
    else
        echo "Warning: Intel KVM nested virtualization is supported by CPU but NOT enabled in KVM module."
        echo "To enable: 'sudo modprobe -r kvm_intel; sudo modprobe kvm_intel nested=1'."
    fi
elif [ -f /sys/module/kvm_amd/parameters/nested ]; then
    if [ "$(cat /sys/module/kvm_amd/parameters/nested)" = "1" ]; then # POSIX: Used = instead of ==
        KVM_NESTED_ENABLED=true
        echo "AMD KVM nested virtualization is enabled."
    else
        echo "Warning: AMD KVM nested virtualization is supported by CPU but NOT enabled in KVM module."
        echo "To enable: 'sudo modprobe -r kvm_amd; sudo modprobe kvm_amd nested=1'."
    fi
else
    echo "Warning: KVM module parameters for nested virtualization not found (likely not loaded or non-Intel/AMD CPU)."
fi

if [ "$KVM_NESTED_ENABLED" = false ]; then # POSIX: Used = instead of ==
    echo "WARNING: Nested virtualization is crucial for running OpenStack instances within Vagrant VMs."
    echo "Please ensure it's properly enabled on your host system if you encounter issues launching VMs."
fi
echo "Host virtualization checks completed."

# Verify essential project files
echo "Verifying essential project files..."
[ -f Vagrantfile ] || { echo "Error: Vagrantfile not found in current directory. Exiting."; exit 1; }
[ -f playbooks/site.yml ] || { echo "Error: Ansible main playbook (playbooks/site.yml) not found. Exiting."; exit 1; }
[ -f inventory/hosts.ini ] || { echo "Error: Ansible inventory (inventory/hosts.ini) not found. Exiting."; exit 1; }
[ -f requirements.yml ] || { echo "Error: Ansible collections requirements file (requirements.yml) not found. Exiting."; exit 1; }
echo "All essential project files found."

# Install Ansible Collections
echo "Installing Ansible Collections from requirements.yml..."
ansible-galaxy collection install -r requirements.yml || { echo "Error: Failed to install Ansible collections. Exiting."; exit 1; }
echo "Ansible Collections installed."

# Start Vagrant VMs and trigger Ansible provisioning
echo "Starting Vagrant VMs (this may take a while)..."
vagrant up --provider=libvirt >vagrant_up.log 2>&1 || { echo "Error: Vagrant up failed. Check vagrant_up.log for details. Exiting."; cat vagrant_up.log; exit 1; }
echo "Vagrant VMs provisioned successfully."

# Trigger cleanup if requested
if [ "$CLEANUP" = true ]; then
    echo "Triggering cleanup as requested..."
    if [ -f cleanup.sh ] && [ -x cleanup.sh ]; then
        ./cleanup.sh || { echo "Error: Cleanup failed. Exiting."; exit 1; }
        echo "Cleanup completed."
    else
        echo "Warning: cleanup.sh not found or not executable. Skipping cleanup."
    fi
fi

echo "Setup complete. You can now SSH into your VMs:"
echo "  vagrant ssh controller"
echo "  vagrant ssh compute"
echo "To destroy the VMs later, run: ./cleanup.sh"
