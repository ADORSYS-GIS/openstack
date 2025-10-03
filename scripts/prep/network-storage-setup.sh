#!/bin/bash
# Storage Node Network Setup Script (CORRECTED)
# Usage: ./network-storage-setup.sh <NODE_ID>
# Example: ./network-storage-setup.sh 1
# CRITICAL FIX: Now includes Internal API VLAN 11 for service endpoints

# Source the common functions
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/network-functions.sh"

# Validate input
NODE_ID="${1:-}"
if [[ -z "$NODE_ID" ]]; then
    echo "Usage: $0 <NODE_ID>"
    echo "Example: $0 1 (for storage-1)"
    exit 1
fi

validate_node_id "$NODE_ID" "storage"

log_message "INFO" "Starting Storage-$NODE_ID network configuration"
log_message "INFO" "CRITICAL FIX: Including Internal API VLAN 11 for Ceph service endpoints"

# Backup existing configuration
backup_netplan_config

# Generate complete netplan configuration
{
    generate_netplan_header
    generate_bond1_config "storage"
    generate_vlan_config "storage" "$NODE_ID"
} | sudo tee "$NETPLAN_CONFIG" > /dev/null

log_message "INFO" "Network configuration created for Storage-$NODE_ID"
log_message "INFO" "Configuration includes:"
log_message "INFO" "  - Management VLAN 10: 192.168.10.$((20 + NODE_ID))/24"
log_message "INFO" "  - Internal API VLAN 11: 192.168.11.$((20 + NODE_ID))/24 (CRITICAL for Ceph services)"
log_message "INFO" "  - Storage VLAN 20: 192.168.20.$((20 + NODE_ID))/24 (MTU: 9000)"

# Apply configuration
apply_netplan_config

# Verify configuration
verify_interfaces "storage"

# Additional storage-specific verification
log_message "INFO" "Performing storage-specific network tests..."

# Test jumbo frame connectivity if other storage nodes are available
for target_node in {1..3}; do
    if [[ "$target_node" != "$NODE_ID" ]]; then
        target_ip="192.168.20.$((20 + target_node))"
        if ping -c 1 -W 2 "$target_ip" &>/dev/null; then
            if ping -M do -s 8972 -c 1 -W 5 "$target_ip" &>/dev/null 2>&1; then
                log_message "SUCCESS" "Jumbo frame connectivity verified to storage-$target_node ($target_ip)"
            else
                log_message "WARNING" "Standard ping works but jumbo frames may not be working to storage-$target_node"
            fi
        fi
    fi
done

log_message "SUCCESS" "Storage-$NODE_ID network configuration complete"
echo -e "\n=== Storage-$NODE_ID Network Setup Complete ===\n"
echo -e "IMPORTANT: Internal API VLAN 11 is now configured for Ceph service endpoints\n"
