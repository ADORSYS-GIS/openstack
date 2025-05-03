# Ansible

Ansible is an open-source automation tool used for automating applications, service orchestration, and the configuration and management of servers.

## Prerequisites

Before getting started with Ansible, make sure it's installed on your machine. You can follow the installation instructions for your specific OS using the link below:

- #### [Install Ansible](https://spacelift.io/blog/how-to-install-ansible)

## Features

Ansible provides several tools to facilitate server management:

 - #### OpenSSH:
  Used for setting up SSH and generating keys for authenticating with servers.

  - ###  Ad-hoc Commands: 
  These are used as alternatives to playbooks, typically for quick and simple tasks.

- ### Playbooks:
 These are YAML files containing specific tasks to manage servers, commonly used for more complex tasks.

 - ###   Inventory File:
  Contains the list of servers grouped by categories, allowing for organized management of your infrastructure.

## How It Works

### SSH Configuration

Ansible relies on SSH to authenticate and configure servers. While you can use a single SSH key for managing all servers, it is often recommended to use two separate keys for different tasks: one for personal SSH logins and another specifically for automation with Ansible.

#### Creation of SSH Keys

To create SSH keys for both personal use and automation, follow these steps:

 - ##### Personal Key (for interactive SSH/logins):
```
ssh-keygen -t ed25519 -f ~/.ssh/personal_key -C "your_email@domain.com"
```
Ansible Key (for automation tasks):

    ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -C "ansible@$(hostname)"

These commands generate two SSH keys: one for personal use and one for Ansible automation. After creating the keys, copy them to the servers using the following command:

``` 
  ssh-copy-id -i ~/.ssh/ansible_key.pub lc@188.0.0.1

```
AND 
```
    ssh-copy-id -i ~/.ssh/personal.pub  lc@188.0.0.1
  ```

Replace 188.0.0.1 with the IP address or hostname of your target server.

### Launching a Playbook

Playbooks define the automation logic in a structured way. When you run a playbook, Ansible loads temporary modules to the remote server to execute the tasks (e.g., install packages, start services). After execution, these modules are removed.


an example of a playbook structure is: 

```
 ---
- name: Install and configure Nginx
  hosts: webservers
  become: true  # Enable sudo
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install Nginx
      apt:
        name: nginx
        state: present

    - name: Start Nginx service
      service:
        name: nginx
        state: started
        enabled: yes
```
For more details on playbooks:

[Ansible playbbook guide](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html)

### Ad-hoc commands 

Ad-hoc commands are ideal for executing quick operations without creating a playbook. Examples include reboots, file transfers, and directory management.


Examples:

- #### Reboot servers in groups of 12:

```
ansible abc -a "/sbin/reboot" -f 12 -u username
```
- #### Copy a file to target servers:

```
ansible abc -m copy -a "src=/etc/yum.conf dest=/tmp/yum.conf"
```

- #### Create a directory with specific permissions:

```
ansible abc -m file -a "dest=/path/user1/new mode=0777 owner=user1 group=user1 state=directory"
```

- #### Delete a directory:

```  
ansible abc -m file -a "dest=/path/user1/new state=absent"
```

The abc here refers a group of servers in your inventory file.


To learn more about  ad-hoc commands:

- [Ad-hoc](https://docs.ansible.com/ansible/2.8/user_guide/intro_adhoc.html)

