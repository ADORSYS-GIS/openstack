# Role: kvm_config

Configures KVM virtualization and libvirt on OpenStack compute nodes.

## Responsibilities:
- Installs KVM, QEMU, and libvirt packages
- Checks for virtualization hardware support (VT-x/AMD-V)
- Starts and enables libvirt services
- Ensures 'nova' user is in 'libvirt' group

## Variables:
- `kvm_packages`: List of required virtualization packages
- `libvirt_services`: Libvirt-related systemd units to enable

## Notes:
- Uses `kvm-ok` on Ubuntu/Debian to validate CPU support
- For RHEL/CentOS, consider using `virt-host-validate`
