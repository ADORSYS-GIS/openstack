# Keystone Ansible Automation – OpenRC File Creation

## Summary

This documentation describes the creation of the OpenStack OpenRC file using Ansible. The OpenRC file is used to set environment variables for OpenStack CLI access.

## What This Does

- Creates an OpenRC file with the necessary environment variables for OpenStack authentication.
- Ensures the OpenRC file is sourced in the user's shell configuration (e.g., `.zshrc`).

## Where This Fits

- Run after Keystone is bootstrapped and endpoints are available.

## Example Usage

This file is included as part of a role in your main playbook:

```yaml
roles:
  - keystone
```

And within the role’s `tasks/main.yml` or similar:

```yaml
- import_tasks: create_openrc.yml
```

## Prerequisites

- The target user and home directory must exist.
- The playbook must be run with sufficient privileges to write to the user's home directory.

## How to Choose the Target User

The OpenRC file should be created in the home directory of the Linux user who will use the OpenStack CLI. This is usually your regular login user (e.g., `ubuntu`, `usherking`, or another admin account).

To change the target user, modify the `dest`, `owner`, and `group` fields in the Ansible task. For example:

```yaml
copy:
  dest: "/home/usherking/openrc"
  owner: usherking
  group: usherking
  ...
```

## How to Use the OpenRC File

After the playbook runs, log in as your user and run:

```sh
source ~/openrc
```

Now you can use OpenStack CLI commands, for example:

```sh
openstack server list
```

## Why the OpenRC File Is Needed

The OpenRC file contains environment variables needed to authenticate and interact with OpenStack services using the CLI. Sourcing this file in your shell session allows you to run OpenStack commands as a specific OpenStack user.
