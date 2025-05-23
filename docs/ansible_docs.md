# Ansible

Ansible is an open-source automation tool used for automating applications, service orchestration, and the configuration and management of servers.

## Prerequisites

Before diving into Ansible, its installation is greatly necessary. To do so, follow the tutorial on how to install Ansible here:

- [Ansible Installation](/docs/tutorials/ansible_tuto.md)

## Features

Ansible provides several tools to facilitate server management:

- **OpenSSH**: Used for setting up SSH and generating keys for authenticating with servers.

- **Ad-hoc Commands**: These are used as alternatives to playbooks, typically for quick and simple tasks.

- **Playbooks**: These are YAML files containing specific tasks to manage servers, commonly used for more complex tasks.

- **Inventory File**: Contains the list of servers grouped by categories, allowing for organized management of your infrastructure.

## How It Works

### SSH Configuration

Ansible relies on SSH to authenticate and configure servers. While you can use a single SSH key for managing all servers, it is often recommended to use two separate keys for different tasks: one for personal SSH logins and another specifically for automation with Ansible.

#### Creation of SSH Keys

SSH is a key aspect that Ansible uses to connect remotely to all the servers, eliminating the need for credential passwords each time a user logs in.

To set up the SSH key, follow the tutorials in:

- [SSH Configuration](/docs/tutorials/ansible_tuto.md)

### Launching a Playbook

Playbooks define the automation logic in a structured way. When you run a playbook, Ansible loads temporary modules to the remote server to execute the tasks (e.g., install packages, start services). After execution, these modules are removed.

For more details on playbooks:

- [Ansible Playbook Guide](/docs/tutorials/ansible_tuto.md)

### Ad-hoc Commands

Ad-hoc commands are ideal for executing quick operations without creating a playbook. Examples include reboots, file transfers, and directory management.

Ad-hoc commands also allow for fast and rapid management of servers. Follow [Ad-hoc Commands](/docs/tutorials/ansible_tuto.md) to learn more about ad-hoc commands.

## Server Management

Ansible is very good for server management due to the fact that it provides:

- **Playbooks**: If the group managing the servers is shifted and another one is placed, as the tasks that are to be run are in the playbook, this will be easy for the new group to understand what is to be done.

- **Inventory Files**: Placing all the servers' IP addresses in a file makes it easy to recall and know for which tasks are for which server. Just like in an inventory file, there is a group of servers for databases and more.

- **SSH Key**: The fact that Ansible uses SSH keys to handle authentication makes it ideal for movement as the login is already an automated action.

## What If Ansible Becomes Outdated?

If Ansible becomes outdated or no longer maintained, there are other modern tools that can be used for infrastructure automation and server management:

- [Chef](https://docs.chef.io/manage/)
- [SaltStack](https://github.com/saltstack/salt)
- [Pulumi](https://www.pulumi.com/)
- [Puppet](https://www.puppet.com/)

Each of them is based on specific aspects:
   Tools     | Language               | Best Used For                     |
 |:----------|:----------------------:|----------------------------------:|
 | Chef      | Ruby                   | Complex enterprise environments   |
 | SaltStack | YAML                   | Large-scale deployments           |
 | Pulumi    | Mainly programming language | Infrastructure provision and manage cloud resources |
 | Puppet    | Puppet DSL             | Large-scale environments          |