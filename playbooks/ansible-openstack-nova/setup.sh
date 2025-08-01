#!/bin/sh
# setup.sh
# Installs Vagrant, libvirt, vagrant-libvirt, performs host checks, provisions Vagrant VMs with Ansible, and optionally triggers cleanup.

set -e

# ANSI color codes
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BOLD="\033[1m"
COLOR_UNDERLINE="\033[4m"
COLOR_RESET="\033[0m"

# Logging functions
log_section() {
    echo "${COLOR_BOLD}${COLOR_UNDERLINE}===== $1 =====${COLOR_RESET}"
}

log_info() {
    echo "${COLOR_GREEN}[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1${COLOR_RESET}"
}

log_warning() {
    echo "${COLOR_YELLOW}[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1${COLOR_RESET}"
}

log_error() {
    echo "${COLOR_RED}[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1${COLOR_RESET}" >&2
    exit 1
}

# Parse arguments
CLEANUP=false
while [ $# -gt 0 ]; do
    case "$1" in
        --cleanup) CLEANUP=true; shift ;;
        *) log_error "Unknown argument: $1" ;;
    esac
done

log_section "Starting Setup"

# Ensure USER is set
USER="${USER:-$(whoami)}"
[ -z "$USER" ] && log_error "Cannot determine user."

# Detect operating system
log_section "Detecting Operating System"
if [ -f /etc/debian_version ]; then
    DISTRO=debian
elif [ -f /etc/redhat-release ]; then
    DISTRO=rhel
else
    log_error "Unsupported OS. This script supports Debian/Ubuntu and RHEL/CentOS."
fi
log_info "Detected OS: $DISTRO."

# Check for package manager lock
log_section "Checking Package Manager Lock"
if [ "$DISTRO" = debian ]; then
    if sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
       sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
       sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
        log_error "apt is locked by another process. Please wait or resolve manually."
    fi
elif [ "$DISTRO" = rhel ]; then
    if sudo fuser /var/run/yum.pid >/dev/null 2>&1 || \
       sudo fuser /var/run/dnf.pid >/dev/null 2>&1; then
        log_error "yum/dnf is locked by another process. Please wait or resolve manually."
    fi
fi
log_info "No package manager lock detected."

# Install host system dependencies (including wget for Vagrant installation)
log_section "Installing Host System Dependencies"
if [ "$DISTRO" = debian ]; then
    i=1
    while [ "$i" -le 3 ]; do
        if stdbuf -oL sudo apt-get update; then
            break
        else
            log_warning "Retry $i: apt-get update failed. Retrying in 2 seconds..."
            sleep 2
            i=`expr $i + 1`
        fi
    done
    stdbuf -oL sudo apt-get install -y wget lsb-release qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager dnsmasq-base ruby-full build-essential libxml2-dev libxslt1-dev libvirt-dev zlib1g-dev python3-venv python3-pip || \
        log_error "Failed to install Debian/Ubuntu host dependencies."
elif [ "$DISTRO" = rhel ]; then
    i=1
    while [ "$i" -le 3 ]; do
        if stdbuf -oL sudo yum install -y yum-utils qemu-kvm libvirt virt-install bridge-utils virt-manager libguestfs-tools ruby-devel gcc libxml2-devel libxslt-devel libvirt-devel zlib-devel make python3-virtualenv python3-pip; then
            break
        else
            log_warning "Retry $i: yum install failed. Retrying in 2 seconds..."
            sleep 2
            i=`expr $i + 1`
        fi
    done
    stdbuf -oL sudo yum install -y yum-utils qemu-kvm libvirt virt-install bridge-utils virt-manager libguestfs-tools ruby-devel gcc libxml2-devel libxslt-devel libvirt-devel zlib-devel make python3-virtualenv python3-pip || \
        log_error "Failed to install RHEL host dependencies."
fi
log_info "Host dependencies installed."

