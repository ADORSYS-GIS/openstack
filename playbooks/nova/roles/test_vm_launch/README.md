# test_vm_launch

This role launches a temporary test VM to validate the correct functioning of the Nova compute stack in an OpenStack environment.

## Features

- Provisions a test instance using a known flavor/image/network
- Waits for VM to reach `ACTIVE` state
- Optionally cleans up VM and keypair afterward
- Fully idempotent and repeatable

## Variables

| Variable               | Description                         | Default       |
|------------------------|-------------------------------------|---------------|
| `test_vm_name`         | Name of the test VM                 | `test-instance` |
| `test_vm_image`        | Glance image name to use            | `cirros`      |
| `test_vm_flavor`       | Flavor name to use                  | `m1.tiny`     |
| `test_vm_network`      | Network name to attach              | `private`     |
| `test_vm_keypair`      | SSH keypair name                    | `test-key`    |
| `test_vm_create_keypair` | Whether to create/delete keypair   | `true`        |
| `test_vm_key_path`     | Path to generated local key         | `/tmp/test-key.pem` |
| `test_vm_timeout`      | Timeout for instance launch         | `300`         |
| `test_vm_cleanup`      | Whether to delete VM + key after test | `true`      |

## Usage

```yaml
- hosts: controller
  roles:
    - test_vm_launch
