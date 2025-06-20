# Getting Started with Ansible

Welcome to this beginner's guide to Ansible, a powerful automation tool that helps you manage, configure, and deploy applications to servers. In this tutorial, we'll guide you through the installation and basic usage of Ansible.

## What is Ansible?

Ansible is an open-source platform used for server management, configuration, application deployment, and task automation across servers and cloud infrastructures.

## Why Use Ansible?

Ansible simplifies server management and configuration. It uses tools like playbooks, ad-hoc commands, and inventory files to make infrastructure management more efficient and automated.

## Installation

First, ensure you have Ansible installed on your machine. Follow these instructions based on your operating system:

### Linux

```bash
sudo apt install ansible
```

### MacOS

First, install Homebrew (a package manager) if you haven't already:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install Ansible:

```bash
brew install ansible
```

## Managing Your First Servers

### SSH Setup

1. Create SSH keys for authentication:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/personal_key -C "your_email@domain.com"
   ```

   This command creates a key that will be used for automatic authentication when logging into your servers.

2. Create a new SSH key specifically for Ansible automation tasks:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -C "ansible@$(hostname)"
   ```

3. Copy the SSH keys to your servers:

   ```bash
   ssh-copy-id -i ~/.ssh/ansible_key.pub lc@188.0.0.1
   ```

   ```bash
   ssh-copy-id -i ~/.ssh/personal.pub  lc@188.0.0.1
   ```

   These commands copy your authentication and Ansible SSH keys to the server, simplifying configuration and management.

### Using Playbooks

After setting up your SSH keys, you can use Ansible playbooks to execute tasks on your servers. A playbook is a YAML file that contains a list of tasks to be executed on the managed servers.

Here is an example of a playbook that installs and starts the Apache web server:

```yaml
- name: Install and start Apache web server
  hosts: webservers
  become: true # Use sudo
  tasks:
    - name: Install Apache
      apt:
        name: apache2
        state: present
      when: ansible_os_family == "Debian"

    - name: Install Apache on RHEL/CentOS
      yum:
        name: httpd
        state: present
      when: ansible_os_family == "RedHat"

    - name: Ensure Apache is started and enabled
      service:
        name: "{{ 'apache2' if ansible_os_family == 'Debian' else 'httpd' }}"
        state: started
        enabled: true
```

In this playbook, the `hosts` field specifies the group of servers (from the inventory file) on which the tasks will be executed. The `become` field allows the specified user to execute tasks with elevated privileges. The `tasks` field lists the actions to be performed on the servers, such as installing packages and starting services.

### Inventory File

The inventory file defines the servers managed by Ansible and organizes them into groups based on their roles or purposes. Here is an example:

```ini
[web]
192.168.1.10 ansible_user=ubuntu
192.168.1.11 ansible_user=ubuntu

[db]
192.168.1.12 ansible_user=root
```

In this example, the servers are grouped into `web` and `db` groups, indicating their respective roles as web servers and database servers.

### Using Ad-hoc Commands

Ad-hoc commands are used to run single, simple tasks on your servers without the need to write a playbook. Here are some examples:

- **Ping All Servers**

  ```bash
  ansible all -i hosts.ini -m ping
  ```

- **Reboot Web Servers**

  ```bash
  ansible web -i hosts.ini -a "reboot" -b
  ```

- **Install VLC on Web Servers**

  ```bash
  ansible web -i hosts.ini -b -m apt -a "name=vlc state=present"
  ```

Ad-hoc commands are useful for performing quick tasks, such as installing a package or rebooting a server.

## Conclusion

In this tutorial, we covered the basics of Ansible, including its installation, configuration, and usage of playbooks and ad-hoc commands. Ansible is a powerful tool that can greatly simplify the management and automation of tasks across your servers and infrastructure.
