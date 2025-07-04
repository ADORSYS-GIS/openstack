# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  if ENV["CI"]
    config.vm.hostname = "ci-keystone"
    config.vm.boot_timeout = 180

    config.ssh.username = "root"
    config.ssh.password = "root"
    config.ssh.insert_key = false

    # Disable synced folders and fstab updates in Docker
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.allow_fstab_modification = false

    config.vm.provider "docker" do |docker|
      docker.image = "rastasheep/ubuntu-sshd:18.04"
      docker.has_ssh = true
      docker.remains_running = true
      docker.ports = ["2222:22"]
    end

    config.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbooks/keystone_manual/keystone-ansible-role/playbook.yml"
      ansible.become = true
      ansible.extra_vars = {
        ansible_python_interpreter: "/usr/bin/python3"
      }
    end
  else
    # Local Libvirt development configuration
    config.vm.box = "generic/ubuntu2204"
    config.vm.hostname = "dev-keystone"

    config.vm.synced_folder ".", "/vagrant"

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
