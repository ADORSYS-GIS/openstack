# OpenStack Nova Ansible Automation

This project provides an **idempotent, role-based Ansible automation framework** for deploying and validating the OpenStack Nova (Compute) service across controller and compute nodes. It is designed for reproducible, production-grade deployments on Ubuntu-based systems.

---

## Features

* Validates Keystone and Glance availability before proceeding
* Installs and configures all core Nova components:

  * `nova-api`, `nova-conductor`, `nova-scheduler`, `nova-compute`
* Initializes and maps Nova cells (`cell0`, `cell1`)
* Configures hypervisor support using KVM and libvirt
* Provisions standard flavors (e.g. `m1.small`, `m1.large`)
* (Optional) Sets project quotas
* Deploys a test VM to validate end-to-end Nova functionality
* Modular and inventory-scoped using best practices

---

## Directory Structure

```
nova/
├── ansible.cfg
├── inventories/
│   └── production/
│       ├── hosts.yml
│       └── groups_vars/
│           └── all.yml
├── playbooks/
│   └── site.yml
├── requirements.yml
├── README.md
└── roles/
    ├── cell_discovery/
    ├── check_dependencies/
    ├── flavors/
    ├── kvm_config/
    ├── nova_compute/
    ├── nova_controller/
    └── test_vm_launch/
```

---

## Usage

### 1. Prerequisites

* Target hosts should be Ubuntu 20.04+ with root SSH access
* OpenStack packages should already be installed (or provisioned via roles)
* A working Keystone + Glance setup
* The file `/root/admin-openrc.sh` must exist on the controller with valid OpenStack credentials

### 2. Install Ansible Collections

Collections are declared in `requirements.yml`:

```yaml
# requirements.yml
collections:
  - name: openstack.cloud
  - name: community.general
```

Install them using:

```bash
ansible-galaxy collection install -r requirements.yml
```

### 3. Source Keystone Credentials

```bash
source /root/admin-openrc.sh
```

### 4. Vaulted Secrets

The following sensitive variables are defined in `inventories/production/group_vars/all.yml`:

```yaml
nova_db_password: "nova_db_pass"
nova_user_password: "nova_user_pass"
```

These values should be encrypted using [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) to prevent exposure in version control:

```bash
ansible-vault encrypt inventories/production/group_vars/all.yml
```

They are securely used throughout all relevant roles (e.g. `nova_controller`, `nova_compute`).

### 5. Run the Full Deployment

```bash
ansible-playbook -i inventories/production/ playbooks/site.yml
```

### 6. Run by Component (Optional)

* Controller node only:

  ```bash
  ansible-playbook -i inventories/production/ playbooks/controller.yml
  ```

* Compute node(s) only:

  ```bash
  ansible-playbook -i inventories/production/ playbooks/compute.yml
  ```

---

## Post-Deployment Validation

Confirm Nova is functional:

```bash
openstack compute service list
openstack flavor list
openstack server list
nova-status upgrade check
```

---

## Notes

* The `test_vm_launch` role ensures Nova is functional by booting a temporary VM and validating its state.
* All roles are idempotent and fail gracefully when misconfigured.
* Group-scoped configuration (e.g. Keystone auth, DB credentials) is in:

  * `inventories/production/group_vars/controller.yml`
  * `inventories/production/group_vars/compute.yml`
  * Common credentials are shared in `group_vars/all.yml` and should be encrypted using Ansible Vault.

---

## Requirements

* Ansible ≥ 2.9 (2.12+ recommended)
* Required collections (installed via `requirements.yml`):

  * `openstack.cloud`
  * `community.general`
* Functional DNS or `/etc/hosts` entries so compute nodes can resolve `controller`
* SSH key-based access to all nodes
* MySQL backend and RabbitMQ running if needed by Nova
