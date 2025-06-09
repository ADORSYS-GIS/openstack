# OpenStack Installation Guide

## Overview

This repository contains Ansible playbooks and documentation for installing and configuring OpenStack on a Mini PC. The installation is designed to work with Ubuntu 20.04/22.04 and uses DevStack for deployment.

## Hardware Specifications

### Mini PC Configuration

- **CPU**: AMD Ryzen 7 5825U (8 cores, 16 threads)
  - Base Frequency: 2.0 GHz
  - Max Boost: 4.5 GHz
  - Cache: L1 (512KB), L2 (4MB), L3 (16MB)
- **Memory**: 32GB DDR4
- **Storage**: 1TB NVMe SSD
- **Network**: 2.5GbE Ethernet
- **Virtualization**: AMD-V enabled

### Resource Requirements

- **CPU**: Minimum 8 cores (16 threads)
- **RAM**: Minimum 16GB (32GB recommended)
- **Storage**:
  - System: 100GB
  - OpenStack: 200GB
  - Available for VMs: ~700GB
- **Network**: 1GbE minimum (2.5GbE recommended)

## System Requirements

### Operating System

- Ubuntu 20.04 LTS or Ubuntu 22.04 LTS
- 64-bit architecture
- Fresh installation recommended

### Software Dependencies

- Python 3.8 or later
- Ansible 2.9 or later
- Git
- OpenSSH Server
- Network Manager

### Network Requirements

- Static IP address
- DNS resolution
- Open ports:
  - 22 (SSH)
  - 80, 443 (Horizon)
  - 5000 (Keystone)
  - 8774 (Nova)
  - 9696 (Neutron)
  - 9292 (Glance)

## Installation Process

### 1. System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3-pip python3-dev git

# Install Ansible
sudo pip3 install ansible
```

### 2. Clone Repository

```bash
git clone https://github.com/ADORSYS-GIS/openstack.git
cd openstack && cd openstack-installation
```

### 3. Configure Inventory

Edit `inventory.ini` to match your network configuration:

```ini
[openstack]
node1 ansible_host=YOUR_IP ansible_user=YOUR_USER ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### 4. Run Installation

```bash
ansible-playbook -i inventory.ini playbook.yml
```

## Post-Installation Configuration

### 1. Verify Installation

Run the test playbook:

```bash
ansible-playbook -i inventory.ini test-openstack.yml
```

### 2. Initial Setup

1. Access Horizon dashboard at `http://YOUR_IP/dashboard`
2. Log in with:
   - Username: admin
   - Password: devstack

### 3. Security Hardening

1. Change default passwords
2. Configure firewall rules
3. Enable SSL/TLS
4. Set up backup procedures

## Service Verification

### Core Services

- Keystone (Identity)
- Nova (Compute)
- Neutron (Networking)
- Glance (Image)
- Horizon (Dashboard)

### Supporting Services

- MySQL
- RabbitMQ
- Open vSwitch

## Troubleshooting

### Common Issues

1. Service not starting
2. Network connectivity issues
3. Resource constraints
4. Permission problems

### Logs Location

- OpenStack logs: `/opt/stack/logs/`
- System logs: `/var/log/`
- Ansible logs: `./logs/`

## Maintenance

### Regular Tasks

1. System updates
2. Backup procedures
3. Resource monitoring
4. Security patches

### Monitoring

- CPU usage
- Memory utilization
- Storage capacity
- Network traffic

## Documentation Structure

```sh
docs/
├── tutorial/
│   ├── 01-preparation.md
│   ├── 02-installation.md
│   ├── 03-configuration.md
│   ├── 04-verification.md
│   └── 05-troubleshooting.md
├── reference/
│   ├── hardware.md
│   ├── networking.md
│   └── security.md
└── api/
    └── openstack-api.md
```

## Support

For issues and support:

1. Check the troubleshooting guide
2. Review the logs
3. Open an issue in the repository

## License

This project is licensed under the MIT License - see the LICENSE file for details.
