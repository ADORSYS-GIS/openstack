# OpenStack Glance Deployment Using Ansible  
### Comprehensive Documentation and Architecture Explanation

---

## Table of Contents

- [Introduction](#introduction)  
- [OpenStack Architecture Context](#openstack-architecture-context)  
- [Project Overview](#project-overview)  
- [Pre-requisites and Environment](#pre-requisites-and-environment)  
- [Project Structure](#project-structure)  
- [Detailed Configuration Variables](#detailed-configuration-variables)  
- [Role Breakdown and Workflow](#role-breakdown-and-workflow)  
  - [Keystone Role (Identity Service)](#keystone-role-identity-service)  
  - [Glance Role (Image Service)](#glance-role-image-service)  
- [How the Ansible Playbook Operates](#how-the-ansible-playbook-operates)  
- [Key Components and Concepts](#key-components-and-concepts)  
- [Security Considerations](#security-considerations)  
- [Post-Installation Verification](#post-installation-verification)  
- [Extending and Customizing](#extending-and-customizing)  
- [Troubleshooting Guide](#troubleshooting-guide)  
- [References](#references)  

---

## Introduction

This document details the automated installation and configuration of OpenStack's **Keystone** (identity service) and **Glance** (image service) components using Ansible. It provides a modular, idempotent, and reusable approach that simplifies deploying these critical cloud infrastructure services, ensuring they are correctly configured, secured, and integrated.

---

## OpenStack Architecture Context

OpenStack is composed of loosely coupled services that provide infrastructure-as-a-service (IaaS). Two essential components covered here are:

- **Keystone:** The central authentication and authorization system. Every other OpenStack service depends on Keystone for identity management.
- **Glance:** The image service managing VM disk images used to provision instances.

Glance requires Keystone to authenticate users and services securely. Therefore, Keystone must be installed and operational before deploying Glance.

---

## Project Overview

This Ansible project aims to:

- **Automate installation** of Keystone and Glance along with their dependencies.  
- **Configure database access** via MariaDB with securely managed credentials.  
- **Set up Keystone** with secure tokens and proper Apache WSGI integration.  
- **Configure Glance** to authenticate with Keystone and store images on local filesystem.  
- **Register services and endpoints** in Keystone to enable integration across OpenStack components.  
- **Deploy a minimal test image** to validate the Glance installation.  

---

## Pre-requisites and Environment

- A fresh or clean **Ubuntu/Debian** system with root/sudo access.  
- Ansible (version 2.9 or higher recommended) installed locally.  
- Network connectivity to fetch packages and cloud images.  
- Sufficient permissions to install packages, manage services, and configure Apache.

---

## Project Structure

The project follows best practices for Ansible roles, structured as:

glance-ansible/
├── inventory.ini                # Defines target hosts (default: localhost)
├── glance.yml                  # Main playbook orchestrating Keystone & Glance roles
└── roles/
    ├── keystone/               # Keystone role (identity service)
    │   ├── defaults/main.yml   # Default variables for Keystone
    │   └── tasks/main.yml      # Keystone installation & configuration steps
    └── glance/                 # Glance role (image service)
        ├── defaults/main.yml   # Default variables for Glance
        └── tasks/main.yml      # Glance installation & configuration steps


- `inventory.ini`: Defines target hosts (in this case, localhost as controller node).  
- `glance.yml`: Main playbook invoking both Keystone and Glance roles in proper sequence.  
- `roles/keystone`: Automates Keystone installation and configuration.  
- `roles/glance`: Automates Glance installation and configuration, depending on Keystone.

---

## Detailed Configuration Variables

Each role contains default variables for easy customization:

| Variable                   | Description                                                  | Default Value        |
|----------------------------|--------------------------------------------------------------|----------------------|
| `mysql_root_password`       | Root password for MariaDB/MySQL server                        | `newpassword`        |
| `keystone_db_password`      | Database password for Keystone's MySQL user                   | `keystone_db_pass`   |
| `admin_token`               | Initial Keystone admin token used internally during bootstrap | `ADMIN`              |
| `controller_host`           | Hostname/IP where OpenStack services run                      | `localhost`          |
| `keystone_port`             | HTTP port Keystone listens on                                 | `5001`               |
| `glance_db_pass`            | Database password for Glance's MySQL user                      | `GlancePass123!`     |
| `glance_user_pass`          | Password for the Glance user within Keystone                   | `GlancePass123!`     |
| `keystone_admin_pass`       | Password used to bootstrap Keystone admin user                 | `admin`              |

> **Security Tip:** Replace default passwords with strong secrets before deploying to production.

---

## Role Breakdown and Workflow

### Keystone Role (Identity Service)

**Purpose:** Set up Keystone to manage authentication for OpenStack.

- **Package Installation:** Installs MariaDB, Keystone, Apache2, WSGI modules, and configuration helpers.  
- **Database Setup:** Creates `keystone` database and user with restricted privileges.  
- **Configuration:** Updates Keystone's config file with DB connection string, token provider (`fernet`), and admin token.  
- **Database Sync:** Runs `keystone-manage db_sync` to create schema.  
- **Key Setup:** Generates encryption keys for secure token management.  
- **Bootstrap:** Initializes Keystone with admin credentials and endpoint URLs.  
- **Apache Configuration:** Configures Apache with WSGI to serve Keystone on a dedicated port (`5001`). Ensures the site is enabled and Apache restarted.

### Glance Role (Image Service)

**Purpose:** Set up Glance for image management, relying on Keystone for authentication.

- **Package Installation:** Installs Glance service, client tools, Apache2, WSGI modules, and utilities like `crudini` and `wget`.  
- **Database Setup:** Ensures MariaDB root password is set; creates `glance` DB and user.  
- **Configuration:** Configures `glance-api.conf` with DB connection and Keystone authentication details.  
- **Database Sync:** Runs `glance-manage db_sync` to prepare database schema.  
- **Service Management:** Enables and starts `glance-api` service.  
- **Service Availability:** Polls Glance API endpoint until service is ready.  
- **Keystone Integration:**  
  - Creates OpenStack user and service project if missing.  
  - Registers Glance service and API endpoints (public, internal, admin).  
- **Image Upload:** Downloads Cirros test image and uploads it into Glance for verification.

---

## How the Ansible Playbook Operates

1. **Playbook Entry Point:**  
   The playbook (`glance.yml`) runs on the controller host and applies Keystone role first, ensuring the identity service is ready.

2. **Idempotency:**  
   All tasks are written to be idempotent, meaning repeated runs will not cause errors or redundant changes.

3. **Sequential Execution:**  
   Glance role only runs after Keystone is installed and accessible, preventing race conditions and dependency failures.

4. **Variable-driven Configuration:**  
   Passwords, hostnames, ports, and other parameters are abstracted into variables for easy environment adaptation.

5. **Service Registration:**  
   OpenStack users, projects, services, and endpoints are registered via CLI commands executed with appropriate OpenStack environment variables exported dynamically.

6. **Service Availability Checks:**  
   The playbook waits and checks for the Glance API endpoint to be responsive before proceeding to image upload, ensuring system readiness.

---

## Key Components and Concepts

- **MariaDB:** Backend database storing persistent data for Keystone and Glance.
- **Fernet Tokens:** Secure symmetric encryption tokens used by Keystone for identity tokens.
- **WSGI and Apache:** Web server and gateway interface to serve Keystone and Glance APIs.
- **`crudini`:** Command-line utility to modify `.ini` configuration files reliably.
- **OpenStack CLI (`openstack`):** Used for managing Keystone users, roles, services, and images.
- **Cirros Image:** Minimal cloud image used as a functional test for the Glance service.

---

## Security Considerations

- Change default passwords before deploying in production environments.  
- Protect the Keystone and Glance API endpoints using firewall rules and HTTPS with valid certificates.  
- Secure MariaDB with restricted network access and strong authentication.  
- Manage Fernet key rotations periodically to ensure token security.  
- Limit user privileges to least required for operations.

---

## Post-Installation Verification

To verify a successful deployment:

1. **Export OpenStack Credentials:**

```bash
export OS_USERNAME=admin
export OS_PASSWORD=admin
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://localhost:5001/v3
export OS_IDENTITY_API_VERSION=3
```
2. **Check Keystone Status**

```bash
openstack token issue
````

3. **List Keystoone Image**

```sh
openstack image list
```

Look for the 'cirros' image uploaded by the playbook.

## Extending and Customizing

- Add roles for other OpenStack services like Nova (compute), Neutron (networking), Cinder (block storage).

- Change Glance backend storage from local filesystem to Swift or Ceph.

- Configure HTTPS with SSL certificates for Apache.

- Integrate with external authentication backends (LDAP, OAuth).

- Automate multi-node OpenStack deployments.

## Troubleshooting Guide

| Issue                          | Diagnostic Steps                                   | Resolution Suggestions                          |
|-------------------------------|--------------------------------------------------|------------------------------------------------|
| Keystone API not reachable     | Check Apache and Keystone logs                    | Restart services, verify configs and firewall   |
| MariaDB connection errors      | Attempt to connect manually with `mysql` CLI     | Reset root password, ensure MariaDB is running  |
| Glance API fails to start      | Inspect `/var/log/glance/` logs                    | Check config files and database connections     |
| OpenStack CLI authentication fails | Verify environment variables and Keystone credentials | Re-run Keystone bootstrap or reset passwords    |
| Image upload fails             | Validate network and storage permissions          | Check Glance logs, storage directory permissions|

## References

- [OpenStack Official Documentation](https://docs.openstack.org/)
- [Keystone Service Documentation](https://docs.openstack.org/keystone/latest/)
- [Glance Service Documentation](https://docs.openstack.org/glance/latest/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Fernet Tokens in Keystone](https://docs.openstack.org/keystone/latest/admin/fernet_tokens.html)

## Summary

This project automates a critical piece of an OpenStack cloud environment with an emphasis on security, maintainability, and extensibility. It combines robust database configuration, secure service bootstrapping, and integrated testing in an Ansible-driven workflow, making it suitable for lab environments, proof-of-concepts, or a foundation for production deployments.