# Role: nova_compute

Installs and configures Nova Compute service on compute nodes.

## Responsibilities:
- Install nova-compute package
- Render /etc/nova/nova.conf with controller integration
- Ensure nova-compute service is enabled and running

## Variables:
- `nova_user_password`: Keystone password for nova user
- `controller_host`: Hostname or IP of controller
- `virt_type`: Hypervisor type (e.g., kvm or qemu)

## Notes:
- Assumes libvirt and KVM are configured (via `kvm_config` role)
