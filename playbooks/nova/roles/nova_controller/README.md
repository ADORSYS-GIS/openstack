# Role: nova_controller

Installs and configures the Nova controller services in OpenStack.

## Responsibilities:
- Create nova and nova_api databases
- Create nova user and assign admin role
- Register nova service and API endpoints in Keystone
- Install and start controller components: API, Scheduler, Conductor
- Apply nova.conf configuration via Jinja2
- Sync database schemas

## Variables:
- `nova_db_password`: Password for the DB user 'nova'
- `nova_user_password`: Keystone password for nova user
- `nova_api_url`: URL for nova public/internal/admin API endpoints

## Notes:
- Requires Keystone to be installed and available.
- Assumes admin credentials are sourced in `/root/admin-openrc.sh`.
