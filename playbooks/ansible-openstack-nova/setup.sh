#!/bin/sh
# setup.sh
# Installs Vagrant, libvirt, vagrant-libvirt, performs host checks, provisions Vagrant VMs with Ansible, and optionally triggers cleanup.
# Production-ready with robust error handling, retries, and resource validation.

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
FORCE_PROVISION=false
TIMEOUT=3600  # 1 hour default timeout
while [ $# -gt 0 ]; do
    case "$1" in
        --cleanup) CLEANUP=true; shift ;;
        --force-provision) FORCE_PROVISION=true; shift ;;
        --timeout=*)
            TIMEOUT=$(echo "$1" | cut -d= -f2)
            shift
            ;;
        *) log_error "Unknown argument: $1" ;;
    esac
done

log_section "Starting Setup"

# Ensure USER is set
USER="${USER:-$(whoami)}"
[ -z "$USER" ] && log_error "Cannot determine user."

# Check host resources
log_section "Checking Host Resources"
MIN_MEMORY_MB=8192
MIN_CPUS=2
AVAILABLE_MEMORY_MB=$(free -m | awk '/Mem:/ {print $2}')
AVAILABLE_CPUS=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
if [ "$AVAILABLE_MEMORY_MB" -lt "$MIN_MEMORY_MB" ]; then
    log_warning "Host memory ($AVAILABLE_MEMORY_MB MB) is below recommended $MIN_MEMORY_MB MB. Provisioning may be slow or fail."
fi
if [ "$AVAILABLE_CPUS" -lt "$MIN_CPUS" ]; then
    log_warning "Host CPUs ($AVAILABLE_CPUS) are below recommended $MIN_CPUS. Provisioning may be slow or fail."
fi
log_info "Host resources: $AVAILABLE_MEMORY_MB MB memory, $AVAILABLE_CPUS CPUs."

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
    if sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
       sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
       sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
        log_error "apt is locked by another process. Please wait or resolve manually."
    fi
elif [ "$DISTRO" = rhel ]; then
    if sudo fuser /var/run/dnf.pid >/dev/null 2>&1; then
        log_error "dnf is locked by another process. Please wait or resolve manually."
    fi
fi
log_info "No package manager lock detected."

# Install host system dependencies
log_section "Installing Host System Dependencies"
if [ "$DISTRO" = debian ]; then
    i=1
    while [ "$i" -le 3 ]; do
        if stdbuf -oL sudo apt-get update -q; then
            break
        else
            log_warning "Retry $i: apt-get update failed. Retrying in 5 seconds..."
            sleep 5
            i=$((i + 1))
        fi
    done
    [ "$i" -gt 3 ] && log_error "Failed to update apt after 3 retries."
    stdbuf -oL sudo apt-get install -y -q wget lsb-release qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager dnsmasq-base ruby-full build-essential libxml2-dev libxslt1-dev libvirt-dev zlib1g-dev python3-venv python3-pip || \
        log_error "Failed to install Debian/Ubuntu host dependencies."
elif [ "$DISTRO" = rhel ]; then
    i=1
    while [ "$i" -le 3 ]; do
        if stdbuf -oL sudo dnf install -y -q dnf-utils qemu-kvm libvirt virt-install bridge-utils virt-manager libguestfs-tools ruby-devel gcc libxml2-devel libxslt-devel libvirt-devel zlib-devel make python3-virtualenv python3-pip; then
            break
        else
            log_warning "Retry $i: dnf install failed. Retrying in 5 seconds..."
            sleep 5
            i=$((i + 1))
        fi
    done
    [ "$i" -gt 3 ] && log_error "Failed to install RHEL dependencies after 3 retries."
fi
log_info "Host dependencies installed."

# Install Vagrant
log_section "Installing Vagrant"
VAGRANT_MIN_VERSION="2.4.1"
if ! command -v vagrant >/dev/null 2>&1; then
    log_info "Vagrant not found. Installing Vagrant..."
    if [ "$DISTRO" = debian ]; then
        wget -q -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg || \
            log_error "Failed to download HashiCorp GPG key."
        UBUNTU_CODENAME=""
        if [ -f /etc/os-release ]; then
            UBUNTU_CODENAME=$(grep -E "^UBUNTU_CODENAME=" /etc/os-release | cut -d= -f2 | tr -d '\r')
        fi
        [ -z "$UBUNTU_CODENAME" ] && UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null | tr -d '\r') || \
            log_error "Failed to determine Ubuntu codename."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $UBUNTU_CODENAME main" | \
            sudo tee /etc/apt/sources.list.d/hashicorp.list || log_error "Failed to add HashiCorp APT repository."
        stdbuf -oL sudo apt-get update -q || log_error "Failed to update APT after adding HashiCorp repository."
        stdbuf -oL sudo apt-get install -y -q vagrant || log_error "Failed to install Vagrant on Debian/Ubuntu."
    elif [ "$DISTRO" = rhel ]; then
        stdbuf -oL sudo dnf install -y -q dnf-utils || log_error "Failed to install dnf-utils."
        stdbuf -oL sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo || \
            log_error "Failed to add HashiCorp DNF repository."
        stdbuf -oL sudo dnf -y -q install vagrant || log_error "Failed to install Vagrant on RHEL/CentOS."
    fi
