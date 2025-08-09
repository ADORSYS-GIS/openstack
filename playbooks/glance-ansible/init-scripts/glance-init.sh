#!/bin/bash

set -e

# Wait for Keystone to be ready
while ! curl -s http://keystone:5000/v3; do
    echo "Waiting for Keystone to be available..."
    sleep 1
done

# Wait for MariaDB to be ready
while ! mysqladmin ping -h"mariadb" --silent; do
    sleep 1
done

# Create Glance database and user if they don't exist
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -h mariadb -e "CREATE DATABASE IF NOT EXISTS glance;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -h mariadb -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DB_PASS';"

# Configure Glance
crudini --set /etc/glance/glance-api.conf database connection "mysql+pymysql://glance:$GLANCE_DB_PASS@mariadb/glance"
crudini --set /etc/glance/glance-api.conf keystone_authtoken www_authenticate_uri http://keystone:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://keystone:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers memcached:11211
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name Default
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name Default
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken password "$GLANCE_USER_PASS"
crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone

# Populate the Glance database
glance-manage db_sync

# Create the service project, glance user, and assign roles if they don't exist
if ! openstack project show service > /dev/null 2>&1; then
    openstack project create --domain default --description "Service Project" service
fi

if ! openstack user show glance > /dev/null 2>&1; then
    openstack user create --domain default --password "$GLANCE_USER_PASS" glance
fi

if ! openstack role assignment list --project service --user glance --role admin | grep -q admin; then
    openstack role add --project service --user glance admin
fi

# Create the glance service and endpoints if they don't exist
if ! openstack service show image > /dev/null 2>&1; then
    openstack service create --name glance --description "OpenStack Image" image
fi

if ! openstack endpoint list --service image --interface public | grep -q image; then
    openstack endpoint create --region RegionOne image public http://localhost:9292
fi

if ! openstack endpoint list --service image --interface internal | grep -q image; then
    openstack endpoint create --region RegionOne image internal http://localhost:9292
fi

if ! openstack endpoint list --service image --interface admin | grep -q image; then
    openstack endpoint create --region RegionOne image admin http://localhost:9292
fi

# Start Glance API
glance-api