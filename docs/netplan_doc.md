# NETWORK CONFIGURATION USING NETPLAN WITH ANSIBLE

## WHAT IS NETPLAN 

Netplan is a modern network configuration tool, primarily used in Ubuntu-based Linux distributions. Its goal is to simplify the management of network interfaces through the use of YAML files. Before its introduction, network configuration in Linux was done through files like /etc/network/interfaces or other methods specific to the services used, like NetworkManager or systemd-networkd. With Netplan, these configurations are unified, providing a standard and accessible solution.

This guide is designed to show you how to use Netplan with ansible to efficiently configure your network interfaces, whether you need to manage Ethernet connections, Wi-Fi, or even advanced configurations like VLANs and static routes, alongside with ansible to automate all this tedious processes.

## WHY NETPLAN

Netplan was first introduced to the Ubuntu universe in version 17.10 (Artful Aardvark). Prior to this release, Linux server and system administrators often used traditional file and ifup/down/etc/network/interfaces tools to manage their network interfaces. These methods, while widely used, were becoming increasingly limited in modern, complex network environments.

With the emergence of new needs, particularly around dynamic network management, 
the need for a tool that unifies the different network services has become 
apparent. Netplan is designed to fill this gap. It acts as an overlay simplifying 
the management of systemd-networkd (systemd is the network manager) and 
NetworkManager. This allows administrators to use a single, simplified syntax, 
regardless of the underlying service.

Netplan is the choice for Ubuntu distributions that enabled a smoother transition 
to cloud infrastructures and virtualized environments, where tools like cloud-init 
benefit from automated and more flexible network configuration.

**What are NetworkManager and systemd-networkd?**

As mentioned above, Netplan acts as a unified configuration interface for two main network managers: NetworkManager and systemd-networkd. Both services play a key role in managing network interfaces on Ubuntu distributions and its derivatives, but they are not used in the same contexts.

**Network Manager**

NetworkManager is the network manager primarily used on desktop systems like Ubuntu Desktop or its graphical derivatives such as Kubuntu and Lubuntu. It is designed to simplify network connection management, especially in environments where interfaces change frequently, such as with Wi-Fi connections, VPNs, or mobile networks.

On a system using NetworkManager, you often have access to a graphical interface, such as the one built into the GNOME desktop environment, to manage networks. This makes NetworkManager ideal for workstations where flexibility and user interaction are essential.

**systemd-networkd**

systemd-networkd, on the other hand, is more often used on server systems, such as Ubuntu Server, where network interface management is more static and does not require frequent user interaction. This service is minimalistic and seamlessly integrated into the systemd system, making it suitable for servers and headless environments.

**checking your manager**

It is important to know which network manager is active, as it determines how 
**Netplan** will apply your network configuration.

To check if NetworkManager is installed and active, you can run the following 
command:

```sh
sudo systemctl status NetworkManager
```
If the service is active, you will see a return indicating status as "running". 
Otherwise, the service will be inactive or uninstalled.

To check if systemd-networkd is active, use the following command:

```sh
sudo systemctl status systemd-networkd
```

Similarly, if this service is active, it indicates that systemd-networkd is 
managing the network.

**Netplan File Structure and Permissions**

The configuration files used by Netplan are in YAML format, a simple and readable 
format that makes it easy to configure network interfaces. These files are 
located in the directory /etc/netplan/ and it is from there that network 
configurations are applied.

Each Netplan file follows a strict YAML syntax with well-defined indentations. 
Here is a simple example of a configuration where the Ethernet interface uses 
DHCP to obtain an IP address automatically:

```sh
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
```

Explanation:

- network: Main block that contains all network configurations.
- version: The version of the Netplan configuration file (currently it is version 2).
- renderer: Defines which service manages network configuration. Here, networkd 
  means that systemd-networkd is used. For a desktop environment, one can use 
  NetworkManager.
- ethernets: This block contains the Ethernet interfaces. In this example, eth0 
  is the interface being configured.
- dhcp4: Enables DHCP for IPv4, which assigns an IP address automatically.


## Typical configurations with Netplan

Netplan is a flexible tool that allows you to configure different types of networks: IPv4 and IPv6 addresses , DHCP or static configurations , as well as more complex scenarios like network bridges , link aggregation (bonding), and Wi-Fi connections . Here is a set of typical configurations that cover these different cases.

**IPv4 configuration with DHCP**

To configure a network interface with an IPv4 address obtained via DHCP , here is a simple configuration. This is commonly used for workstations or servers in environments where the IP address is automatically provided by a DHCP server :
```sh
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
```

In this example, the eth0 interface automatically obtains an IPv4 address via DHCP.

**Configuring a fixed IPv4 address**

If you need a static IPv4 address for your interface, for example for a server, here's how to configure that:

```sh
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

- addresses: Sets the static IP address with the subnet mask (/24).
- gateway4: specifies the default gateway.
- nameservers: defines the DNS servers (here, those of Google).

**IPv6 Configuration with DHCP**

To configure an interface to obtain an IPv6 address via DHCP , the syntax is similar to that for IPv4 . Here's how to configure DHCP for IPv6 on Netplan :

```sh
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp6: true
```

This configuration allows the eth0 interface to obtain a dynamic IPv6 address via DHCPv6 .

**Configuring a Static IPv6 Address**

To set a static IPv6 address , here is an example configuration:

```sh
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 2001:0db8:85a3::8a2e:0370:7334/64
      gateway6: 2001:0db8:85a3::1
      nameservers:
        addresses:
          - 2001:4860:4860::8888
          - 2001:4860:4860::8844
