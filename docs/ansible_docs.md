# Ansible

Ansible is an open-source automation tool used for automating applications,
service orchestration, and server configuration management.

## Prerequisites

Before diving into Ansible, installation is necessary. Follow the tutorial on
how to install Ansible here:

- [Ansible Installation](/docs/tutorials/ansible_tuto.md)

## Features

Ansible provides several tools to facilitate server management:

- **OpenSSH**: Used for setting up SSH and generating keys for server
  authentication
- **Ad-hoc Commands**: Used as alternatives to playbooks for quick and simple
  tasks
- **Playbooks**: YAML files containing specific tasks to manage servers, used
  for complex tasks
- **Inventory File**: Contains the list of servers grouped by categories for
  organized management

## How It Works

### SSH Configuration

Ansible relies on SSH to authenticate and configure servers. While you can use a
single SSH key for managing all servers, it is often recommended to use two
separate keys:

- One for personal SSH logins
- Another specifically for automation with Ansible

#### Creation of SSH Keys

SSH is a key aspect that Ansible uses to connect remotely to servers,
eliminating the need for credential passwords each time a user logs in.

To create SSH keys for both personal use and automation, follow these steps:

- **Personal Key (for interactive SSH/logins):**

  ```sh
  ssh-keygen -t ed25519 -f ~/.ssh/personal_key -C "your_email@domain.com"
  ```

- **Ansible Key (for automation tasks):**

  ```sh
  ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -C "ansible@$(hostname)"
  ```

After creating the keys, copy them to the servers using:

```sh
ssh-copy-id -i ~/.ssh/ansible_key.pub user@server_ip
ssh-copy-id -i ~/.ssh/personal_key.pub user@server_ip
```

Replace `user@server_ip` with the appropriate username and IP address or
hostname of your target server.

For more details, see:

- [SSH Configuration](/docs/tutorials/ansible_tuto.md)

### Launching a Playbook

Playbooks define the automation logic in a structured way. When you run a
playbook, Ansible:

1. Loads temporary modules to the remote server
2. Executes the tasks (e.g., install packages, start services)
3. Removes the modules after execution

For more details on playbooks:

- [Ansible Playbook Guide](/docs/tutorials/ansible_tuto.md)

### Ad-hoc Commands

Ad-hoc commands are ideal for executing quick operations without creating a
playbook. Examples include reboots, file transfers, and directory management.

To learn more about ad-hoc commands, see:

- [Ad-hoc Commands](/docs/tutorials/ansible_tuto.md)
- [Ad-hoc (Ansible Docs)](https://docs.ansible.com/ansible/2.8/user_guide/intro_adhoc.html)

## Server Management

Ansible excels at server management by providing:

- **Playbooks**: Makes task handover between teams seamless, as all required
  tasks are documented in playbooks
- **Inventory Files**: Organizes server IP addresses by groups, making it easy
  to manage and assign tasks
- **SSH Key**: Automates authentication, making server access and management
  more efficient

## What If Ansible Becomes Outdated?

If Ansible becomes outdated or no longer maintained, other modern tools can be
used for infrastructure automation and server management:

- [Chef](https://docs.chef.io/manage/)
- [SaltStack](https://github.com/saltstack/salt)
- [Pulumi](https://www.pulumi.com/)
- [Puppet](https://www.puppet.com/)

Each tool has its specific strengths:

| Tools     | Language   | Best Used For                                |
| --------- | ---------- | -------------------------------------------- |
| Chef      | Ruby       | Complex enterprise environments              |
| SaltStack | YAML       | Large-scale deployments                      |
| Pulumi    | Various    | Cloud infrastructure and resource management |
| Puppet    | Puppet DSL | Large-scale environments                     |
