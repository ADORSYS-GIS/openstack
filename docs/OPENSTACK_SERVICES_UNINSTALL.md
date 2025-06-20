# OpenStack Services Uninstallation Guide

This document provides instructions for uninstalling OpenStack services that were implemented using Ansible in this repository.

## OpenStack Services Implemented

Based on the repository structure, the following OpenStack components were implemented:

1. **DevStack Installation**
   - DevStack environment setup
   - OpenStack services deployment
   - Development environment configuration

2. **Environment Setup**
   - System prerequisites
   - Network configuration
   - User setup and permissions

## Manual Uninstallation Instructions

### 1. Stop OpenStack Services

```bash
# Stop all OpenStack services
sudo systemctl stop devstack@*
sudo systemctl stop openstack-*
sudo systemctl stop neutron-*
sudo systemctl stop nova-*
sudo systemctl stop glance-*
sudo systemctl stop keystone
sudo systemctl stop mysql
sudo systemctl stop rabbitmq-server

# Disable services from starting at boot
sudo systemctl disable devstack@*
sudo systemctl disable openstack-*
sudo systemctl disable neutron-*
sudo systemctl disable nova-*
sudo systemctl disable glance-*
sudo systemctl disable keystone
sudo systemctl disable mysql
sudo systemctl disable rabbitmq-server
```

### 2. Remove DevStack Installation

```bash
# Navigate to DevStack directory
cd ~/devstack

# Run unstack script
./unstack.sh

# Clean up DevStack
./clean.sh

# Remove DevStack directory
cd ~
rm -rf devstack
```

### 3. Remove OpenStack Packages

```bash
# Remove OpenStack packages
sudo apt remove python3-openstackclient openstack-* python3-keystone* \
    python3-nova* python3-glance* python3-neutron*
sudo apt purge python3-openstackclient openstack-* python3-keystone* \
    python3-nova* python3-glance* python3-neutron*

# Remove database
sudo apt remove mysql-server mysql-client
sudo apt purge mysql-server mysql-client

# Remove message queue
sudo apt remove rabbitmq-server
sudo apt purge rabbitmq-server

# Clean up dependencies
sudo apt autoremove
```

### 4. Clean Up Network Configuration

```bash
# Remove OpenStack network namespaces
sudo ip netns list | xargs -I {} sudo ip netns delete {}

# Remove OpenStack bridges
sudo ovs-vsctl list-br | while read bridge; do
    sudo ovs-vsctl del-br "$bridge"
done

# Remove virtual network interfaces
sudo ip link show | grep -E 'ovs|br-' | awk -F': ' '{print $2}' | \
    while read interface; do
        sudo ip link delete "$interface"
    done
```

### 5. Remove OpenStack User and Groups

```bash
# Remove OpenStack user
sudo userdel -r stack

# Remove OpenStack groups
sudo groupdel stack
```

## Ansible-based Uninstallation

Create a file named `openstack_services_uninstall.yml`:

```yaml
---
- name: Uninstall OpenStack services
  hosts: all
  become: true
  tasks:
    - name: Stop OpenStack services
      service:
        name: "{{ item }}"
        state: stopped
        enabled: false
      loop:
        - devstack@*
        - openstack-*
        - neutron-*
        - nova-*
        - glance-*
        - keystone
        - mysql
        - rabbitmq-server
      ignore_errors: true

    - name: Run DevStack unstack script
      shell: |
        cd ~/devstack
        ./unstack.sh
        ./clean.sh
      ignore_errors: true

    - name: Remove DevStack directory
      file:
        path: ~/devstack
        state: absent

    - name: Remove OpenStack packages
      apt:
        name:
          - python3-openstackclient
          - openstack-*
          - python3-keystone*
          - python3-nova*
          - python3-glance*
          - python3-neutron*
          - mysql-server
          - mysql-client
          - rabbitmq-server
        state: absent
        autoremove: yes
        purge: yes

    - name: Remove OpenStack network namespaces
      shell: |
        for ns in $(ip netns list); do
          ip netns delete $ns
        done
      ignore_errors: true

    - name: Remove OVS bridges
      shell: |
        for bridge in $(ovs-vsctl list-br); do
          ovs-vsctl del-br "$bridge"
        done
      ignore_errors: true

    - name: Remove virtual network interfaces
      shell: |
        for interface in $(ip link show | grep -E 'ovs|br-' | \
            awk -F': ' '{print $2}'); do
          ip link delete "$interface"
        done
      ignore_errors: true

    - name: Remove OpenStack user and groups
      user:
        name: stack
        state: absent
        remove: yes
      ignore_errors: true
```

To run the uninstallation playbook:

```bash
ansible-playbook -i inventory.ini openstack_services_uninstall.yml
```

## Post-Uninstallation Cleanup

After uninstallation, clean up any remaining configuration files:

```bash
# Remove OpenStack configuration
sudo rm -rf /etc/openstack
sudo rm -rf /etc/keystone
sudo rm -rf /etc/nova
sudo rm -rf /etc/glance
sudo rm -rf /etc/neutron

# Remove database files
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/lib/rabbitmq

# Remove log files
sudo rm -rf /var/log/openstack
sudo rm -rf /var/log/keystone
sudo rm -rf /var/log/nova
sudo rm -rf /var/log/glance
sudo rm -rf /var/log/neutron

# Remove any remaining bridge configurations
sudo rm -f /etc/netplan/*-openstack.yaml
```

## Verification

After uninstallation, verify that all services have been removed:

```bash
# Check service status
systemctl status devstack@*
systemctl status openstack-*
systemctl status neutron-*
systemctl status nova-*
systemctl status glance-*
systemctl status keystone
systemctl status mysql
systemctl status rabbitmq-server

# Check for any remaining OpenStack processes
ps aux | grep -E 'openstack|keystone|nova|glance|neutron'

# Check network status
ip netns list
ovs-vsctl show
brctl show
```

## Note

- Make sure to backup any important data before uninstalling
- Some commands may require sudo privileges
- The uninstallation process may vary depending on your specific setup and customizations
- If you encounter any errors during uninstallation, check the error messages and ensure all dependencies are properly removed
- After uninstallation, you may need to reboot your system to ensure all services are completely removed
- This guide assumes a standard DevStack installation. If you have a custom installation, you may need to modify some steps
