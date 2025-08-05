#!/bin/bash
# add-local-box.sh
# Helper script to add a local Ubuntu 20.04 box for offline usage

# This script is designed to work with the OpenStack Nova setup project
# It can be called automatically by setup.sh when box download fails

set -e

# Default values
BOX_NAME="ubuntu2004"
BOX_URL="https://cloud-images.ubuntu.com/releases/20.04/release/ubuntu-20.04-server-cloudimg-amd64.img"

# ANSI color codes
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BOLD="\033[1m"
COLOR_RESET="\033[0m"

# Logging functions
log_info() {
    echo "${COLOR_GREEN}[INFO]${COLOR_RESET} $1"
}

log_warning() {
    echo "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

log_error() {
    echo "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
    exit 1
}

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --box-name=*)
            BOX_NAME=$(echo "$1" | cut -d= -f2)
            shift
            ;;
        --box-file=*)
            BOX_FILE=$(echo "$1" | cut -d= -f2)
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Helper script to add a local Ubuntu 20.04 box for offline usage"
            echo ""
            echo "Options:"
            echo "  --box-name=NAME     Box name to use (default: ubuntu2004)"
            echo "  --box-file=FILE     Path to existing box file"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0  # Download and add default box"
            echo "  $0 --box-name=my-ubuntu --box-file=/path/to/ubuntu.box"
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            ;;
    esac
done

# Check if box already exists
if vagrant box list | grep -q "$BOX_NAME"; then
    log_warning "Box '$BOX_NAME' already exists. Skipping addition."
    exit 0
fi

# If box file is provided, use it directly
if [ -n "$BOX_FILE" ]; then
    if [ ! -f "$BOX_FILE" ]; then
        log_error "Box file '$BOX_FILE' not found."
    fi
    
    log_info "Adding box '$BOX_NAME' from '$BOX_FILE'..."
    vagrant box add "$BOX_NAME" "$BOX_FILE" || log_error "Failed to add box from file."
    log_info "Box '$BOX_NAME' added successfully."
    exit 0
fi

# Download and convert cloud image to Vagrant box
log_info "Downloading Ubuntu 20.04 cloud image..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download cloud image
wget -O ubuntu-20.04.img "$BOX_URL" || log_error "Failed to download cloud image."

# Create Vagrant box metadata
cat > metadata.json << EOF
{
    "provider": "libvirt",
    "format": "qcow2",
    "virtual_size": 10
}
EOF

# Create Vagrantfile for the box
cat > Vagrantfile << EOF
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
    libvirt.host = "localhost"
    libvirt.uri = "qemu:///system"
    libvirt.memory = 2048
    libvirt.cpus = 2
  end
end
EOF

# Create box archive
log_info "Creating Vagrant box archive..."
tar cvzf ubuntu2004.box metadata.json Vagrantfile ubuntu-20.04.img || log_error "Failed to create box archive."

# Add box to Vagrant
log_info "Adding box to Vagrant..."
vagrant box add "$BOX_NAME" ubuntu2004.box || log_error "Failed to add box to Vagrant."

# Cleanup
cd -
rm -rf "$TEMP_DIR"

log_info "Box '$BOX_NAME' added successfully."
log_info "You can now use it with: VAGRANT_BOX=$BOX_NAME ./setup.sh"