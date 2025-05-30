# OpenStack Troubleshooting Guide

## Quick Reference

### Service Status Commands
```bash
# List all services
openstack service list

# List all endpoints
openstack endpoint list

# Check service status
sudo systemctl status <service-name>

# View service logs
sudo tail -f /var/log/<service-name>/<service-name>.log
```

### Common Log Locations
```bash
/var/log/keystone/    # Identity service
/var/log/nova/        # Compute service
/var/log/neutron/     # Network service
/var/log/glance/      # Image service
/var/log/cinder/      # Block storage
```

## Common Issues & Solutions

### 1. Service Endpoint Issues

#### Missing Service Endpoints
```bash
# Register missing service
openstack service create --name <service> --description "<description>" <service-type>

# Create missing endpoint
openstack endpoint create --region RegionOne <service-type> public http://<host-ip>:<port>
```

#### Service Not Responding
```bash
# Restart service
sudo systemctl restart <service-name>

# Verify service status
sudo systemctl status <service-name>
```

### 2. Authentication Issues

#### Token Validation Fails
```bash
# Source credentials
source /opt/stack/devstack/openrc

# Verify token
openstack token issue
```

#### Connection Refused
```bash
# Check service status
sudo systemctl status <service-name>

# Verify firewall
sudo ufw status

# Check port
sudo netstat -tulpn | grep <port>
```

### 3. Resource Issues

#### High CPU/Memory Usage
```bash
# Check resource usage
top -b -n 1
free -h
df -h

# Check service resource usage
ps aux | grep <service-name>
```

#### Storage Issues
```bash
# Check storage
df -h /var/lib/<service-name>

# Verify volumes
openstack volume list
```

### 4. Network Issues

#### Instance Network Problems
```bash
# Check network configuration
openstack network show <network-name>
openstack subnet show <subnet-name>
openstack router show <router-name>

# Verify security groups
openstack security group list
```

#### DNS Resolution Issues
```bash
# Check DNS
cat /etc/resolv.conf
nslookup google.com
```

## Test Playbook Failures

### 1. Missing Service Endpoints
```bash
# Error: public endpoint for <service> service in RegionOne region not found

# Solution:
openstack service create --name <service> --description "<description>" <service-type>
openstack endpoint create --region RegionOne <service-type> public http://<host-ip>:<port>
```

### 2. Service Not Available
```bash
# Error: <service> service not available

# Solution:
sudo systemctl restart <service-name>
sudo systemctl status <service-name>
```

## Recovery Procedures

### 1. Service Recovery
```bash
# Restart all services
sudo systemctl restart keystone nova-compute neutron-server glance-api

# Verify recovery
openstack service list
openstack endpoint list
```

### 2. Data Recovery
```bash
# Database recovery
mysql -u root -p < /var/backups/openstack/mysql-$(date +%Y%m%d).sql

# Configuration recovery
sudo tar -xzf /var/backups/openstack/config-$(date +%Y%m%d).tar.gz -C /
```

## Next Steps
1. [Verification Guide](04-verification.md)
2. [Maintenance Guide](../reference/maintenance.md)
3. [Security Guide](../reference/security.md) 