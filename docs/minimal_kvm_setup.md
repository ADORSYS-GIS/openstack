# Install QEMU, KVM, and Libvirt on Ubuntu Server using Ansible

This guide documents how to use Ansible to install and configure QEMU, KVM, and Libvirt on Ubuntu servers without a graphical interface.

## What It Does

- Installs virtualization tools: `qemu-kvm`, `libvirt`, `bridge-utils`, `virtinst`
- Starts and enables the `libvirtd` service
- Adds the current user to `kvm` and `libvirt` groups

## Files

- [`scripts/minimal_kvm_setup.yml`](../scripts/minimal_kvm_setup.yml): Ansible playbook to automate installation
- [`inventory.ini`](../inventory.ini): Inventory file listing target Ubuntu hosts
- [`docs/minimal_kvm_setup.md`](minimal_kvm_setup.md): This documentation

## Requirements

- Ubuntu 20.04+ servers with SSH access
- A control node with Ansible installed
- SSH key-based authentication to target servers