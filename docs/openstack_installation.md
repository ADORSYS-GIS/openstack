# Openstack instllation

This documentation will guide inorder to install openstack using devstack  through an ansible-playbook.

## Prerequisites

Before diving into the main instllation make sure you are having [ansible](/docs/tutorials/ansible_tuto.md) installed.

## The installation process

To install openstack using devstack through an ansible-script modules have to be genrated depending on the task that is carry out,
that is :

- In the devstack mode , there are commads like

```
 sudo apt install git 
```
When using ansible to run such commad , modules are used so as to   install the package listed in the command (git)

```
  - name : install git package 
      apt:
        name: git 
        update_cache : yes 
```
So here the module apt is used so as to install the git package ..

Then for the rest playbook the same thing is done each step is converted to a module depending on the package it is.

```
  ---
- name: Prepare system for DevStack
  hosts: localhost
  become: yes
  gather_facts: yes

  tasks:
    - name: Update apt cache (Debian/Ub
    untu)
      apt:
        update_cache: yes
      when: ansible_distribution == 'Ubuntu' or ansible_distribution == 'Debian'

    - name: Upgrade all packages (Debian/Ubuntu)
      apt:
        upgrade: dist
        update_cache: yes
      when: ansible_distribution == 'Ubuntu' or ansible_distribution == 'Debian'

    - name: Create the 'stack' user
      user:
        name: stack
        shell: /bin/bash
        create_home: yes

    - name: Allow passwordless sudo for 'stack'
      copy:
        dest: /etc/sudoers.d/stack
        content: "stack ALL=(ALL) NOPASSWD: ALL\n"
        mode: '0440'

    - name: Ensure Git is installed (Debian/Ubuntu)
      apt:
        name: git
        state: present
      when: ansible_distribution == 'Ubuntu' or ansible_distribution == 'Debian'

    - name: Fix ownership of /home/stack
      file:
        path: /home/stack
        state: directory
        owner: stack
        group: stack
        recurse: yes

    - name: Create temp dir for Ansible under stack user
      file:
        path: /home/stack/.ansible/tmp
        state: directory
        owner: stack
        group: stack
        mode: '0700'

- name: Install DevStack as 'stack' user
  hosts: localhost
  become: yes
  become_user: stack
  gather_facts: no  # Already gathered earlier
  environment:
    ANSIBLE_LOCAL_TEMP: /home/stack/.ansible/tmp
    ANSIBLE_REMOTE_TEMP: /home/stack/.ansible/tmp

  tasks:
    - name: Check current user
      command: whoami
      register: whoami_result

    - debug:
        var: whoami_result.stdout

    - name: Clone DevStack repo
      git:
        repo: https://opendev.org/openstack/devstack
        dest: /home/stack/devstack

    - name: Copy sample local.conf
      copy:
        src: /home/stack/devstack/samples/local.conf
        dest: /home/stack/devstack/local.conf
        remote_src: yes

    - name: Run DevStack install script
      command: ./stack.sh
      args:
        chdir: /home/stack/devstac
```

The installation process include 
 
 - 