else
    VAGRANT_VERSION=$(vagrant --version | awk '{print $2}')
    if [ "$(printf '%s\n%s' "$VAGRANT_VERSION" "$VAGRANT_MIN_VERSION" | sort -V | head -n1)" != "$VAGRANT_MIN_VERSION" ]; then
        log_warning "Vagrant version $VAGRANT_VERSION is older than recommended $VAGRANT_MIN_VERSION. Consider upgrading."
    fi
fi
command -v vagrant >/dev/null 2>&1 || log_error "Vagrant installation failed. Please install manually from https://www.vagrantup.com."
log_info "Vagrant is installed (version: $(vagrant --version))."

# Start and enable libvirtd
log_section "Configuring libvirtd Service"
sudo systemctl enable --now libvirtd || log_error "Failed to enable or start libvirtd. Check logs with 'journalctl -u libvirtd -n 50'."
systemctl is-active libvirtd >/dev/null 2>&1 || log_error "libvirtd is not running after start attempt."
log_info "libvirtd is running."

# Ensure libvirt default network is active
log_section "Configuring libvirt Default Network"
if ! virsh net-list --all | grep -q " default.*active"; then
    log_info "Starting libvirt default network..."
    virsh net-start default || log_error "Failed to start libvirt default network."
    virsh net-autostart default || log_warning "Failed to set libvirt default network to autostart."
fi
log_info "libvirt default network is active."

# Add user to libvirt group
log_section "Configuring User Permissions"
getent group libvirt >/dev/null || log_error "'libvirt' group does not exist."
if id -nG "$USER" | grep -q libvirt; then
    log_info "User '$USER' is already in 'libvirt' group."
else
    sudo usermod -aG libvirt "$USER" || log_error "Failed to add user '$USER' to 'libvirt' group."
    log_warning "User '$USER' added to 'libvirt' group. Run 'newgrp libvirt' or log out and back in, then re-run this script."
    exit 1
fi

# Install/Update vagrant-libvirt plugin
log_section "Configuring vagrant-libvirt Plugin"
VAGRANT_LIBVIRT_MIN_VERSION="0.12.2"
if vagrant plugin list | grep -q vagrant-libvirt; then
    log_info "vagrant-libvirt plugin found. Checking version and updating if needed..."
    VAGRANT_LIBVIRT_VERSION=$(vagrant plugin list | grep vagrant-libvirt | awk '{print $2}' | tr -d '()')
    if [ "$(printf '%s\n%s' "$VAGRANT_LIBVIRT_VERSION" "$VAGRANT_LIBVIRT_MIN_VERSION" | sort -V | head -n1)" != "$VAGRANT_LIBVIRT_MIN_VERSION" ]; then
        log_warning "vagrant-libvirt version $VAGRANT_LIBVIRT_VERSION is older than recommended $VAGRANT_LIBVIRT_MIN_VERSION. Updating..."
        stdbuf -oL vagrant plugin update vagrant-libvirt || log_warning "Failed to update vagrant-libvirt plugin. Proceeding with existing version."
    fi
else
    log_info "Installing vagrant-libvirt plugin (this may take a moment)..."
    i=1
    while [ "$i" -le 3 ]; do
        if stdbuf -oL vagrant plugin install vagrant-libvirt; then
            break
        else
            log_warning "Retry $i: vagrant-libvirt plugin install failed. Retrying in 5 seconds..."
            sleep 5
            i=$((i + 1))
        fi
    done
    vagrant plugin list | grep -q vagrant-libvirt || log_error "Failed to install vagrant-libvirt plugin after 3 retries."
fi
log_info "vagrant-libvirt plugin installed/updated (version: $(vagrant plugin list | grep vagrant-libvirt | awk '{print $2}' | tr -d '()'))."

# Verify libvirt connectivity
log_section "Verifying libvirt Connectivity"
if ! virsh -c qemu:///system list --all >/dev/null 2>virsh_error.log; then
    log_error "virsh cannot connect to libvirt. Check permissions (id -nG $USER) or libvirtd issues.\n$(cat virsh_error.log)"
