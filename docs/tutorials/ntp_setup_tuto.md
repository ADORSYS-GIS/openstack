
## NTP Setup Tutorial

As discussed in the [NTP documentation](/docs/ntp_docs.md), NTP (Network Time Protocol) is used to synchronize time across all servers in an infrastructure. In this tutorial, we’ll learn how to install and configure NTP using an Ansible playbook.

Ansible automates tasks through *playbooks*, which define the desired state of systems. We’ll write a playbook to install NTP on all servers.

---
## Prerequisites

Before proceeding, make sure you understand how playbooks work by reviewing this guide:

- [Ansible Playbook Basics](/docs/tutorials/ansible_tuto.md)

---
## playbook initialisation 

To begin writing a playbook, you generally follow a common structure made up of the following main keys:
 ```
   name
   hosts
   become
   tasks
```

- For our NTP setup, we can give the playbook a descriptive name like "Installing NTP via Ansible".

- The hosts field specifies the group of servers where the tasks should run. In our case, we'll set it to all, meaning we want the NTP service installed on all target servers.

- The become field allows tasks to be executed with sudo privileges. Since installing a service like NTP requires elevated permissions, we’ll set this to yes.

- The tasks section defines the actual steps Ansible should perform. Each task can have sub-sections such as a package manager. For our case, we’ll use apt to install the package named ntp.

- Additionally, we use update_cache: yes to ensure that the package list is up to date before installation, so the latest version of ntp is installed.

So our playbook will look like:

```
  - name: Installing Ntp service
    hosts: all
    become: yes
    tasks:
      - apt: NTP
        update cache: yes

```
---
Then finally you will run this command 

   ```
   ansible-playbook -i inventory.ini playbook.yml
```

The inventory.ini file is the place where all your servers identity ae place .
 follow this to learn more about inventory.ini 

 => [ansible inventory_docs](/docs/tutorials/ansible_tuto.md)

## Conclusion

That's it! You've now learned how to install NTP using an Ansible playbook to synchronize time across your servers. This is an essential step in managing distributed systems to ensure consistent timekeeping and prevent potential issues.