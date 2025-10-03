#!/bin/bash
# Keepalived and HAProxy HA Setup for OpenStack
# Usage: ./keepalived-setup.sh <NODE_PRIORITY> <NODE_NAME>
# Example: ./keepalived-setup.sh 100 controller-1

set -euo pipefail

# Configuration parameters
KEEPALIVED_CONFIG="/etc/keepalived/keepalived.conf"
HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"
VIP="192.168.11.100"
INTERFACE="bond0.11"
NODE_PRIORITY="${1:-100}"  # Priority: 100 (master), 90, 80
NODE_NAME="${2:-controller-1}"

echo -e "\n=== Configuring HA Services for $NODE_NAME (Priority: $NODE_PRIORITY) ===\n"

# Install required packages
sudo apt update
sudo apt install -y keepalived haproxy

# Configure HAProxy for OpenStack services
sudo tee "$HAPROXY_CONFIG" > /dev/null << 'EOF'
global
    daemon
    group haproxy
    log stdout local0
    maxconn 4000
    pidfile /var/run/haproxy.pid
    user haproxy

defaults
    log global
    maxconn 4000
    option redispatch
    retries 3
    timeout http-request 10s
    timeout queue 1m
    timeout connect 10s
    timeout client 1m
    timeout server 1m
    timeout check 10s

# HAProxy Stats
listen stats
    bind 192.168.11.100:8080
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
    stats realm HAProxy\ Statistics
    stats auth admin:openstack

# OpenStack API Endpoints
frontend openstack_api_cluster
    bind 192.168.11.100:80
    bind 192.168.11.100:443
    bind 192.168.11.100:5000   # Keystone
    bind 192.168.11.100:8774   # Nova
    bind 192.168.11.100:9696   # Neutron
    bind 192.168.11.100:8776   # Cinder
    bind 192.168.11.100:9292   # Glance
    default_backend openstack_api_nodes

backend openstack_api_nodes
    balance roundrobin
    option httpchk GET /
    server controller-1 192.168.11.10:80 check inter 2000 rise 2 fall 5
    server controller-2 192.168.11.11:80 check inter 2000 rise 2 fall 5
    server controller-3 192.168.11.12:80 check inter 2000 rise 2 fall 5

# MariaDB Galera Cluster
listen galera_cluster
    bind 192.168.11.100:3306
    balance source
    option mysql-check user haproxy
    server controller-1 192.168.11.10:3306 check weight 1
    server controller-2 192.168.11.11:3306 check weight 1
    server controller-3 192.168.11.12:3306 check weight 1

# RabbitMQ Cluster
listen rabbitmq_cluster
    bind 192.168.11.100:5672
    balance roundrobin
    server controller-1 192.168.11.10:5672 check inter 2000 rise 2 fall 3
    server controller-2 192.168.11.11:5672 check inter 2000 rise 2 fall 3
    server controller-3 192.168.11.12:5672 check inter 2000 rise 2 fall 3
EOF

# Configure Keepalived with HAProxy health checks
sudo tee "$KEEPALIVED_CONFIG" > /dev/null << EOF
vrrp_script chk_haproxy {
    script "/bin/curl -f http://localhost:8080/stats || exit 1"
    interval 2
    weight -2
    fall 3
    rise 2
}

vrrp_instance VI_OPENSTACK {
    state BACKUP
    interface $INTERFACE
    virtual_router_id 51
    priority $NODE_PRIORITY
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass openstack_ha_$(date +%s | sha256sum | head -c 8)
    }
    virtual_ipaddress {
        $VIP
    }
    track_script {
        chk_haproxy
    }
    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault "/etc/keepalived/notify_fault.sh"
}
EOF

# Create notification scripts
sudo mkdir -p /etc/keepalived

# Master notification script
sudo tee /etc/keepalived/notify_master.sh > /dev/null << 'EOF'
#!/bin/bash
logger "Keepalived: Transitioned to MASTER state"
systemctl restart haproxy
EOF

# Backup notification script
sudo tee /etc/keepalived/notify_backup.sh > /dev/null << 'EOF'
#!/bin/bash
logger "Keepalived: Transitioned to BACKUP state"
EOF

# Fault notification script
sudo tee /etc/keepalived/notify_fault.sh > /dev/null << 'EOF'
#!/bin/bash
logger "Keepalived: Transitioned to FAULT state"
systemctl stop haproxy
EOF

# Make scripts executable
sudo chmod +x /etc/keepalived/notify_*.sh

# Enable and start services
sudo systemctl enable haproxy keepalived
sudo systemctl restart haproxy
sudo systemctl restart keepalived

# Verify configuration
echo -e "\n=== HA Services Configuration Complete ===\n"
echo -e "VIP: $VIP configured on interface: $INTERFACE"
echo -e "HAProxy Stats: http://$VIP:8080/stats (admin/openstack)"
echo -e "Node Priority: $NODE_PRIORITY\n"

# Check service status
sudo systemctl status haproxy --no-pager -l
sudo systemctl status keepalived --no-pager -l
