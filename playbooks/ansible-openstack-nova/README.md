# OpenStack Nova Setup with Vagrant and Ansible

This project provides an automated setup for a minimal OpenStack Nova environment using Vagrant and Ansible. It creates two virtual machines (controller and compute) and deploys a basic OpenStack Nova setup with all necessary services.

## Project Overview

The setup includes:
- **Controller VM**: Runs OpenStack control plane services
  - Keystone (Identity)
  - Glance (Image)
  - Placement (Resource tracking)
  - Nova Controller
- **Compute VM**: Runs Nova compute service
- **Libvirt/KVM**: Used as the hypervisor
- **Ansible**: Used for provisioning and configuration management

## Architecture

```
+------------------+     +------------------+
|   Controller     |     |    Compute       |
|                  |     |                  |
| Keystone         |     | Nova Compute     |
| Glance           |     | Libvirt/KVM      |
| Placement        |     |                  |
| Nova Controller  |     |                  |
+------------------+     +------------------+
         |                        |
         +------------------------+
                  |
            Management Network
                  |
            (192.168.56.0/24)
```

## Prerequisites

- Linux system with KVM support
- Minimum 8GB RAM and 2 CPU cores
- Internet connectivity (for initial setup)

## Quick Start

1. **Basic Setup**:
   ```bash
   ./setup.sh
   ```

2. **Access the VMs**:
   ```bash
   # SSH into controller
   vagrant ssh controller
   
   # SSH into compute node
   vagrant ssh compute
   ```

3. **Test the Setup**:
   ```bash
   ./test-setup.sh
   ```

4. **Cleanup**:
   ```bash
   ./cleanup.sh
   ```

## Advanced Usage

### Handling Network Issues

If you encounter network connectivity issues with the default box:

1. **Automatic local box creation**:
   ```bash
   # The setup script will automatically try to create a local box
   ./setup.sh
   ```

2. **Manual local box creation**:
   ```bash
   # Create and add a local box manually
   ./add-local-box.sh
   
   # Use the local box
   VAGRANT_BOX=ubuntu2004 ./setup.sh
   ```

3. **Offline mode** (requires pre-installed boxes):
   ```bash
   ./setup.sh --offline
   ```

### Environment Variables

- `VAGRANT_BOX`: Specify a different Vagrant box (default: generic/ubuntu2004)
- `CONTROLLER_IP`: Controller VM IP address (default: 192.168.56.10)
- `COMPUTE_IP`: Compute VM IP address (default: 192.168.56.11)

### Script Options

**setup.sh**:
```bash
./setup.sh                    # Basic setup
./setup.sh --force-provision  # Force Ansible provisioning
./setup.sh --offline          # Offline mode (requires pre-installed boxes)
./setup.sh --cleanup          # Cleanup after setup
VAGRANT_BOX=ubuntu2004 ./setup.sh  # Use a specific box
```

**cleanup.sh**:
```bash
./cleanup.sh        # Basic cleanup
./cleanup.sh --force # Force cleanup without playbook success check
```

**add-local-box.sh**:
```bash
./add-local-box.sh                    # Create and add default local box
./add-local-box.sh --box-name=mybox   # Use custom box name
./add-local-box.sh --box-file=/path/to/box  # Add existing box file
```

## Testing the Setup

After successful setup:
1. SSH into the controller VM: `vagrant ssh controller`
2. Source the OpenStack admin credentials: `source ~/admin-openrc.sh`
3. Run OpenStack commands:
   ```bash
   openstack server list
   openstack image list
   openstack network list
   ```

## Project Structure

```
├── setup.sh              # Main setup script
├── cleanup.sh            # Cleanup script
├── add-local-box.sh      # Local box creation helper
├── test-setup.sh         # Setup verification script
├── Vagrantfile           # Vagrant configuration
├── ansible.cfg           # Ansible configuration
├── requirements.yml      # Ansible collections requirements
├── inventory/            # Ansible inventory files
├── playbooks/            # Ansible playbooks
└── roles/                # Ansible roles for each service
```

## Services Deployed

- **Keystone**: Identity service with default admin user
- **Glance**: Image service with CirrOS test image
- **Placement**: Resource tracking for Nova
- **Nova**: Compute service with controller and compute components
- **MariaDB**: Database backend for all services
- **RabbitMQ**: Message queue for inter-service communication

## Troubleshooting

### Box Download Issues
If the setup fails due to box download issues:
1. Try running `./add-local-box.sh` to create a local box
2. Use `VAGRANT_BOX=ubuntu2004 ./setup.sh` to use the local box
3. Check network connectivity and firewall settings

### VM Provisioning Failures
If VM provisioning fails:
1. Check `vagrant_up.log` for detailed error messages
2. Try `./setup.sh --force-provision` to re-run Ansible
3. Verify system resources (RAM, CPU, disk space)

### Service Access Issues
If you cannot access OpenStack services:
1. Verify VMs are running: `vagrant status`
2. Check service status inside controller VM
3. Verify network connectivity between VMs

## Security Notes

- Default passwords are used for demonstration purposes only
- Host key checking is disabled for development convenience
- Not suitable for production use without security hardening

## Requirements

- Vagrant >= 2.4.1
- vagrant-libvirt plugin >= 0.12.2
- libvirt/KVM
- Ansible >= 8.7.0
- Minimum 8GB RAM and 2 CPU cores