# Install Vagrant if not present
log_section "Installing Vagrant"
if ! command -v vagrant >/dev/null 2>&1; then
    log_info "Vagrant not found. Installing Vagrant..."
    if [ "$DISTRO" = debian ]; then
        wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg || \
            log_error "Failed to download HashiCorp GPG key."
        UBUNTU_CODENAME=""
        if [ -f /etc/os-release ]; then
            UBUNTU_CODENAME=`grep UBUNTU_CODENAME /etc/os-release | cut -d= -f2`
        fi
        [ -z "$UBUNTU_CODENAME" ] && UBUNTU_CODENAME=`lsb_release -cs 2>/dev/null` || \
            log_error "Failed to determine Ubuntu codename."
        echo "deb [arch=`dpkg --print-architecture` signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $UBUNTU_CODENAME main" | \
            sudo tee /etc/apt/sources.list.d/hashicorp.list || log_error "Failed to add HashiCorp APT repository."
        stdbuf -oL sudo apt-get update || log_error "Failed to update APT after adding HashiCorp repository."
        stdbuf -oL sudo apt-get install -y vagrant || log_error "Failed to install Vagrant on Debian/Ubuntu."
    elif [ "$DISTRO" = rhel ]; then
        stdbuf -oL sudo yum install -y yum-utils || log_error "Failed to install yum-utils."
        stdbuf -oL sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo || \
            log_error "Failed to add HashiCorp YUM repository."
        stdbuf -oL sudo yum -y install vagrant || log_error "Failed to install Vagrant on RHEL/CentOS."
    fi
    command -v vagrant >/dev/null 2>&1 || log_error "Vagrant installation failed. Please install manually from vagrantup.com."
fi
log_info "Vagrant is installed."

# Start and enable libvirtd
log_section "Configuring libvirtd Service"
sudo systemctl enable libvirtd || log_error "Failed to enable libvirtd."
sudo systemctl start libvirtd || log_error "Failed to start libvirtd. Check logs with 'journalctl -u libvirtd -n 50'."
systemctl is-active libvirtd >/dev/null 2>&1 || log_error "libvirtd not running after start attempt."
log_info "libvirtd is running."

# Add user to libvirt group
log_section "Configuring User Permissions"
getent group libvirt >/dev/null || log_error "'libvirt' group does not exist."
# POSIX: Use grep | wc -l instead of grep -qw
if id -nG "$USER" | grep libvirt >/dev/null 2>&1; then
    : # No-op
else
    sudo usermod -aG libvirt "$USER" || log_error "Failed to add user '$USER' to 'libvirt' group."
    log_error "User '$USER' added to 'libvirt' group. Run 'newgrp libvirt' or log out and back in, then re-run this script."
fi
log_info "User '$USER' is already in 'libvirt' group."

# Install/Update vagrant-libvirt plugin
log_section "Configuring vagrant-libvirt Plugin"
if vagrant plugin list | grep vagrant-libvirt >/dev/null 2>&1; then
    log_info "vagrant-libvirt plugin found. Attempting to update..."
    stdbuf -oL vagrant plugin update vagrant-libvirt || log_warning "Failed to update vagrant-libvirt plugin. Proceeding with existing version."
else
    log_info "Installing vagrant-libvirt plugin (this may take a moment)..."
    i=1
    while [ "$i" -le 3 ]; do
        if stdbuf -oL vagrant plugin install vagrant-libvirt; then
            break
        else
            log_warning "Retry $i: vagrant-libvirt plugin install failed. Retrying in 2 seconds..."
            sleep 2
            i=`expr $i + 1`
        fi
    done
    vagrant plugin list | grep vagrant-libvirt >/dev/null 2>&1 || log_error "Failed to install vagrant-libvirt plugin."
fi
log_info "vagrant-libvirt plugin installed/updated."

# Verify virsh connectivity
log_section "Verifying libvirt Connectivity"
sleep 2
if ! virsh -c qemu:///system list --all >/dev/null 2>virsh_error.log; then
    log_error "virsh cannot connect to libvirt. Check permissions (id -nG $USER) or libvirtd issues.\n$(cat virsh_error.log)"
fi
rm -f virsh_error.log
log_info "libvirt is accessible via virsh."

# Check nested virtualization
log_section "Checking Nested Virtualization"
if lscpu | grep -E "Virtualization:.*VT-x|AMD-V" >/dev/null 2>&1; then
    : # No-op
