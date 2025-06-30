#!/bin/bash
set -e

# === CONFIGURATION ===

MYSQL_ROOT_PASS="newpassword"
KEYSTONE_DB_PASS="keystone_db_pass"
ADMIN_TOKEN="ADMIN"
CONTROLLER_HOST="localhost"
KEYSTONE_PORT=5001  # Changed port to avoid conflicts

# === FUNCTIONS ===
function install_if_missing {
    PKG="$1"
    if ! dpkg -s "$PKG" >/dev/null 2>&1; then
        echo "Installing $PKG..."
        sudo apt install -y "$PKG"
    else
        echo "$PKG is already installed."
    fi
}

function ensure_mysql_root_password {
    echo "==> Checking MySQL root access..."
    if mysql -u root -e "exit" 2>/dev/null; then
        echo "✅ No MySQL root password yet, setting it..."
        sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}'; FLUSH PRIVILEGES;"
    elif mysql -u root -p"${MYSQL_ROOT_PASS}" -e "exit" 2>/dev/null; then
        echo "✅ MySQL root password already set and valid."
    else
        echo "❌ Could not access MySQL as root. Exiting."
        exit 1
    fi
}

function create_keystone_db {
    echo "==> Configuring Keystone database..."
    sudo mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS keystone;
CREATE OR REPLACE USER 'keystone'@'localhost' IDENTIFIED BY '${KEYSTONE_DB_PASS}';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost';
FLUSH PRIVILEGES;
EOF
}

# === MAIN EXECUTION ===

echo "==> Installing MariaDB and Keystone packages..."
sudo apt update

install_if_missing mariadb-server
install_if_missing python3-pymysql
install_if_missing keystone
install_if_missing apache2
install_if_missing libapache2-mod-wsgi-py3
install_if_missing crudini

# Enable and start MariaDB
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Set MySQL root password if needed
ensure_mysql_root_password

# Create Keystone DB and user
create_keystone_db

# Update keystone.conf
echo "==> Updating keystone.conf..."
sudo crudini --set /etc/keystone/keystone.conf database connection "mysql+pymysql://keystone:${KEYSTONE_DB_PASS}@localhost/keystone"
sudo crudini --set /etc/keystone/keystone.conf token provider fernet
sudo crudini --set /etc/keystone/keystone.conf DEFAULT admin_token "${ADMIN_TOKEN}"

# DB Sync
echo "==> Syncing Keystone DB..."
sudo keystone-manage db_sync

# Fernet keys
echo "==> Initializing Fernet keys..."
sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

# Bootstrap Keystone with new port
echo "==> Bootstrapping Keystone..."
sudo keystone-manage bootstrap --bootstrap-password admin \
  --bootstrap-admin-url http://${CONTROLLER_HOST}:${KEYSTONE_PORT}/v3/ \
  --bootstrap-internal-url http://${CONTROLLER_HOST}:${KEYSTONE_PORT}/v3/ \
  --bootstrap-public-url http://${CONTROLLER_HOST}:${KEYSTONE_PORT}/v3/ \
  --bootstrap-region-id RegionOne

# Add Listen directive to ports.conf if missing
if ! sudo grep -q "^Listen ${KEYSTONE_PORT}$" /etc/apache2/ports.conf; then
    echo "==> Adding Listen ${KEYSTONE_PORT} to /etc/apache2/ports.conf..."
    echo "Listen ${KEYSTONE_PORT}" | sudo tee -a /etc/apache2/ports.conf
fi

# Disable old conflicting site if exists
if sudo a2query -s keystone.conf >/dev/null 2>&1; then
    echo "==> Disabling old Keystone site keystone.conf..."
    sudo a2dissite keystone.conf
fi

# Write Apache WSGI config for Keystone without Listen directive (only <VirtualHost>)
echo "==> Writing Apache WSGI config for Keystone..."
cat <<EOF | sudo tee /etc/apache2/sites-available/wsgi-keystone.conf >/dev/null
<VirtualHost *:${KEYSTONE_PORT}>
    WSGIDaemonProcess keystone processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/apache2/keystone_error.log
    CustomLog /var/log/apache2/keystone_access.log combined
</VirtualHost>
EOF

echo "==> Enabling Keystone Apache site and restarting Apache..."
sudo a2ensite wsgi-keystone.conf

sudo systemctl restart apache2 || {
    echo "❌ Apache failed to start. Check config!"
    sudo apachectl configtest
    exit 1
}

echo "✅ Keystone installation complete!"
