# OpenStack Installation Steps

## Clone Repository
```bash
git clone https://github.com/your-repo/openstack-installation.git
cd openstack-installation
```

## Configure Inventory
Edit `inventory.ini`:
```ini
[openstack]
controller ansible_host=10.0.0.10 ansible_user=ubuntu
compute1 ansible_host=10.0.0.11 ansible_user=ubuntu
compute2 ansible_host=10.0.0.12 ansible_user=ubuntu
```

## Run Installation
```bash
ansible-playbook -i inventory.ini main.yml
```

## Verify Installation
```bash
# Check services
openstack service list

# Check endpoints
openstack endpoint list
```

## Next Steps
1. [Configuration Guide](configuration.md) 