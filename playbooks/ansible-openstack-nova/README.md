# OpenStack Nova Deployment with Ansible

This project automates the complete and robust deployment of OpenStack Nova (Compute Service) along with its minimal dependencies for testing and validation. It uses Vagrant with libvirt to create virtual machines for a controller and compute node, then provisions them with Ansible playbooks to create a fully functional OpenStack environment.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Validation](#validation)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Overview

This project automates the deployment of a minimal OpenStack environment with Nova compute service. It includes:

- Controller node running:
  - MariaDB (database)
  - RabbitMQ (message queue)
  - Keystone (identity service)
  - Glance (image service)
  - Placement (placement service)
  - Nova API, Scheduler, and Conductor services
- Compute node running:
  - Nova Compute service
  - Libvirt for VM management

## Architecture

```
+------------------+     +------------------+
|   Controller     |     |    Compute       |
|                  |     |                  |
|  MariaDB         |     |  Nova Compute    |
|  RabbitMQ        |     |  Libvirt         |
|  Keystone        |     |                  |
|  Glance          |     |                  |
|  Placement       |     |                  |
|  Nova API        |     |                  |
|  Nova Scheduler  |     |                  |
|  Nova Conductor  |     |                  |
+------------------+     +------------------+
         |                        |
         +----------+-------------+
                    |
              +-----+-----+
              |  Network  |
              +-----------+
```

For detailed information about the architecture and service interactions, see:
- [Architecture Documentation](docs/architecture.md)
- [Security Implementation](docs/security.md)

## Prerequisites

- Linux host system (Debian/Ubuntu or RHEL/CentOS)
- Minimum 8GB RAM and 2 CPU cores
- Nested virtualization enabled in BIOS/UEFI
- Internet connectivity for package downloads

## Project Structure

```
.
├── ansible.cfg                 # Ansible configuration
├── cleanup.sh                  # Cleanup script to destroy VMs
├── inventory/                  # Ansible inventory files
│   ├── hosts.ini               # Host definitions
│   └── group_vars/             # Group-specific variables
├── playbooks/                  # Ansible playbooks
│   ├── site.yml                # Main playbook orchestrating deployment
│   ├── install_nova.yml        # Nova-only installation
│   ├── check_dependencies.yml  # Dependency installation
│   └── validate_nova.yml       # Nova validation
├── requirements.yml            # Required Ansible collections
├── roles/                      # Ansible roles for each service
│   ├── common/                 # Common setup tasks
│   ├── mariadb/                # Database setup
│   ├── rabbitmq/               # Message queue setup
│   ├── keystone_minimal/       # Identity service setup
│   ├── glance_minimal/         # Image service setup
│   ├── placement_minimal/      # Placement service setup
│   ├── nova/                   # Compute service setup
│   └── nova_validation/        # Nova validation tasks
├── setup.sh                    # Main setup script
└── Vagrantfile                 # Vagrant configuration
```

## Configuration

### Inventory

The inventory is defined in `inventory/hosts.ini` and group variables in `inventory/group_vars/`.

Key variables to configure:

- `openstack_db_password` - Database password
- `openstack_admin_password` - Admin user password
- `rabbitmq_password` - RabbitMQ password
- Network settings in `hosts_entries`

### Network Configuration

By default, the setup uses:
- Controller IP: 192.168.56.10
- Compute IP: 192.168.56.11
- Private network: 192.168.56.0/24

These can be modified by setting environment variables:
- `CONTROLLER_IP` - Controller node IP address (default: 192.168.56.10)
- `COMPUTE_IP` - Compute node IP address (default: 192.168.56.11)

Example:
```bash
CONTROLLER_IP=192.168.57.10 COMPUTE_IP=192.168.57.11 ./setup.sh
```

The IP addresses can also be modified in:
- `inventory/group_vars/all.yml` - `controller_ip_address` and `compute_ip_address` variables
- `inventory/group_vars/controllers.yml` - `controller_ip` variable
- `inventory/group_vars/computes.yml` - `compute_ip` variable

## Deployment

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd ansible-openstack-nova
   ```

2. Run the setup script:
   ```bash
   ./setup.sh
   ```

The setup script will:
- Install Vagrant and required dependencies
- Set up libvirt and networking
- Create Python virtual environment with Ansible
- Install required Ansible collections
- Start and provision Vagrant VMs

### Setup Script Options

- `--cleanup`: Automatically run cleanup after deployment
- `--force-provision`: Force re-provisioning of existing VMs
- `--timeout=<seconds>`: Set timeout for operations (default: 3600)

Example:
```bash
./setup.sh --cleanup --timeout=7200
```

## Validation

The deployment includes an automated validation process that:
1. Verifies all services are running
2. Uploads a CirrOS test image
3. Creates a test network and security group
4. Launches a test instance
5. Verifies network connectivity to the instance
6. Cleans up all test resources

You can manually run validation with:
```bash
vagrant ssh controller -c "sudo ansible-playbook /home/ubuntu/openstack/playbooks/ansible-openstack-nova/playbooks/validate_nova.yml"
```

## Cleanup

To destroy the VMs and clean up resources:

```bash
./cleanup.sh
```

### Cleanup Script Options

- `--force`: Skip playbook success verification
- `--timeout=<seconds>`: Set timeout for operations (default: 3600)

## Troubleshooting

### Common Issues

1. **Vagrant fails to start VMs**:
   - Ensure nested virtualization is enabled
   - Check available system resources
   - Verify libvirt is running: `systemctl status libvirtd`

2. **Ansible provisioning fails**:
   - Check `vagrant_up.log` for detailed error messages
   - Verify network connectivity between VMs
   - Ensure all passwords are properly set in inventory

3. **Services not starting**:
   - Check service logs on VMs: `journalctl -u <service-name>`
   - Verify database connectivity
   - Check configuration files in `/etc/<service>/`

### Accessing VMs

After deployment, you can access the VMs with:
```bash
vagrant ssh controller
vagrant ssh compute
```

### Checking Service Status

On the controller node:
```bash
sudo systemctl status mariadb
sudo systemctl status rabbitmq-server
sudo systemctl status apache2  # Keystone, Glance, Placement
sudo systemctl status nova-api nova-scheduler nova-conductor nova-novncproxy
```

On the compute node:
```bash
sudo systemctl status nova-compute
sudo systemctl status libvirtd
```

## Security Considerations

This deployment implements several security best practices:

- Services run under dedicated system users for isolation
- File permissions are properly set for configuration files
- Database connections use secure authentication
- Passwords are parameterized and should be changed for production use
- Communication between services is secured where possible
- Fernet tokens are used for Keystone authentication

For detailed information about security implementation, see [Security Documentation](docs/security.md).

For production deployments, additional security measures should be implemented:
- Use HTTPS for all API endpoints
- Implement proper certificate management
- Enable firewall rules to restrict access
- Regularly update and patch all components
- Implement monitoring and logging solutions

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add or update documentation as needed
5. Submit a pull request

## License

This project is licensed under the MIT License. See the LICENSE file for details.