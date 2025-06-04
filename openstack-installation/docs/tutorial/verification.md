# OpenStack Verification Guide

## Service Verification
```bash
# Check all services
openstack service list

# Check endpoints
openstack endpoint list

# Check compute services
openstack compute service list
```

## Network Verification
```bash
# Check networks
openstack network list

# Check routers
openstack router list

# Check security groups
openstack security group list
```

## Instance Verification
```bash
# Create test instance
openstack server create --image cirros --flavor m1.tiny --network provider test-instance

# Check instance status
openstack server list

# Test connectivity
openstack server ssh test-instance
```

## Next Steps
1. [Troubleshooting Guide](troubleshooting.md) 