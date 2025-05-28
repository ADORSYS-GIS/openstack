 Welcome to this beginner's guide to Ansible, a powerful automation tool that helps you manage, configure, and deploy applications to servers. In this tutorial, we’ll guide you through the installation and basic usage of Ansible, so you can start automating tasks across your infrastructure.

### what is ansible ??

Ansible is an open source platform that is used for management, configuration , application deployment and task automation of servers and cloud infrastructures.

### Why is it used ??

Ansible is use so as to easy the management of servers and their configuration .It is uses certain tools like  playbooks , ad-hoc commands and inventory file so to easy and makes the work more efficient.

So now we will dive into managing our server using ansible.

### Installation 

First make sure you are having ansible install in you machine , Follow this to install it depending on the os you are on 

-  linux 
```
sudo apt install ansible
```

- MacOs 

If you are macOs you will first need to install homebrew which is a package manager that will facilitate the installation of ansible 

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

  Then type the command to install ansible 
  
```
brew install ansible
```

   ### Managing Our FirstGroup of  Servers

#### SSH Setup 

-  First you will need to create Ssh keys for authentification and for ansible 
   So you will run this command 

   
```
ssh-keygen -t ed25519 -f ~/.ssh/personal_key -C "your_email@domain.com"
```

 -   This command will create a key that will be use for authentification so as to login into all the servers automatically.
   
 Then 

 
```
ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -C "ansible@$(hostname)"
```


- This will create a new ssh key specifically for ansible automation tasks.

- After creating the different keys for ansible and for authentification , you will need to copy them to all the other servers .So to achieve it you will use this command

```
ssh-copy-id -i ~/.ssh/ansible_key.pub lc@188.0.0.1
```


AND 

```
ssh-copy-id -i ~/.ssh/personal.pub  lc@188.0.0.1
```


 So this command will copy both of your keys to the servers so as to easy the configurations and the management of the servers 

#### USING PLAYBOOKS 

After setting up your ssh keys and copy them to all the different servers , you will need now a way to execute the different task on the servers and to do so you will use an ansible tool known as Playbook .

A PLaybook is a yaml file that contains all the tasks that are to run on server ..This means taht if i need to install vlc or any other apps on a group of server instead of going to each server and configuring them , i will descibe the task and give the action that should run  inorder to insatll the given app .

So a global example of a playbook is 

```
- name: Install and start Apache web server
  hosts: webservers
  become: true  # Use sudo
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
So here as you can see the action we want to perform on the webservers is to update apt cache .So This will now use modules .

Modules are small programs used to execute specific tasks on a playbook . That is when a playbook is launched the modules are loaded into the servers to execute the specific task described in the playbook .

As you can see a playbook is having a define syntax that is 

name: Install and start apache web server
hosts: webservers
become: true  # Use sudo
tasks:


Here as you can see the name can be optional ..not always obligated gives a name to the playbook we are about to run. The next field are important and mostly obligated.

The hosts indicate under which group of server found in the inventory file should the operation execute , become gives the user running it a high access . Then  tasks is used to define which operation we want to execute in the webservers ,given the name and the package manager that will be used to run the task .

Now we will look at the inventory file 

#### Inventory file 

This is a file that defines all the servers and place them in groups depending on what the server is used for .That is 

[web]
192.168.1.10 ansible_user=ubuntu
192.168.1.11 ansible_user=ubuntu

[db]
192.168.1.12 ansible_user=root


So here you can find different ip in different group. The groups define what the server is used for.This means that the 1st Servers are use for web purpose while the other one is used for database.

#### Using Ad-hoc Commands

Ad-hoc commands are quick commands to run single tasks without a playbook.So this help you to carry some short task that are not too complex without writing a whole playbook.Some examples are 

##### Example: Ping All Servers
```
ansible all -i hosts.ini -m ping
```

##### Example: Reboot Web Servers

```
ansible web -i hosts.ini -a "reboot" -b
```

##### Example: Install VLC on Web Servers

```
ansible web -i hosts.ini -b -m apt -a "name=vlc state=present"
```

So there are many other things that ansible can do like creating directories, files or deleting them in servers.

We are at the end of our tutorial on ansible  hope that this have help you to manage your first servers using ansible .