#!/bin/bash
# Controller Node Network Setup Script
# Usage: ./network-controller-setup.sh <NODE_ID>
# Example: ./network-controller-setup.sh 1

# Source the common functions
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/network-functions.sh"

# Validate input
NODE_ID="${1:-}"
if [[ -z "$NODE_ID" ]]; then
    echo "Usage: $0 <NODE_ID>"
    echo "Example: $0 1 (for controller-1)"
    exit 1
fi

validate_node_id "$NODE_ID" "controller"

log_message "INFO" "Starting Controller-$NODE_ID network configuration"

# Backup existing configuration
backup_netplan_config

# Generate complete netplan configuration
{
    generate_netplan_header
    generate_bond1_config "controller"
    generate_vlan_config "controller" "$NODE_ID"
} | sudo tee "$NETPLAN_CONFIG" > /dev/null

log_message "INFO" "Network configuration created for Controller-$NODE_ID"

# Apply configuration
apply_netplan_config

# Verify configuration
verify_interfaces "controller"

log_message "SUCCESS" "Controller-$NODE_ID network configuration complete"
echo -e "\n=== Controller-$NODE_ID Network Setup Complete ===\n"
