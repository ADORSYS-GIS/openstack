# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Use Ubuntu 22.04 LTS as the base box (recommended for OpenStack)
  config.vm.box = "generic/ubuntu2204"

  # VM resources (adjust as needed for Keystone)v 
  config.vm.provider "libvirt" do |libvirt|
    libvirt.memory = 4096
    libvirt.cpus = 2
  end

  # Network: private network for easier SSH and API access
  config.vm.network "private_network", type: "dhcp"

  # Sync your project directory to /vagrant inside the VM
  config.vm.synced_folder ".", "/vagrant"

  # Provision with Ansible (local)
  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "/vagrant/playbooks/keystone_manual/keystone-ansible-role/playbook.yml"
    ansible.become = true
    ansible.extra_vars = {
      ansible_python_interpreter: "/usr/bin/python3"
    }
  end
end
