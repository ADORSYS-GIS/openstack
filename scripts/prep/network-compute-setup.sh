#!/bin/bash
# Compute Node Network Setup Script (CORRECTED)
# Usage: ./network-compute-setup.sh <NODE_ID>
# Example: ./network-compute-setup.sh 1
# CORRECTION: Standard MTU for bond1 on compute nodes (not hosting primary Ceph services)

# Source the common functions
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/network-functions.sh"

# Validate input
NODE_ID="${1:-}"
if [[ -z "$NODE_ID" ]]; then
    echo "Usage: $0 <NODE_ID>"
    echo "Example: $0 1 (for compute-1)"
    exit 1
fi

validate_node_id "$NODE_ID" "compute"

log_message "INFO" "Starting Compute-$NODE_ID network configuration"
log_message "INFO" "CORRECTION: Using standard MTU (1500) for bond1 on compute nodes"

# Backup existing configuration
backup_netplan_config

# Generate complete netplan configuration
{
    generate_netplan_header
    generate_bond1_config "compute"
    generate_vlan_config "compute" "$NODE_ID"
} | sudo tee "$NETPLAN_CONFIG" > /dev/null

log_message "INFO" "Network configuration created for Compute-$NODE_ID"
log_message "INFO" "Configuration includes:"
log_message "INFO" "  - Management VLAN 10: 192.168.10.$((30 + NODE_ID))/24"
log_message "INFO" "  - Internal API VLAN 11: 192.168.11.$((30 + NODE_ID))/24"
log_message "INFO" "  - Storage VLAN 20: 192.168.20.$((30 + NODE_ID))/24 (MTU: 1500 - compute access only)"
log_message "INFO" "  - Provider Interface eth2: Ready for OVN tunnel traffic"

# Apply configuration
apply_netplan_config

# Verify configuration
verify_interfaces "compute"

# Additional compute-specific verification
log_message "INFO" "Performing compute-specific network tests..."

# Test connectivity to controller VIP
if ping -c 3 -W 5 192.168.11.100 &>/dev/null; then
    log_message "SUCCESS" "Connectivity to controller VIP (192.168.11.100) verified"
else
    log_message "WARNING" "Cannot reach controller VIP - may not be configured yet"
fi

# Verify provider interface is ready
if ip link show eth2 &>/dev/null; then
    local eth2_mtu=$(ip link show eth2 | grep -o 'mtu [0-9]*' | cut -d' ' -f2)
    log_message "INFO" "Provider interface eth2: UP, MTU: $eth2_mtu (ready for OVN)"
else
    log_message "WARNING" "Provider interface eth2 not found"
fi

log_message "SUCCESS" "Compute-$NODE_ID network configuration complete"
echo -e "\n=== Compute-$NODE_ID Network Setup Complete ===\n"
echo -e "NOTE: OVN tunnel MTU (1442) will be configured during OpenStack deployment\n"
