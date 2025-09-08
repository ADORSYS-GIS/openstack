# OpenStack Keystone + Glance Installation (Ansible-Based)

This documentation describes a fully automated installation of **Keystone** (Identity Service) and **Glance** (Image Service) using **Ansible**. The playbook provisions and configures required services, sets up databases, initializes Keystone, registers Glance, and validates the image upload process.

---

##  Project Layout

```
├── ansible.cfg
├── group_vars
│   └── all.yml
├── inventory.ini
├── playbook.yml
└── roles
    ├── glance
    │   ├── tasks
    │   │   └── main.yml
    │   ├── templates
    │       ├── glance-api-paste.ini.j2
    │       └── glance-api.conf.j2
    │   
    ├── keystone
    │   ├── tasks
    │   │   └── main.yml
    │   ├── templates
    │       └── wsgi-keystone.conf.j2
    │ 
    └── test-setup
        ├── tasks
        │   └── main.yml
        └── vars
            └── main.yml
```
---

## ⚙️ Variable Configuration (`group_vars/all.yml`)

```yaml
# Database passwords
mysql_root_pass: newpassword
keystone_db_pass: keystone_db_pass
glance_db_pass: GlancePass123!

# Keystone admin credentials
keystone_admin_pass: admin

# Glance user password
glance_user_pass: GlancePass123!

# Host and ports
controller_host: localhost
keystone_port: 5001

# Glance test image config
image_file: cirros-0.6.2-x86_64-disk.img
image_name: test-cirros
disk_format: qcow2
container_format: bare

# Keystone/Glance endpoints
keystone_url: http://localhost:5001/v3
glance_url: http://localhost:9292/v2

# Keystone auth scope
admin_user: admin
admin_pass: admin
project_name: admin
domain_name: Default
```

---

##  Keystone Installation (`roles/keystone/tasks/main.yml`)

###  Packages

- Installs: MariaDB, Apache2, WSGI, Memcached, Keystone, OpenStack client, Python packages

###  MariaDB Configuration

- Ensures `bind-address = 127.0.0.1`
- Creates `keystone` database
- Grants privileges to `keystone` user (for `localhost` and `%`)

###  Keystone Config

- Configures `keystone.conf`:
  - `[database]` connection string
  - `[token]` provider = `fernet`
- Runs:
  - `keystone-manage fernet_setup`
  - `keystone-manage credential_setup`
  - `keystone-manage db_sync`
  - `keystone-manage bootstrap`

### Apache WSGI

- Adds Keystone virtual host on port `5001`
- Enables the site and restarts Apache

---

## Glance Installation (`roles/glance/tasks/main.yml`)

###  Database

- Creates `glance` database
- Grants user privileges for `glance` user

###  Configuration

- Renders `glance-api.conf` and `glance-api-paste.ini` from templates
- Sets ownership to `glance:glance`, mode `0640`
- Runs `glance-manage db_sync`

###  Service Setup

- Enables and restarts `glance-api` systemd service

###  Keystone Integration

- Creates:
  - `service` project
  - `glance` user
  - Role binding: `glance` as `admin` in `service`
- Registers Glance:
  - Service type: `image`
  - Endpoints: `public`, `internal`, `admin` at `http://localhost:9292`

---

##  Validation (`roles/test-setup/tasks/main.yml`)

###  Authentication

- Sends `POST /v3/auth/tokens` to Keystone
- Extracts `X-Subject-Token` as auth token

###  Glance API Check

- Polls `GET /images` until 200 OK is received

###  Cirros Image Upload

1. Downloads image if missing
2. Sends metadata via `POST /images`
3. Extracts image `id` from response
4. Uploads binary using `PUT /images/<id>/file`
5. Lists images with `GET /images`
6. Deletes test image using `DELETE /images/<id>`

---

##  Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| **403 Forbidden on Keystone** | Apache WSGI misconfigured | Ensure `Require all granted` in VirtualHost |
| **Image upload fails** | Bad image ID or Glance not ready | Confirm metadata created and Glance is running |
| **Token missing** | Wrong credentials or Keystone unreachable | Double-check `keystone_url` and auth info |
| **DB connection error** | Wrong password or bind-address issue | Check MariaDB logs and config |

---

##  Expected Results

After running the playbook:

- Keystone is reachable at: `http://localhost:5001/v3`
- Glance is reachable at: `http://localhost:9292/v2`
- Keystone admin and Glance service users are functional
- Cirros image is uploaded and deleted via Glance API


