# OpenStack Nova Ansible Automation

This project provides an **idempotent, role-based Ansible automation framework** for deploying and validating the OpenStack Nova (Compute) service across controller and compute nodes. It is designed for reproducible, production-grade deployments on Ubuntu-based systems.

---

## Features

- Validates Keystone and Glance availability before proceeding
- Installs and configures all core Nova components:
  - `nova-api`, `nova-conductor`, `nova-scheduler`, `nova-compute`
- Initializes and maps Nova cells (`cell0`, `cell1`)
- Configures hypervisor support using KVM and libvirt
- Provisions standard flavors (e.g. `m1.small`, `m1.large`)
- (Optional) Sets project quotas
- Deploys a test VM to validate end-to-end Nova functionality
- Modular and inventory-scoped using best practices

---

## Directory Structure

```

openstack-nova-ansible/
├── inventories/
│   └── production/
│       ├── hosts.yml
│       └── group\_vars/
│           ├── controller.yml
│           └── compute.yml
├── playbooks/
│   ├── site.yml
│   ├── controller.yml
│   └── compute.yml
├── roles/
│   ├── check\_dependencies/
│   ├── nova\_controller/
│   ├── cell\_discovery/
│   ├── flavors/
│   ├── quotas/
│   ├── nova\_compute/
│   ├── kvm\_config/
│   └── test\_vm\_launch/
├── requirements.yml
└── README.md

````

---

## Usage

### 1. Prerequisites

- Target hosts should be Ubuntu 20.04+ with root SSH access
- OpenStack packages should already be installed (or provisioned via roles)
- A working Keystone + Glance setup
- The file `/root/admin-openrc.sh` must exist on the controller with valid OpenStack credentials

### 2. Install Ansible Collections

Collections are declared in `requirements.yml`:

```yaml
# requirements.yml
collections:
  - name: openstack.cloud
  - name: community.general
````

Install them using:

```bash
ansible-galaxy collection install -r requirements.yml
```

### 3. Source Keystone Credentials

```bash
source /root/admin-openrc.sh
```

### 4. Run the Full Deployment

```bash
ansible-playbook -i inventories/production/ playbooks/site.yml
```

### 5. Run by Component (Optional)

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

---

## Requirements

* Ansible ≥ 2.9 (2.12+ recommended)
* Required collections (installed via `requirements.yml`):

  * `openstack.cloud`
  * `community.general`
* Functional DNS or `/etc/hosts` entries so compute nodes can resolve `controller`
* SSH key-based access to all nodes
* MySQL backend and RabbitMQ running if needed by Nova