fi
rm -f virsh_error.log
log_info "libvirt is accessible via virsh."

# Check nested virtualization
log_section "Checking Nested Virtualization"
if ! lscpu | grep -qE "Virtualization:.*VT-x|AMD-V"; then
    log_error "Host CPU does not support virtualization (VT-x/AMD-V). Enable in BIOS/UEFI."
fi
KVM_NESTED_ENABLED=false
if [ -f /sys/module/kvm_intel/parameters/nested ]; then
    if [ "$(cat /sys/module/kvm_intel/parameters/nested)" = Y ]; then
        KVM_NESTED_ENABLED=true
        log_info "Intel KVM nested virtualization is enabled."
    else
        log_warning "Intel KVM nested virtualization is supported but not enabled. Enabling..."
        sudo modprobe -r kvm_intel || log_warning "Failed to unload kvm_intel module."
        sudo modprobe kvm_intel nested=1 || log_warning "Failed to enable nested virtualization for kvm_intel."
        [ "$(cat /sys/module/kvm_intel/parameters/nested)" = Y ] && KVM_NESTED_ENABLED=true
    fi
elif [ -f /sys/module/kvm_amd/parameters/nested ]; then
    if [ "$(cat /sys/module/kvm_amd/parameters/nested)" = 1 ]; then
        KVM_NESTED_ENABLED=true
        log_info "AMD KVM nested virtualization is enabled."
    else
        log_warning "AMD KVM nested virtualization is supported but not enabled. Enabling..."
        sudo modprobe -r kvm_amd || log_warning "Failed to unload kvm_amd module."
        sudo modprobe kvm_amd nested=1 || log_warning "Failed to enable nested virtualization for kvm_amd."
        [ "$(cat /sys/module/kvm_amd/parameters/nested)" = 1 ] && KVM_NESTED_ENABLED=true
    fi
else
    log_error "KVM module parameters for nested virtualization not found. Ensure KVM is installed and loaded."
fi
if [ "$KVM_NESTED_ENABLED" = false ]; then
    log_error "Nested virtualization could not be enabled. Required for OpenStack instances in VMs."
fi
log_info "Nested virtualization enabled."

# Install Ansible in Virtual Environment
log_section "Setting Up Ansible Environment"
PYTHON_VENV_DIR="/opt/dev/venv"
if [ ! -d "$PYTHON_VENV_DIR" ]; then
    PYTHONUNBUFFERED=1 python3 -m venv "$PYTHON_VENV_DIR" || log_error "Failed to create Python virtual environment. Ensure python3-venv is installed."
    log_info "Virtual environment created at $PYTHON_VENV_DIR."
fi
. "$PYTHON_VENV_DIR/bin/activate" || log_error "Failed to activate virtual environment."
log_info "Virtual environment activated."
log_info "Installing Ansible and OpenStackSDK in virtual environment..."
PYTHONUNBUFFERED=1 stdbuf -oL pip install --upgrade pip setuptools wheel || log_warning "Failed to upgrade pip/setuptools/wheel. Continuing..."
PYTHONUNBUFFERED=1 stdbuf -oL pip install ansible==8.7.0 openstacksdk==4.6.0 || log_error "Failed to install Ansible and OpenStackSDK."
log_info "Ansible and OpenStackSDK installed (Ansible: $(ansible --version | head -n1), OpenStackSDK: $(pip show openstacksdk | grep Version))."

# Verify project files
log_section "Verifying Project Files"
[ -f Vagrantfile ] || log_error "Vagrantfile not found."
[ -f playbooks/site.yml ] || log_error "Ansible main playbook (playbooks/site.yml) not found."
[ -f inventory/hosts.ini ] || log_error "Ansible inventory (inventory/hosts.ini) not found."
[ -f requirements.yml ] || log_error "Ansible collections requirements file (requirements.yml) not found."
log_info "All essential project files found."

# Validate requirements.yml
log_section "Validating Ansible Collections Requirements"
if grep -qE "collections:|^ *- name:.*version:.*$" requirements.yml; then
    log_info "requirements.yml appears valid."
else
    log_warning "requirements.yml may be malformed. Ensure it contains 'collections:' with valid entries."
fi

# Install Ansible Collections
log_section "Installing Ansible Collections"
ANSIBLE_COLLECTIONS_PATH_ENV="$(pwd)/collections"
mkdir -p "$ANSIBLE_COLLECTIONS_PATH_ENV" || log_error "Failed to create collections directory at $ANSIBLE_COLLECTIONS_PATH_ENV."
if [ ! -d "$ANSIBLE_COLLECTIONS_PATH_ENV" ]; then
    log_error "Collections directory $ANSIBLE_COLLECTIONS_PATH_ENV does not exist after creation attempt."
