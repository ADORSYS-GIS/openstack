#!/bin/bash
set -e

# Check if multipass is installed
if ! command -v multipass >/dev/null 2>&1; then
    echo "[ERROR] Multipass is not installed."
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "To install Multipass on macOS, run:"
        echo "  brew install --cask multipass"
    elif [[ -f /etc/lsb-release ]] && grep -qi ubuntu /etc/lsb-release; then
        echo "To install Multipass on Ubuntu, run:"
        echo "  sudo snap install multipass"
    else
        echo "Please see https://multipass.run/ for installation instructions for your OS."
    fi
    exit 1
fi

# Configuration
CONTROLLER_NAME="controller"
COMPUTE_NAME="compute"
CONTROLLER_CPUS=2
CONTROLLER_MEM=4G
CONTROLLER_DISK=20G
COMPUTE_CPUS=2
COMPUTE_MEM=4G
COMPUTE_DISK=20G
SSH_KEY=$HOME/.ssh/id_ed25519
SSH_PUB=$HOME/.ssh/id_ed25519.pub


# check if ifconfig is installed 

ensure_ifconfig_installed() {
    if command -v ifconfig >/dev/null 2>&1; then
        echo "[INFO] ifconfig is already installed."
        return 0
    fi

    echo "[INFO] ifconfig not found. Installing net-tools for Ubuntu..."

    # Check if the OS is Ubuntu
    if [ -f /etc/lsb-release ] && grep -qi "ubuntu" /etc/lsb-release; then
        sudo apt update
        sudo apt install -y net-tools
    else
        echo "[ERROR] This script only supports Ubuntu for automatic net-tools installation."
        return 1
    fi

    # Verify installation
    if command -v ifconfig >/dev/null 2>&1; then
        echo "[INFO] ifconfig successfully installed."
    else
        echo "[ERROR] Installation failed. Please install net-tools manually."
        return 1
    fi
}

ensure_ifconfig_installed
#### Bridge networking for multipass vms is not supported for mac

BRIDGE_NAME="mpbr0"



OS="$(uname)"

if [ "$OS" = "Darwin" ]; then
    echo "[INFO] macOS detected – skipping bridge creation (not supported)."
else
    echo "[INFO] Linux detected – checking for bridge $BRIDGE_NAME..."

    # Check if bridge exists
    if ifconfig | grep -q "$BRIDGE_NAME"; then
        echo "[INFO] Bridge $BRIDGE_NAME already exists. Skipping creation."
    else
        echo "[INFO] Creating bridge: $BRIDGE_NAME"
        sudo brctl addbr "$BRIDGE_NAME"
        sudo ifconfig "$BRIDGE_NAME" up
        echo "[INFO] Bridge $BRIDGE_NAME created and brought up."
    fi
fi


# 1. Generate SSH key if not exists
if [ ! -f "$SSH_KEY" ]; then
    ssh-keygen -t ed25519 -N "" -f "$SSH_KEY"
fi

# Ensure correct permissions on SSH key
echo "[INFO] Ensuring correct permissions on SSH directory and public key..."
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ -f "$SSH_PUB" ]; then
    chmod 644 "$SSH_PUB"
fi

# Ensure Ansible is installed or set up a virtual environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv_ansible"

activate_venv() {
    # shellcheck disable=SC1090
    source "$VENV_DIR/bin/activate"
}

if command -v ansible-playbook >/dev/null 2>&1; then
    ANSIBLE_CMD="ansible-playbook"
    echo "[INFO] Using system Ansible: $(ansible-playbook --version | head -n1)"
elif [ -d "$VENV_DIR" ] && [ -x "$VENV_DIR/bin/ansible-playbook" ]; then
    echo "[INFO] Using existing virtualenv Ansible."
    activate_venv
    ANSIBLE_CMD="ansible-playbook"
