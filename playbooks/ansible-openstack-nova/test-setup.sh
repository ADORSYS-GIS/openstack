#!/bin/bash
# test-setup.sh
# Test script to verify the OpenStack Nova setup

# This script is designed to work with the OpenStack Nova setup project
# It can be called automatically by setup.sh to verify the setup

set -e

echo "Testing OpenStack Nova Setup"
echo "============================"

# Check if VMs are running
echo "1. Checking VM status..."
if vagrant status | grep -E "controller.*running|compute.*running" | wc -l | grep -q "^2$"; then
    echo "✓ Both controller and compute VMs are running"
else
    echo "✗ VMs are not running properly"
    exit 1
fi

# SSH into controller and check OpenStack services
echo "2. Checking OpenStack services..."
if vagrant ssh controller -c "source ~/admin-openrc.sh && openstack service list" >/dev/null 2>&1; then
    echo "✓ OpenStack services are accessible"
else
    echo "✗ Cannot access OpenStack services"
    exit 1
fi

# Check if Nova services are running
echo "3. Checking Nova services..."
if vagrant ssh controller -c "source ~/admin-openrc.sh && openstack compute service list" >/dev/null 2>&1; then
    echo "✓ Nova services are running"
else
    echo "✗ Nova services are not running properly"
    exit 1
fi

# Check if we can list images
echo "4. Checking Glance images..."
if vagrant ssh controller -c "source ~/admin-openrc.sh && openstack image list" >/dev/null 2>&1; then
    echo "✓ Glance images are accessible"
else
    echo "✗ Cannot access Glance images"
    exit 1
fi

echo ""
echo "All tests passed! The OpenStack Nova setup is working correctly."
echo ""
echo "You can now:"
echo "  - SSH into the controller: vagrant ssh controller"
echo "  - SSH into the compute node: vagrant ssh compute"
echo "  - Access OpenStack CLI on the controller VM"