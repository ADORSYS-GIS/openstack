# Installing Openstack Networking Service (Neutron)

Neutron is the networking service of OpenStack. It allows us to create networks
for our VMs, allocate floating IPs, add security groups, and many more.

It makes use of open source SDN tools to enable virtual networking support.

In this guide, we will be talking about installing OpenStack networking service
on Ubuntu.

This tutorial makes use of the official OpenStack documentation for installing
Neutron: [neutron-docs](https://docs.openstack.org/neutron/latest/install/index.html)

---

## Installing OpenStack Networking Service On Ubuntu Manually

### Pre-requisite

- Ubuntu Server installed. Version 20 and above  
  [ubuntu server](https://documentation.ubuntu.com/server/)
- Make sure you have MySQL/MariaDB and the python-client for MySQL installed for
  OpenStack. See [Installing Database for OpenStack](https://docs.openstack.org/install-guide/environment-sql-database.html)
- Two machines for controller node and compute node if you are using a multi-tier
  approach of installing OpenStack.

#### Hardware requirements

| Node            | CPU      | RAM   | Storage | NIC |
|-----------------|----------|-------|---------|-----|
| Controller Node | 1-2      | 8 GB  | 100 GB  | 2   |
| Compute Node    | 2-4+     | 8 GB+ | 100 GB+ | 2   |

- You should already have Keystone installed, which is used for authentication by
  the Neutron API.  
  [keystone installation](https://docs.openstack.org/keystone/latest/install/keystone-install-rdo.html)
- You should also have Nova installed, which is the compute service that Neutron
  serves with networking capabilities.  
  [nova installation](https://docs.openstack.org/nova/pike/install/compute-install.html)
- The different nodes should be able to talk to each other.
  - You can do this by editing the `/etc/hosts` of both nodes and resolve the IP
    of both controller and compute node.  
    Example, editing `/etc/hosts`:

    ```sh
    # controller
    CONTROLLER_IP controller
    # compute
    COMPUTE_IP compute
    # storage
    STORAGE_IP storage
    ```

    Replace `COMPUTE_IP`, `STORAGE_IP`, and `CONTROLLER_IP` with the actual IP
    addresses.

  - Edit the `/etc/network/interfaces` to add the following:

    ```sh
    auto INTERFACE_NAME

    iface INTERFACE_NAME inet manual
    up ip link set dev $IFACE up
    down ip link set dev $IFACE down
    ```

    Replace the `INTERFACE_NAME` with the actual interface name, which you can get
    using `ifconfig`, `ip link show`, or other networking tools.

- Make sure you have access to the internet on both hosts and that you can ping
  every host.

---

## Installing and Configuring the Controller Node

Note that this is the same as what you will find on the documentation and the
documentation is constantly being updated. For more info and up-to-date
installation and configuration guide, visit  
[neutron installation docs](https://docs.openstack.org/neutron/latest/install/controller-install-ubuntu.html#prerequisites)

- To begin with the installation, you need a database that will be used for
  storing user networks, subnets, ports, and even routers which other OpenStack
  services like Nova can use.
- It is good to run all these commands as a root user.

### 1. Creating the Neutron Database

```sql
mysql -u root -p

/* create neutron database */
MariaDB [(none)]> CREATE DATABASE neutron;

/* grant all privileges to neutron database and also set a strong password. */
MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' \
  IDENTIFIED BY 'NEUTRON_DBPASS';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' \
  IDENTIFIED BY 'NEUTRON_DBPASS';
```

### 2. Source Admin Credentials

```sh
. admin-openrc
# This file contains all the default setup for admin including admin password,
# project, domain, etc.
```

### 3. Now Create Service Credentials

This step uses Keystone.

```sh
# create a neutron user
openstack user create --domain default --password-prompt neutron

# add admin role to the neutron user
openstack role add --project service --user neutron admin

# create neutron service entity
openstack service create --name neutron \
  --description "OpenStack Networking Service. Installed By YOUR_NAME on \
  DATE_OF_INSTALLATION" network
```

### 4. Create Networking API Endpoints

```sh
# create networking service API endpoints
openstack endpoint create --region RegionOne \
  network public http://controller:9696

openstack endpoint create --region RegionOne \
  network internal http://controller:9696

openstack endpoint create --region RegionOne \
  network admin http://controller:9696
```

---

## At This Point Now You Can Choose Between Two Network Service Options

### 1. Provider Networks

- This option helps us to connect directly with the underlying physical network
  infrastructure (PNI) and connects VMs directly on the external network in our
  data center or the internet.
- With this, an external network can communicate directly with our VM using its IP.
- It uses only technologies like VLAN.

### 2. Self-Service Network

- This option helps us to create virtual networks for our VMs and also allows for
  VMs to communicate with each other even in different subnets or networks using
  routers.
- It uses NAT for connecting our VMs to the internet by translating their IP into
  an IP that has internet access.
- It interacts with options for address translation and internet connectivity.

Given the advantages that option two might have, in this tutorial we will
configure our Neutron to use option two.

---

## Now Let's Install the Components

### a. Installation

```sh
# installing SDN tools
apt install neutron-server neutron-plugin-ml2 \
  neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent \
  neutron-metadata-agent
```

### b. Configuring the Components

The best option here will be referencing the documentation:  
[self service network](https://docs.openstack.org/neutron/latest/install/controller-install-option2-ubuntu.html)

---

## Installing and Configuring Neutron on the Compute Node

### Install the Components

```sh
apt install neutron-openvswitch-agent
```

For the configuration, refer to the documentation since it will be the same if
we needed to type it ourselves:  
[configure neutron on the compute node](https://docs.openstack.org/neutron/latest/install/compute-install-ubuntu.html)

Also, for further configuration of OVN and other networking agents and plugins,
visit the following links:

- [Install & Configure OVN](https://docs.openstack.org/neutron/latest/install/ovn/manual_install.html)
- [Networking guide](https://docs.openstack.org/neutron/latest/admin/index.html)

---

### Now You Need to Test the Success of the Installation and Configuration

```sh
# You should see all the network agents or SDNs you have installed and configured
openstack network agent list

# You should see anything or have any error message
openstack network list

# Let's create a network
openstack network create NETWORK_NAME

# Let's add a subnet
openstack subnet create --network <network-name> \
  --subnet-range <CIDR> <subnet-name>
```
