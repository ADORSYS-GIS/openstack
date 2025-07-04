# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Use Ubuntu 22.04 LTS as the default base box for local testing
  config.vm.box = "generic/ubuntu2204"

  # Shared synced folder (local host <-> guest VM)
  config.vm.synced_folder ".", "/vagrant"

  if ENV["CI"]
    # CI-specific: Use Docker provider for GitHub Actions
    config.vm.provider "docker" do |docker|
      docker.image = "ubuntu:22.04"
      docker.has_ssh = true
      docker.remains_running = true
    end

    config.vm.hostname = "ci-keystone"
    config.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbooks/keystone_manual/keystone-ansible-role/playbook.yml"
      ansible.become = true
      ansible.extra_vars = {
        ansible_python_interpreter: "/usr/bin/python3"
      }
    end

  else
    # Local development: Use libvirt
    config.vm.provider "libvirt" do |libvirt|
      libvirt.memory = 4096
      libvirt.cpus = 2
    end

    config.vm.network "private_network", type: "dhcp"

    config.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "/vagrant/playbooks/keystone_manual/keystone-ansible-role/playbook.yml"
      ansible.become = true
      ansible.extra_vars = {
        ansible_python_interpreter: "/usr/bin/python3"
      }
    end
  end
end