```

- addresses: specifies the static IPv6 address and its prefix ( /64).
- gateway6: Sets the default gateway for IPv6 .
- nameservers: Sets the DNS servers for IPv6 .

**Wi-Fi configuration**

Setting up a Wi-Fi network with Netplan requires specifying the SSID and security key. Here's an example of how to configure a Wi-Fi interface :

```sh
network:
  version: 2
  renderer: NetworkManager
  wifis:
    wlan0:
      access-points:
        "MonSSID":
          password: "motdepassewifi"
      dhcp4: true
```

In this example:

- wlan0 is the Wi-Fi interface .
- access-pointsspecifies the Wi-Fi network name ( MonSSID) and its password.
- dhcp4: true indicates that the Wi-Fi interface 

**Checking network connectivity**

If you have followed the [ubuntu server installation]() documentation, then no need of configuring the network interface for wi-fi or ethernet manually, because it was surely configured during the installation of ubuntu server. You may use the following command to ensure that network connection is well configured:

```sh
cat /etc/netplan/50-cloud-init.yaml
```

Also, you can use the followimg commands to check whether you are connected to internet:

```sh
ping -c 5 8.8.8.8
```
OR

```sh
ping -c 5 google.com
```

If you see zero packet loss, all the 5 packet were transmitted and 5 packet received, then it means that the DNS(doman name system) is able to resolve domain-name to ip address thus you are connected to the internet.

**Configuring network interfaces manually**

If you want to configure Wi-Fi, static IPv4, static IPv6, IPv4 with DHCP, or 
IPv6 with DHCP manually, do the following:

1. You need to:

```sh
sudo nano /etc/netplan/50-cloud-init.yaml
```
Then replace the configuration with any of the configurations above, depending 
on your choice.

2. To apply the changes, run the following command:
```sh
netplan generate
netplan apply
```

**Configuring network interfaces manually using Ansible script along with 
playbook**

To configure any of these network interfaces manually using Ansible script, do 
the following:

1. We need to install Ansible on our machine to be able to run Ansible scripts. 
   Run the following command to install Ansible:

```sh
sudo apt update && sudo apt upgrade -y
sudo apt install python3 
sudo python3 venv my_venv | sudo source my_venv/bin/activate | cd my_venv
sudo apt install -y build-essential libssl-dev libffi-dev python3-dev python3-pip
python3 install ansible --user
```

2. Create a playbook.yml file, copy and paste the following:

```sh
---
- name: Configure Ethernet with static IP using Netplan
  hosts: localhost
  become: yes

  vars:
    interface_name: "ens33"
    static_ip: "10.42.0.10/24"
    gateway4: "10.42.0.1"
    nameservers:   
      - "8.8.8.8"
      - "8.8.4.4"

  tasks:
    - name: Create Netplan configuration for Ethernet
      copy:
        dest: /etc/netplan/50-cloud-init.yaml
        content: |
          network:
            version: 2
            ethernets:
              {{ interface_name }}:
                dhcp4: no
                addresses:
                  - {{ static_ip }}
                gateway4: {{ gateway4 }}
                nameservers:
                  addresses: {{ nameservers }}
      notify: Apply Netplan

  handlers:
    - name: Apply Netplan
      command: netplan apply

    - name: Check interface IP using ip a
      command: ip -4 addr show {{ interface_name }}
      register: ip_result

    - name: Display interface IP info
      debug:
        var: ip_result.stdout_lines
```

3. To execute the Ansible code, run this command:

```sh
sudo ansible-playbook -i host playbook.yaml
```

If your output looks like this:

```
inet 192.168.1.100/24 brd 192.168.1.255 scope global ens33
```

Then this indicates that your network interface "ens33" has been configured.

Alternatively, if you want to configure a wireless network interface with a 
static IP address (i.e., a network interface that uses Wi-Fi), replace the 
content in the /etc/netplan/50-cloud-init.yaml file with the following Ansible 
script:

```sh
---
- name: Configure Wi-Fi with static IP using Netplan
  hosts: localhost
  become: yes

  vars:
    wifi_name: "your_wifi_ssid"
    static_ip: "192.168.1.100/24"
    interface_name: "wlan0"

  tasks:
    - name: Create Netplan configuration for Wi-Fi
      copy:
        dest: /etc/netplan/50-cloud-init.yaml
        content: |
          network:
            version: 2
            wifis:
              {{ interface_name }}:
                dhcp4: no
                addresses:
                  - {{ static_ip }}
                gateway4: 192.168.1.1
                nameservers:
                  addresses:
                    - 8.8.8.8
                    - 8.8.4.4
                access-points:
                  "{{ wifi_name }}":
                    password: "your_wifi_password"
      notify: Apply Netplan

    - name: Check interface IP using ip a
      command: ip -4 addr show {{ interface_name }}
      register: ip_result

    - name: Display interface IP info
      debug:
        var: ip_result.stdout_lines

  handlers:
    - name: Apply Netplan
      command: netplan apply
```

If your output looks like this:

```
inet 192.168.1.100/24 brd 192.168.1.255 scope global wlan0
```

Then this indicates that your network interface "wlan0" has been configured.
