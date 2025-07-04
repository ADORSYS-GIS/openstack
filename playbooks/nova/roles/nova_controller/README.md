# Role: nova\_controller

This role installs and configures the Nova controller services for OpenStack.

## Responsibilities

* Create `nova` and `nova_api` MySQL databases.
* Create the Keystone `nova` user and assign the `admin` role.
* Register the Nova service and API endpoints (public, internal, admin) in Keystone.
* Install and enable Nova controller components: `nova-api`, `nova-scheduler`, `nova-conductor`.
* Manage `nova.conf` configuration using a Jinja2 template.
* Synchronize Nova and Nova API database schemas.

## Variables

| Variable                     | Description                                          |
| ---------------------------- | ---------------------------------------------------- |
| `nova_db_password`           | Password for the MySQL user `nova`.                  |
| `nova_user_password`         | Password for the Keystone user `nova`.               |
| `nova_api_url`               | Base URL used for registering Nova API endpoints.    |
| `db_host`                    | Hostname or IP address of the MySQL database server. |
| `keystone_host`              | Hostname or IP address of the Keystone service.      |
| `memcached_host`             | Hostname or IP address of the Memcached server.      |
| `nova_keystone_service_name` | Keystone service name (default: `nova`).             |
| `nova_keystone_service_type` | Keystone service type (default: `compute`).          |
| `nova_keystone_description`  | Description for the Keystone Nova service.           |
| `nova_services`              | List of Nova services to manage and start.           |

Variables should be defined in `group_vars`, `host_vars`, or passed at runtime.
