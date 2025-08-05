# flavors

This role creates standard VM flavor definitions in OpenStack using the `openstack.cloud.compute_flavor` module.

## Features

- Creates standard instance types (`m1.tiny`, `m1.small`, etc.)
- Fully idempotent
- Uses Keystone credentials from the environment (`admin-openrc.sh`)

## Variables

| Variable            | Description                          | Default      |
|---------------------|--------------------------------------|--------------|
| `openstack_flavors` | List of flavor definitions           | See defaults |
| `flavor_project`    | Project under which to create flavors| `admin`      |
| `flavor_region`     | Target region name                   | `RegionOne`  |

## Usage

```yaml
- hosts: controller
  roles:
    - flavors
