#!/bin/bash
set -euo pipefail

# Temporarily disable exit on unbound variables to suppress RC_DIR unbound variable errors
set +u
unset RC_DIR || true
unset DEVSTACK_DIR || true
set -u

NEW_MYSQL_ROOT_PASS="newpassword"
GLANCE_DB_PASS="GlancePass123!"
GLANCE_USER_PASS="GlancePass123!"
CONTROLLER_HOST=localhost
KEYSTONE_PORT=5001                     # Keystone runs on this port
KEYSTONE_ADMIN_PASS="admin"           # MUST match Keystone bootstrap password

is_mysql_installed() {
    command -v mysql >/dev/null 2>&1
}

can_mysql_root_no_password() {
    sudo mysql -u root -e "SELECT 1;" >/dev/null 2>&1
}

can_mysql_root_with_password() {
    sudo mysql -u root -p"${NEW_MYSQL_ROOT_PASS}" -e "SELECT 1;" >/dev/null 2>&1
}

keystone_is_up() {
    curl -s -o /dev/null -w "%{http_code}" http://${CONTROLLER_HOST}:${KEYSTONE_PORT}/v3 | grep -qE "200|300"
}

openstack_auth_is_valid() {
    export OS_USERNAME=admin
    export OS_PASSWORD=${KEYSTONE_ADMIN_PASS}
    export OS_PROJECT_NAME=admin
    export OS_AUTH_URL=http://${CONTROLLER_HOST}:${KEYSTONE_PORT}/v3
    export OS_USER_DOMAIN_NAME=Default
    export OS_PROJECT_DOMAIN_NAME=Default
    export OS_IDENTITY_API_VERSION=3

    openstack token issue >/dev/null 2>&1
}

echo "==> Checking if MySQL is installed..."

if ! is_mysql_installed; then
    echo "MySQL not installed. Installing MariaDB and dependencies..."
    sudo DEBIAN_FRONTEND=noninteractive apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server python3-pymysql || true
    sudo systemctl enable mariadb
    sudo systemctl start mariadb

    echo "Setting MySQL root password (initial no-password access)..."
    sudo mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
EOF

else
    echo "MySQL is already installed."

    if can_mysql_root_with_password; then
        echo "MySQL root password is valid."
    elif can_mysql_root_no_password; then
        echo "MySQL root has no password set, setting it now..."
        sudo mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
EOF
    else
        echo "ERROR: Cannot connect to MySQL root user with or without password."
        echo "Please ensure MySQL root password is '${NEW_MYSQL_ROOT_PASS}' or reset it manually."
        exit 1
    fi

    sudo systemctl enable mariadb
    sudo systemctl start mariadb
fi

echo "==> Creating Glance database and user..."
sudo mysql -u root -p"${NEW_MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS glance;
CREATE USER IF NOT EXISTS 'glance'@'localhost' IDENTIFIED BY '${GLANCE_DB_PASS}';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "==> Installing Glance and dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y glance python3-glanceclient apache2 libapache2-mod-wsgi-py3 crudini

echo "==> Checking for OpenStack client..."
if ! command -v openstack >/dev/null 2>&1; then
    echo "Installing python3-openstackclient..."
    sudo apt update
    sudo apt install -y python3-openstackclient
fi

echo "==> Checking if Keystone is up..."
if ! keystone_is_up; then
    echo "ERROR: Keystone service is not reachable at http://${CONTROLLER_HOST}:${KEYSTONE_PORT}/v3."
    echo "Please start Keystone before running this script."
    echo "To avoid RC_DIR errors, consider running this script via:"
    echo "  env -i bash --noprofile --norc ./glance-setup.sh"
    exit 1
fi

echo "==> Validating OpenStack authentication..."
if ! openstack_auth_is_valid; then
    echo "ERROR: Unable to authenticate to Keystone at http://${CONTROLLER_HOST}:${KEYSTONE_PORT}/v3."
    echo "Please check your OS_USERNAME, OS_PASSWORD, and Keystone bootstrap password."
    echo "Ensure Keystone was bootstrapped with password '${KEYSTONE_ADMIN_PASS}'."
    exit 1
fi

# Ensure 'service' project exists (fix for 'No project with a name or ID of service exists' error)
if ! openstack project show service >/dev/null 2>&1; then
    echo "Creating 'service' project in Keystone..."
    openstack project create --domain default service
fi

echo "==> Setting OpenStack environment variables for Glance registration..."
export OS_USERNAME=admin
export OS_PASSWORD=${KEYSTONE_ADMIN_PASS}
export OS_PROJECT_NAME=admin
export OS_AUTH_URL=http://${CONTROLLER_HOST}:${KEYSTONE_PORT}/v3
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_IDENTITY_API_VERSION=3

echo "==> Registering Glance with Keystone..."
if ! openstack user show glance >/dev/null 2>&1; then
    openstack user create --domain default --password "$GLANCE_USER_PASS" glance
fi

openstack role add --project service --user glance admin || true

if ! openstack service show image >/dev/null 2>&1; then
    openstack service create --name glance --description "OpenStack Image" image
fi

if ! openstack endpoint list | grep -q glance; then
    openstack endpoint create --region RegionOne image public "http://${CONTROLLER_HOST}:9292"
    openstack endpoint create --region RegionOne image internal "http://${CONTROLLER_HOST}:9292"
    openstack endpoint create --region RegionOne image admin "http://${CONTROLLER_HOST}:9292"
fi

echo "==> Configuring Glance..."
sudo crudini --set /etc/glance/glance-api.conf database connection "mysql+pymysql://glance:${GLANCE_DB_PASS}@localhost/glance"

sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken www_authenticate_uri "http://${CONTROLLER_HOST}:${KEYSTONE_PORT}"
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url "http://${CONTROLLER_HOST}:${KEYSTONE_PORT}"
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers "${CONTROLLER_HOST}:11211"
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name Default
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name Default
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken password "${GLANCE_USER_PASS}"

sudo crudini --set /etc/glance/glance-api.conf glance_store stores "file,http"
sudo crudini --set /etc/glance/glance-api.conf glance_store default_store "file"
sudo crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir "/var/lib/glance/images/"

echo "==> Migrating Glance database..."
sudo glance-manage db_sync

echo "==> Enabling and starting Glance service..."
sudo systemctl enable glance-api
sudo systemctl restart glance-api

echo "==> Waiting for Glance API to start and respond on port 9292..."
for i in {1..30}; do
    if curl -s http://localhost:9292/v2 >/dev/null 2>&1; then
        echo "Glance API is up!"
        break
    else
        echo "Waiting for Glance API... ($i/30)"
        sleep 2
    fi
done

if ! curl -s http://localhost:9292/v2 >/dev/null 2>&1; then
    echo "ERROR: Glance API did not start properly. Exiting."
    exit 1
fi

echo "==> Downloading and uploading test image (cirros)..."
wget -q http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img || true

if ! openstack image list | grep -q cirros; then
    openstack image create "cirros" \
      --file cirros-0.6.2-x86_64-disk.img \
      --disk-format qcow2 --container-format bare \
      --public
fi

echo "✅ Glance is fully installed, configured, and ready."
