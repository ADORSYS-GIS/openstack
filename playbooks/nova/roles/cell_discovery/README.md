# cell_discovery

This role handles the creation and discovery of Nova cells (cell0 and cell1), required for scaling out Nova compute services in an OpenStack deployment.

## Features

- Maps `cell0` (idempotent)
- Creates `cell1` if not present
- Discovers and registers compute hosts

## Variables

| Variable         | Description                          | Default      |
|------------------|--------------------------------------|--------------|
| `nova_manage_cmd` | Path to the `nova-manage` binary     | `/usr/bin/nova-manage` |
| `nova_user`       | System user that owns Nova services | `nova`       |
| `nova_group`      | System group for Nova               | `nova`       |

## Usage

Include this role after `nova_controller` and `nova_compute` roles are complete:

```yaml
- hosts: controller
  roles:
    - cell_discovery
