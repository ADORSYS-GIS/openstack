# OpenStack Configuration Guide

## Overview
This guide covers the configuration of OpenStack services after installation. It includes initial setup, security hardening, and service optimization.

## Initial Configuration

### 1. Access the Dashboard
- URL: `http://YOUR_IP/dashboard`
- Default credentials:
  - Username: admin
  - Password: devstack

### 2. Change Default Passwords
```bash
# Switch to stack user
sudo su - stack

# Source credentials
source /opt/stack/devstack/openrc

# Change admin password
openstack user password set --password NEW_PASSWORD admin
```

### 3. Configure Project and User
```bash
# Create new project
openstack project create --description "My Project" myproject

# Create new user
openstack user create --password NEW_PASSWORD --project myproject myuser

# Assign role
openstack role add --project myproject --user myuser member
```

## Network Configuration

### 1. Provider Network Setup
```bash
# Create provider network
openstack network create --provider-network-type flat --provider-physical-network physnet1 --external provider

# Create subnet
openstack subnet create --network provider --subnet-range 192.168.1.0/24 --gateway 192.168.1.1 --allocation-pool start=192.168.1.100,end=192.168.1.200 provider-subnet
```

### 2. Self-Service Network Setup
```bash
# Create self-service network
openstack network create selfservice

# Create self-service subnet
openstack subnet create --network selfservice \
    --dns-nameserver 8.8.8.8 --gateway 172.16.1.1 \
    --subnet-range 172.16.1.0/24 selfservice

# Create router
openstack router create router

# Add router interface
openstack router add subnet router selfservice

# Set gateway
openstack router set --external-gateway provider router
```

## Compute Configuration

### 1. Configure Nova
```bash
# Check compute service
openstack compute service list

# Configure flavors
openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny
openstack flavor create --ram 2048 --disk 20 --vcpus 2 m1.small
openstack flavor create --ram 4096 --disk 40 --vcpus 4 m1.medium

# Configure compute node
openstack compute service set --enable <compute-host> nova-compute

# Verify compute node
openstack compute service list
```

### 2. Configure Glance
```bash
# Download test image
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img

# Upload image
openstack image create "cirros" \
    --file cirros-0.4.0-x86_64-disk.img \
    --disk-format qcow2 --container-format bare \
    --public
```

## Security Configuration

### 1. Firewall Rules
```bash
# Configure UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 5000/tcp  # Keystone
sudo ufw allow 8774/tcp  # Nova
sudo ufw allow 9696/tcp  # Neutron
sudo ufw allow 9292/tcp  # Glance
sudo ufw enable
```

### 2. SSL/TLS Configuration
```bash
# Install certbot
sudo apt install certbot python3-certbot-apache

# Obtain certificate
sudo certbot --apache -d your-domain.com
```

### 3. Security Groups
```bash
# Create security group
openstack security group create --description "Basic security group" basic

# Add rules
openstack security group rule create --protocol icmp basic
openstack security group rule create --protocol tcp --dst-port 22 basic
```

## Storage Configuration

### 1. Configure Cinder
```bash
# Check volume service
openstack volume service list

# Create volume type
openstack volume type create --description "SSD" ssd
```

### 2. Configure Swift (if enabled)
```bash
# Create container
openstack container create mycontainer

# Upload object
openstack object create mycontainer myfile.txt
```

## Monitoring Configuration

### 1. Enable Telemetry
```bash
# Check telemetry service
openstack metric list

# Configure alarms
openstack alarm create \
    --name cpu_high \
    --description "CPU usage high" \
    --meter-name cpu_util \
    --threshold 80.0 \
    --comparison-operator gt \
    --statistic avg \
    --period 60 \
    --evaluation-periods 2 \
    --alarm-action "log://" \
    --ok-action "log://"
```

### 2. Configure Logging
```bash
# Configure rsyslog
sudo nano /etc/rsyslog.d/30-openstack.conf

# Add logging configuration
local0.* /var/log/openstack/openstack.log
local1.* /var/log/openstack/nova.log
local2.* /var/log/openstack/neutron.log
```

## Backup Configuration

### 1. Database Backup
```bash
# Create backup script
sudo nano /usr/local/bin/backup-openstack.sh

#!/bin/bash
BACKUP_DIR="/var/backups/openstack"
DATE=$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

# Backup MySQL
mysqldump -u root -p --all-databases > $BACKUP_DIR/mysql-$DATE.sql

# Backup configuration
tar -czf $BACKUP_DIR/config-$DATE.tar.gz /etc/openstack/
```

### 2. Automate Backups
```bash
# Add to crontab
sudo crontab -e

# Add backup schedule
0 2 * * * /usr/local/bin/backup-openstack.sh
```

## Performance Tuning

### 1. Nova Configuration
```bash
# Edit nova.conf
sudo nano /etc/nova/nova.conf

# Add performance settings
[DEFAULT]
cpu_allocation_ratio = 16.0
ram_allocation_ratio = 1.5
disk_allocation_ratio = 1.0
```

### 2. Neutron Configuration
```bash
# Edit neutron.conf
sudo nano /etc/neutron/neutron.conf

# Add performance settings
[DEFAULT]
max_fixed_ips_per_port = 5
max_routes = 100
```

## Next Steps
1. [Verification Guide](verification.md) 