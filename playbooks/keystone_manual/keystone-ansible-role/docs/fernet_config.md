# Keystone Ansible Automation – Fernet Key Setup

## Summary

This documentation describes the Fernet and Credential key setup tasks used in the Keystone Ansible automation. These steps are essential for enabling secure token and credential management in OpenStack Keystone.

## What This Does

- **Initialize Fernet Key Repository:**
  - Runs `keystone-manage fernet_setup` as the `keystone` user and group.
  - Creates the directory and keys for Fernet token encryption and validation.
- **Initialize Credential Key Repository:**
  - Runs `keystone-manage credential_setup` as the `keystone` user and group.
  - Sets up the keys for encrypting credentials in the Keystone database.

Both tasks use the `creates` argument to ensure idempotency (they only run if the key files do not already exist).

## Where This Fits

- These tasks are run after installing Keystone and configuring its database, but before starting the Keystone service and bootstrapping the admin account.
- They are essential for a secure and functional Keystone deployment.

## Example Usage

This file is included as part of a role in your main playbook:

```yaml
roles:
  - keystone
```

And within the role’s `tasks/main.yml` or similar:

```yaml
- import_tasks: fernet_config.yml
```

## Prerequisites

- Keystone must be installed.
- The `keystone` user and group must exist.
- `/etc/keystone/` must be writable by the `keystone` user.

## How to Choose the Key Owner

The Fernet and Credential keys must be owned by the `keystone` system user and group. This ensures only the Keystone service can access and manage these keys. Do not change the owner unless you have a custom service user for Keystone.

## How to Use These Keys

After this playbook runs, Keystone will use the Fernet keys to sign and validate authentication tokens, and the Credential keys to encrypt sensitive credentials. You do not need to manually interact with these keys, but you must ensure they are backed up and rotated according to OpenStack security best practices.

## Why This Step Is Needed

Keystone uses Fernet tokens for stateless authentication and Credential keys for encrypting stored credentials. Without these keys, Keystone cannot issue or validate tokens, and secure credential storage will not work.

## References

- [OpenStack Keystone Fernet Tokens](https://docs.openstack.org/keystone/latest/admin/fernet-token-faq.html)
- [OpenStack Keystone Credential Setup](https://docs.openstack.org/keystone/latest/admin/credential-setup.html)