else
    log_error "Host CPU does NOT support virtualization (VT-x/AMD-V). Enable in BIOS/UEFI."
fi
KVM_NESTED_ENABLED=false
if [ -f /sys/module/kvm_intel/parameters/nested ]; then
    if [ "$(cat /sys/module/kvm_intel/parameters/nested)" = Y ]; then
        KVM_NESTED_ENABLED=true
        log_info "Intel KVM nested virtualization is enabled."
    else
        log_warning "Intel KVM nested virtualization is supported but NOT enabled. To enable: 'sudo modprobe -r kvm_intel; sudo modprobe kvm_intel nested=1'."
    fi
elif [ -f /sys/module/kvm_amd/parameters/nested ]; then
    if [ "$(cat /sys/module/kvm_amd/parameters/nested)" = 1 ]; then
        KVM_NESTED_ENABLED=true
        log_info "AMD KVM nested virtualization is enabled."
    else
        log_warning "AMD KVM nested virtualization is supported but NOT enabled. To enable: 'sudo modprobe -r kvm_amd; sudo modprobe kvm_amd nested=1'."
    fi
else
    log_warning "KVM module parameters for nested virtualization not found."
fi
if [ "$KVM_NESTED_ENABLED" = false ]; then
    log_warning "Nested virtualization is crucial for OpenStack instances. Enable it if you encounter issues."
fi
log_info "Host virtualization checks completed."

# Install Ansible in Virtual Environment
log_section "Setting Up Ansible Environment"
PYTHON_VENV_DIR=.venv
if [ ! -d "$PYTHON_VENV_DIR" ]; then
    PYTHONUNBUFFERED=1 python3 -m venv "$PYTHON_VENV_DIR" || log_error "Failed to create Python virtual environment."
    log_info "Virtual environment created at $PYTHON_VENV_DIR."
fi
. "$PYTHON_VENV_DIR/bin/activate" || log_error "Failed to activate virtual environment."
log_info "Virtual environment activated."
log_info "Installing Ansible and OpenStackSDK in virtual environment..."
PYTHONUNBUFFERED=1 stdbuf -oL pip install --upgrade pip || log_warning "Failed to upgrade pip."
PYTHONUNBUFFERED=1 stdbuf -oL pip install ansible openstacksdk || log_error "Failed to install Ansible and OpenStackSDK."
log_info "Ansible and OpenStackSDK installed in virtual environment."

# Verify project files
log_section "Verifying Project Files"
[ -f Vagrantfile ] || log_error "Vagrantfile not found."
[ -f playbooks/site.yml ] || log_error "Ansible playbook (playbooks/site.yml) not found."
[ -f inventory/hosts.ini ] || log_error "Ansible inventory (inventory/hosts.ini) not found."
[ -f requirements.yml ] || log_error "Ansible collections requirements file (requirements.yml) not found."
log_info "All essential project files found."

# Install Ansible Collections
log_section "Installing Ansible Collections"
PYTHONUNBUFFERED=1 stdbuf -oL ansible-galaxy collection install -r requirements.yml || log_error "Failed to install Ansible collections."
log_info "Ansible Collections installed."

# Start Vagrant VMs
log_section "Starting Vagrant VMs"
stdbuf -oL vagrant up --provider=libvirt --no-tty >vagrant_up.log 2>&1 || {
    log_error "Vagrant up failed. Check vagrant_up.log for details:\n$(cat vagrant_up.log)"
}
log_info "Vagrant VMs provisioned successfully."

# Trigger cleanup if requested
log_section "Checking for Cleanup"
if [ "$CLEANUP" = true ]; then
    log_info "Triggering cleanup as requested..."
    if [ -f cleanup.sh ] && [ -x cleanup.sh ]; then
        ./cleanup.sh || log_error "Cleanup failed."
        log_info "Cleanup completed."
    else
        log_warning "cleanup.sh not found or not executable. Skipping cleanup."
    fi
fi

log_section "Setup Complete"
log_info "You can now SSH into your VMs:"
log_info "  vagrant ssh controller"
log_info "  vagrant ssh compute"
log_info "To destroy the VMs later, run: ./cleanup.sh"