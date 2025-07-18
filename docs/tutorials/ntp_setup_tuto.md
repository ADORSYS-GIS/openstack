# NTP Setup Tutorial

As discussed in the [NTP documentation](/docs/ntp_docs.md), NTP (Network Time Protocol) is used to synchronize time across all servers in an infrastructure. In this tutorial, we'll learn how to install and configure NTP using an Ansible playbook.

Ansible automates tasks through _playbooks_, which define the desired state of systems. We'll write a playbook to install NTP on all servers.

## Prerequisites

Before proceeding, make sure you understand how playbooks work by reviewing this guide:

- [Ansible Playbook Basics](/docs/tutorials/ansible_tuto.md)

## Playbook Initialization

To begin writing a playbook, you generally follow a common structure made up of the following main keys:

```yaml
name    # The name of the playbook
hosts   # Target servers where tasks will run
become  # Whether to use sudo privileges
tasks   # List of tasks to execute
```

### Understanding the Structure

1. **Name**: For our NTP setup, we give the playbook a descriptive name like "Installing NTP via Ansible"

2. **Hosts**: Specifies the group of servers where the tasks should run. We'll set it to `all`, meaning we want the NTP service installed on all target servers

3. **Become**: Allows tasks to be executed with sudo privileges. Since installing NTP requires elevated permissions, we'll set this to `yes`

4. **Tasks**: Defines the actual steps Ansible should perform. Each task can use modules like the package manager. We'll use `apt` to install the NTP package

Additionally, we use `update_cache: yes` to ensure that the package list is up-to-date before installation, so the latest version of NTP is installed.

Here's our complete playbook:

```yaml
- name: Installing NTP service
  hosts: all
  become: yes
  tasks:
    - name: Install NTP package
      apt:
        name: ntp
        state: present
        update_cache: yes
```

## Running the Playbook

To execute the playbook, run this command:

```bash
ansible-playbook -i inventory.ini playbook.yml
```

The `inventory.ini` file is where all your server identities are placed. Follow this to learn more about `inventory.ini`:

- [Ansible Inventory Documentation](/docs/tutorials/ansible_tuto.md)

## Conclusion

That's it! You've now learned how to install NTP using an Ansible playbook to synchronize time across your servers. This is an essential step in managing distributed systems to ensure consistent timekeeping and prevent potential issues.
