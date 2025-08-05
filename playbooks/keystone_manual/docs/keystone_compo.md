# Keystone Ansible Automation – Keystone and Apache2 Installation

## Summary

This documentation describes the tasks for installing Keystone and Apache2 with the WSGI module using Ansible. These steps are essential for running Keystone as a web service.

## What This Does

- Installs the Keystone package.
- Installs Apache2 and the WSGI module for Python 3.

## Where This Fits

- Run after the database is initialized and before configuring Keystone.

## Example Usage

This file is included as part of a role in your main playbook:

```yaml
roles:
  - keystone
```

And within the role’s `tasks/main.yml` or similar:

```yaml
- import_tasks: keystone_compo.yml
```

## Prerequisites

- The system must have access to the package repositories for Keystone and Apache2.

## How to Choose the Packages

The packages installed here are required for Keystone to run as a web service under Apache2. You can adjust the package names if you are using a different Linux distribution or if you need a different version of the WSGI module. For Ubuntu, the defaults are usually correct.

To change the packages, modify the Ansible task in `keystone_compo.yml`:

```yaml
apt:
  name:
    - keystone
    - apache2
    - libapache2-mod-wsgi-py3
  state: present
  update_cache: yes
```

## How to Use the Installed Services

After this playbook runs, Keystone and Apache2 will be installed and ready for further configuration. You can then proceed to configure Keystone and set up Apache2 to serve the Keystone API.

## Why This Step Is Needed

Keystone requires Apache2 and the WSGI module to serve its API endpoints. Installing these packages is the first step in making Keystone available as a web service.
