# Keystone Ansible Automation – Keystone Bootstrap

## Summary

This documentation describes the bootstrap process for OpenStack Keystone using Ansible. Bootstrapping initializes the Keystone service with an admin account and endpoint URLs.

## What This Does

- Ensures the Keystone log file exists and is owned by the keystone user.
- Populates the Keystone database using `keystone-manage db_sync`.
- Bootstraps Keystone with admin credentials and endpoint URLs using `keystone-manage bootstrap`.

## Where This Fits

- Run after Keystone is installed, configured, and Fernet/Credential keys are set up.

## Example Usage

This file is included as part of a role in your main playbook:

```yaml
roles:
  - keystone
```

And within the role’s `tasks/main.yml` or similar:

```yaml
- import_tasks: keystone_bootstrap.yml
```

## Prerequisites

- Keystone must be installed and configured.
- The database must be initialized and accessible.
- The `keystone` user must have permission to write to `/var/log/keystone/`.

## How to Set Admin Credentials and Endpoints

The admin password and endpoint URLs used in this step are critical for accessing and managing your OpenStack cloud. Set the variables `keystone_admin_password`, `keystone_admin_url`, `keystone_internal_url`, `keystone_public_url`, and `keystone_region` to match your desired configuration. These values will be used to bootstrap the Keystone service and should be kept secure.

To change these, modify your Ansible variables or inventory:

```yaml
vars:
  keystone_admin_password: strongpassword
  keystone_admin_url: http://controller:5000/v3/
  keystone_internal_url: http://controller:5000/v3/
  keystone_public_url: http://controller:5000/v3/
  keystone_region: RegionOne
```

## How to Use the Bootstrapped Service

After this playbook runs, you can use the admin credentials and endpoints to authenticate with Keystone and perform administrative tasks. Make sure to store these credentials securely and update your OpenRC file to use them.

## Why This Step Is Needed

Bootstrapping Keystone initializes the service with an admin account and endpoint URLs, making it possible to manage OpenStack identities and services. Without this step, you cannot authenticate or use Keystone.
