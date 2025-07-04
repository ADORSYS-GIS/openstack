# Keystone Ansible Automation – Database Initialization

## Summary

This documentation describes the database initialization tasks for OpenStack Keystone using Ansible. These steps ensure the Keystone database and user are created and ready for use.

## What This Does

- Installs the required MySQL Python bindings for Ansible.
- Creates the Keystone database if it does not exist.
- Creates the Keystone database user with the necessary privileges.

## Where This Fits

- Run after MariaDB is installed and started, but before Keystone is installed and configured.
- Ensures the database is ready for Keystone to use.

## Example Usage

This file is included as part of a role in your main playbook:

```yaml
roles:
  - keystone
```

And within the role’s `tasks/main.yml` or similar:

```yaml
- import_tasks: db_initialise.yml
```

## Prerequisites

- MariaDB/MySQL server must be installed and running.
- The playbook must be run with sufficient privileges to create databases and users.

## How to Choose the Database and User

The database and user created here are for the Keystone service. You should set the variables `db_name`, `db_user`, and `db_password` to match your desired database name, user, and password for Keystone. These should be unique for security and to avoid conflicts with other services.

To change these, modify your Ansible variables or inventory:

```yaml
vars:
  db_name: keystone
  db_user: keystone
  db_password: strongpassword
```

## How to Use This Database

After this playbook runs, the Keystone service will be able to connect to the database using the credentials you set. Make sure your Keystone configuration file (`/etc/keystone/keystone.conf`) uses these same values for the database connection string.

## Why This Step Is Needed

Keystone requires its own database and user to store identity and token information. This step ensures the database is ready and accessible before you install and configure Keystone.
