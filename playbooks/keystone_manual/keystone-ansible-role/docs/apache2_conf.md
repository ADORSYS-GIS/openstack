# Keystone Ansible Automation – Apache2 Configuration

## Summary

This documentation describes the Apache2 configuration tasks for OpenStack Keystone using Ansible. These steps ensure Apache2 is properly configured and restarted to serve Keystone.

## What This Does

- (Optional) Inserts the `ServerName localhost` directive into `/etc/apache2/apache2.conf` if not present.
- Restarts the Apache2 service to apply configuration changes.

## Where This Fits

- Run after Keystone and Apache2 are installed and configured.

## Example Usage

This file is included as part of a role in your main playbook:

```yaml
roles:
  - keystone
```

And within the role’s `tasks/main.yml` or similar:

```yaml
- import_tasks: apache2_conf.yml
```

## Prerequisites

- Apache2 must be installed.
- The playbook must be run with sufficient privileges to modify Apache2 configuration and restart the service.

## How to Choose the Apache2 Configuration

The configuration here ensures that Apache2 is set up to serve Keystone correctly. The `ServerName localhost` directive is added to avoid warnings and ensure proper operation. If you are using a different hostname or need to customize Apache2 further, adjust the configuration line in the Ansible task accordingly.

To change the configuration, modify the Ansible task in `apache2_conf.yml`:

```yaml
lineinfile:
  path: /etc/apache2/apache2.conf
  line: "ServerName your-hostname"
  insertafter: '^#ServerRoot = "/etc/apache2"'
  state: present
  backup: yes
```

## How to Use the Configured Apache2 Service

After this playbook runs, Apache2 will be configured and restarted. Keystone will be served via Apache2, and you can access the Keystone API through the configured endpoints.

## Why This Step Is Needed

Keystone uses Apache2 as its web server. Proper configuration and restarting of Apache2 are required for Keystone to function and be accessible.