else
    echo "[INFO] Ansible not found. Creating virtual environment and installing Ansible..."
    python3 -m venv "$VENV_DIR"
    activate_venv
    pip install --upgrade pip
    pip install ansible
    ANSIBLE_CMD="ansible-playbook"
fi

# 2. Launch VMs with multipass (if not already running)
for VM in $CONTROLLER_NAME $COMPUTE_NAME; do
    if multipass info $VM >/dev/null 2>&1; then
        echo "$VM already exists. Skipping creation."
    else
        if [ "$OS" = "Darwin" ]; then
            echo "Launching $VM with default NIC only (macOS, no bridge support)..."
            multipass launch -n $VM \
                -c $CONTROLLER_CPUS -m $CONTROLLER_MEM -d $CONTROLLER_DISK 
        else
            echo "Launching $VM with two NICs (default + $BRIDGE_NAME)..."
            multipass launch -n $VM \
                -c $CONTROLLER_CPUS -m $CONTROLLER_MEM -d $CONTROLLER_DISK \
                --network name=$BRIDGE_NAME,mode=manual
        fi
    fi
    # Ensure VM is running
    multipass start $VM
    sleep 2
    multipass info $VM
    echo
done

# 3. Get VM IPs
echo "Waiting for VMs to obtain IP addresses..."
CONTROLLER_IP="$(multipass info $CONTROLLER_NAME | awk '/IPv4/ {print $2; exit}')"
COMPUTE_IP="$(multipass info $COMPUTE_NAME | awk '/IPv4/ {print $2; exit}')"

# check if the IP is
if [ -z "$CONTROLLER_IP" ] || [ -z "$COMPUTE_IP" ]; then
    echo "[ERROR] One or both VMs failed to obtain IP addresses."
    multipass info $CONTROLLER_NAME
    multipass info $COMPUTE_NAME
    exit 1
fi


# 4. Setup SSH on VMs and copy public key
for VM in $CONTROLLER_NAME $COMPUTE_NAME; do
    multipass exec $VM -- bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    multipass exec $VM -- bash -c "touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    multipass transfer $SSH_PUB $VM:/tmp/host_id_ed25519.pub
    multipass exec $VM -- bash -c "cat /tmp/host_id_ed25519.pub >> ~/.ssh/authorized_keys && rm /tmp/host_id_ed25519.pub"
done

echo "SSH key setup complete."

# 5. Update inventory files
update_inventory() {
    local inventory_file="$1"
    cat > "$inventory_file" <<EOF
[controllers]
controller ansible_host=$CONTROLLER_IP

[computes]
compute ansible_host=$COMPUTE_IP

[all:vars]
ansible_become=true
ansible_become_method=sudo
ansible_become_user=root
ansible_ssh_private_key_file=$SSH_KEY
ansible_user=ubuntu
EOF
}

update_inventory "$(dirname "$0")/openstack-dep/inventory.ini"
update_inventory "$(dirname "$0")/openstack-neutron/inventory.ini"

echo "Inventories updated with VM IPs:"
echo "  Controller: $CONTROLLER_IP"
echo "  Compute:    $COMPUTE_IP"

# Run openstack-dep playbook
cd "$SCRIPT_DIR/openstack-dep" || exit 1
$ANSIBLE_CMD -i inventory.ini site.yml -vvv

# Run openstack-neutron playbook
cd ../openstack-neutron || exit 1
$ANSIBLE_CMD -i inventory.ini site.yml -vvv 

# At the end, print manual test and cleanup instructions
cat <<EOF

[INFO] OpenStack deployment script completed.

To manually test your OpenStack installation:
  1. SSH into the controller VM:
     multipass shell controller
  2. Source the OpenStack admin credentials (if created):
     source /root/admin-openrc.sh
  3. Run a test command, e.g.:
     openstack project list
     openstack user list
     openstack service list

To delete all Multipass VMs and free resources:
  multipass list
  multipass delete --all
  multipass purge

For more info, see: https://docs.openstack.org/ and https://multipass.run/
EOF 


### install net-tools 