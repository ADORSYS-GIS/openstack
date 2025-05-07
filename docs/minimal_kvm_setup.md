# Installating QEMU/KVM/Libvirt via Ansible

This Script provides Linux hosts with the necessary virtualization stack `QEMU`, `KVM`, and `Libvirt` to serve as compute nodes or general VM hosts within a virtualized infrastructure.

## What This Playbook Does

The playbook automates the following tasks:

1. **Installs virtualization packages**, including:
   - `qemu-kvm`: The QEMU full system emulator with KVM support.
   - `libvirt-daemon-system` and `libvirt-clients`: Provides the libvirtd service and CLI tools to manage VMs.
   - `bridge-utils`: For networking between host and VMs.
   - `virtinst` and `virt-manager`: Tools for creating and managing virtual machines.

2. **Enables and starts the `libvirtd` service** to ensure virtualization is running.

3. **Adds the user running Ansible to the `libvirt` and `kvm` groups**, allowing VM management without root privileges.

## Requirements

- A control node with **Ansible** installed.
- One or more target hosts running **Ubuntu** or **Debian**.
- SSH access from the control node to the target hosts.

## How to Use

 1. Clone or download the playbook files.

 2. Update the inventory file

Edit `inventory.ini` with the IP addresses and usernames of your target machines:

```ini
[kvm_hosts]
192.168.122.10 ansible_user=your_username ansible_ssh_private_key_file=~/.ssh/id_rsa