fi
log_info "Collections directory created at $ANSIBLE_COLLECTIONS_PATH_ENV."
i=1
while [ "$i" -le 3 ]; do
    if PYTHONUNBUFFERED=1 stdbuf -oL ansible-galaxy collection install -r requirements.yml -p "$ANSIBLE_COLLECTIONS_PATH_ENV" --force; then
        log_info "Ansible Collections installed successfully."
        break
    else
        log_warning "Retry $i: Failed to install Ansible collections. Retrying in 5 seconds..."
        sleep 5
        i=$((i + 1))
    fi
done
[ "$i" -gt 3 ] && log_error "Failed to install Ansible collections after 3 retries. Check requirements.yml and network connectivity."

# Start Vagrant VMs and ensure provisioning
log_section "Starting Vagrant VMs"
if stdbuf -oL vagrant status | grep -E "controller.*running|compute.*running" | wc -l | grep -q "^2$"; then
    log_info "Both controller and compute VMs are running."
    if [ "$FORCE_PROVISION" = true ]; then
        log_info "Forcing Ansible provisioning..."
        stdbuf -oL vagrant provision >vagrant_up.log 2>&1 || {
            log_error "Vagrant provision failed. Check vagrant_up.log for details:\n$(cat vagrant_up.log)"
        }
    else
        log_info "Skipping provisioning as VMs are already running. Use --force-provision to re-run Ansible."
    fi
else
    log_info "Starting and provisioning Vagrant VMs..."
    stdbuf -oL vagrant up --provider=libvirt --no-tty >vagrant_up.log 2>&1 || {
        log_error "Vagrant up failed. Check vagrant_up.log for details:\n$(cat vagrant_up.log)"
    }
fi

# Verify machines are running and SSH is accessible
log_section "Verifying VM Status and SSH Connectivity"
if stdbuf -oL vagrant status | grep -E "controller.*running|compute.*running" | wc -l | grep -q "^2$"; then
    log_info "Both controller and compute VMs are running."
    # Fix SSH private key ownership
    for vm in controller compute; do
        key_file=".vagrant/machines/$vm/libvirt/private_key"
        if [ -f "$key_file" ]; then
            sudo chown "$USER:$USER" "$key_file" || log_error "Failed to change ownership of $key_file to $USER."
            chmod 600 "$key_file" || log_error "Failed to set permissions on $key_file."
            log_info "Fixed ownership and permissions for $key_file."
        else
            log_error "Private key $key_file not found after VM start."
        fi
    done
    # Test SSH configuration
    if stdbuf -oL vagrant ssh-config >/dev/null 2>&1; then
        log_info "SSH configuration is valid."
    else
        log_error "Vagrant SSH configuration is invalid after VM start. Check .vagrant/machines/*/libvirt/private_key permissions and Vagrantfile."
    fi
else
    log_error "VMs are not both running. Check vagrant_up.log for details:\n$(cat vagrant_up.log)"
fi

# Verify Ansible playbook completion
log_section "Verifying Ansible Playbook Completion"
i=1
while [ "$i" -le 3 ]; do
    if grep -q "PLAY RECAP" vagrant_up.log; then
        log_info "Ansible playbook completed. Checking for failures..."
        for host in controller compute; do
            if grep -A 2 "PLAY RECAP.*$host" vagrant_up.log | grep -q "failed=0"; then
                : # No-op
            else
                log_error "Ansible playbook reported failures for $host. Check vagrant_up.log (search 'PLAY RECAP')."
            fi
        done
        log_info "Ansible playbook (site.yml) completed successfully with no reported failures."
        break
    else
        log_warning "Retry $i: PLAY RECAP not found in vagrant_up.log. Retrying in 10 seconds..."
        sleep 10
        i=$((i + 1))
    fi
done
[ "$i" -gt 3 ] && log_error "Ansible playbook did not complete after 3 retries. Check vagrant_up.log for details:\n$(cat vagrant_up.log)"

# Trigger cleanup if requested
log_section "Checking for Cleanup"
if [ "$CLEANUP" = true ]; then
    log_info "Triggering cleanup as requested..."
    if [ -f cleanup.sh ] && [ -x cleanup.sh ]; then
        ./cleanup.sh --timeout="$TIMEOUT" || log_error "Cleanup failed."
        log_info "Cleanup completed."
    else
        log_warning "cleanup.sh not found or not executable. Skipping cleanup."
    fi
fi

log_section "Setup Complete"
log_info "You can now SSH into your VMs:"
log_info "  vagrant ssh controller"
log_info "  vagrant ssh compute"
log_info "To destroy the VMs later, run: ./cleanup.sh --timeout=$TIMEOUT"
