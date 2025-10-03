#!/bin/bash
# OpenStack Network Configuration Library
# Source this file in node-specific scripts

set -euo pipefail

# Global configuration
NETPLAN_CONFIG="/etc/netplan/99-openstack-network.yaml"
BACKUP_DIR="/etc/netplan/backup"
LOG_FILE="/var/log/openstack-network-setup.log"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

# Input validation function
validate_node_id() {
    local node_id="$1"
    local node_type="$2"
    
    if [[ ! "$node_id" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "NODE_ID must be a number"
        exit 1
    fi
    
    case "$node_type" in
        "controller"|"storage")
            if [[ "$node_id" -lt 1 || "$node_id" -gt 10 ]]; then
                log_message "ERROR" "$node_type NODE_ID must be between 1-10"
                exit 1
            fi
            ;;
        "compute")
            if [[ "$node_id" -lt 1 || "$node_id" -gt 100 ]]; then
                log_message "ERROR" "$node_type NODE_ID must be between 1-100"
                exit 1
            fi
            ;;
        *)
            log_message "ERROR" "Invalid node type: $node_type"
            exit 1
            ;;
    esac
}

# Backup existing configuration
backup_netplan_config() {
    sudo mkdir -p "$BACKUP_DIR"
    if [[ -f "$NETPLAN_CONFIG" ]]; then
        local backup_file="$BACKUP_DIR/99-openstack-network.yaml.$(date +%Y%m%d_%H%M%S)"
        sudo cp "$NETPLAN_CONFIG" "$backup_file"
        log_message "INFO" "Existing configuration backed up to $backup_file"
    fi
}

# Generate common netplan header
generate_netplan_header() {
    cat << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    # Physical interfaces for bonding
    ens3:
      dhcp4: false
      dhcp6: false
    ens4:
      dhcp4: false
      dhcp6: false
    ens5:
      dhcp4: false
      dhcp6: false
    ens6:
      dhcp4: false
      dhcp6: false
    # Provider network uplink
    eth2:
      dhcp4: false
      dhcp6: false
      mtu: 1500

  bonds:
    # Management and Internal API bond
    bond0:
      interfaces: [ens3, ens4]
      parameters:
        mode: active-backup
        primary: ens3
        mii-monitor-interval: 100
        fail-over-mac-policy: active
      dhcp4: false
      dhcp6: false
      mtu: 1500
EOF
}

# Generate bond1 configuration based on node type
generate_bond1_config() {
    local node_type="$1"
    
    case "$node_type" in
        "controller"|"storage")
            cat << 'EOF'

    # Storage network bond with jumbo frames
    bond1:
      interfaces: [ens5, ens6]
      parameters:
        mode: active-backup
        primary: ens5
        mii-monitor-interval: 100
        fail-over-mac-policy: active
      dhcp4: false
      dhcp6: false
      mtu: 9000
EOF
            ;;
        "compute")
            cat << 'EOF'

    # Storage network bond (standard MTU for compute)
    bond1:
      interfaces: [ens5, ens6]
      parameters:
        mode: active-backup
        primary: ens5
        mii-monitor-interval: 100
        fail-over-mac-policy: active
      dhcp4: false
      dhcp6: false
      mtu: 1500
EOF
            ;;
    esac
}

# Generate VLAN configuration based on node type and ID
generate_vlan_config() {
    local node_type="$1"
    local node_id="$2"
    local base_ip_mgmt base_ip_api base_ip_storage
    
    case "$node_type" in
        "controller")
            base_ip_mgmt=$((10 + node_id - 1))
            base_ip_api=$((10 + node_id - 1))
            base_ip_storage=$((10 + node_id - 1))
            ;;
        "storage")
            base_ip_mgmt=$((20 + node_id))
            base_ip_api=$((20 + node_id))
            base_ip_storage=$((20 + node_id))
            ;;
        "compute")
            base_ip_mgmt=$((30 + node_id))
            base_ip_api=$((30 + node_id))
            base_ip_storage=$((30 + node_id))
            ;;
    esac
    
    cat << EOF

  vlans:
    # Management VLAN
    bond0.10:
      id: 10
      link: bond0
      addresses:
        - 192.168.10.$base_ip_mgmt/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
      mtu: 1500

    # Internal API VLAN
    bond0.11:
      id: 11
      link: bond0
      addresses:
        - 192.168.11.$base_ip_api/24
      mtu: 1500
EOF
    
    # Add storage VLAN configuration
    case "$node_type" in
        "controller"|"storage")
            cat << EOF

    # Storage VLAN with jumbo frames
    bond1.20:
      id: 20
      link: bond1
      addresses:
        - 192.168.20.$base_ip_storage/24
      mtu: 9000
EOF
            ;;
        "compute")
            cat << EOF

    # Storage VLAN (standard MTU for compute access)
    bond1.20:
      id: 20
      link: bond1
      addresses:
        - 192.168.20.$base_ip_storage/24
      mtu: 1500
EOF
            ;;
    esac
}

# Apply and validate netplan configuration
apply_netplan_config() {
    log_message "INFO" "Validating netplan configuration..."
    if sudo netplan try --timeout=30; then
        log_message "SUCCESS" "Configuration validated and applied successfully"
    else
        log_message "ERROR" "Configuration validation failed"
        exit 1
    fi
}

# Verify interface status
verify_interfaces() {
    local node_type="$1"
    
    log_message "INFO" "Verifying interface status..."
    
    # Check bonds
    for bond in bond0 bond1; do
        if ip link show "$bond" &>/dev/null; then
            local mtu=$(ip link show "$bond" | grep -o 'mtu [0-9]*' | cut -d' ' -f2)
            log_message "INFO" "$bond: UP, MTU: $mtu"
        else
            log_message "WARNING" "$bond: Not found"
        fi
    done
    
    # Check VLANs
    for vlan in bond0.10 bond0.11 bond1.20; do
        if ip link show "$vlan" &>/dev/null; then
            local mtu=$(ip link show "$vlan" | grep -o 'mtu [0-9]*' | cut -d' ' -f2)
            local ip=$(ip addr show "$vlan" | grep 'inet ' | awk '{print $2}' | head -1)
            log_message "INFO" "$vlan: UP, MTU: $mtu, IP: ${ip:-'Not assigned'}"
        else
            log_message "WARNING" "$vlan: Not found"
        fi
    done
    
    # Verify jumbo frame capability for storage nodes
    if [[ "$node_type" == "controller" || "$node_type" == "storage" ]]; then
        if ip link show bond1.20 | grep -q "mtu 9000"; then
            log_message "SUCCESS" "Jumbo frames (9000 MTU) configured correctly on storage network"
        else
            log_message "ERROR" "Jumbo frames not configured on storage network"
        fi
    fi
}
