#!/bin/bash

set -e

# Wait for MariaDB to be ready
while ! mysqladmin ping -h"mariadb" --silent; do
    sleep 1
done

# Create Keystone database and user if they don't exist
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -h mariadb -e "CREATE DATABASE IF NOT EXISTS keystone;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -h mariadb -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DB_PASS';"

# Configure Keystone
crudini --set /etc/keystone/keystone.conf database connection "mysql+pymysql://keystone:$KEYSTONE_DB_PASS@mariadb/keystone"
crudini --set /etc/keystone/keystone.conf token provider fernet

# Populate the Keystone database
keystone-manage db_sync

# Initialize fernet and credential keys only if they don't exist
if [ ! -f /etc/keystone/fernet-keys/0 ]; then
    keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
fi

if [ ! -f /etc/keystone/credential-keys/0 ]; then
    keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
fi

# Bootstrap Keystone only if the admin project doesn't exist
if ! openstack project show admin > /dev/null 2>&1; then
    keystone-manage bootstrap \
        --bootstrap-password "$KEYSTONE_ADMIN_PASS" \
        --bootstrap-admin-url http://localhost:5000/v3/ \
        --bootstrap-internal-url http://localhost:5000/v3/ \
        --bootstrap-public-url http://localhost:5000/v3/ \
        --bootstrap-region-id RegionOne
fi

# Configure Apache
echo "ServerName keystone" >> /etc/apache2/apache2.conf
sed -i "s/{{ keystone_port }}/5000/g" /etc/apache2/sites-available/wsgi-keystone.conf

a2ensite wsgi-keystone.conf

# Start Apache in the foreground
apache2ctl -D FOREGROUND