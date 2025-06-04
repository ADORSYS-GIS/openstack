#!/bin/bash

# Define variables
BRIDGE_NAME="br0"
VM1="test-vm1"
VM2="test-vm2"
SUBNET="192.168.100.0/24"

# Create a bridge (if it doesn’t exist)
if ! ip link show $BRIDGE_NAME &> /dev/null; then
  sudo ip link add $BRIDGE_NAME type bridge
  sudo ip link set $BRIDGE_NAME up
  sudo ip addr add 192.168.100.1/24 dev $BRIDGE_NAME
fi

# Stop VMs to attach the bridge
multipass stop $VM1 $VM2

# Attach each VM to the bridge
for VM in $VM1 $VM2; do
  multipass set local.$VM.network.bridge=$BRIDGE_NAME
done

# Start VMs
multipass start $VM1 $VM2

# Assign static IPs inside VMs (optional)
multipass exec $VM1 -- sudo ip addr add 192.168.100.2/24 dev enp0s1
multipass exec $VM2 -- sudo ip addr add 192.168.100.3/24 dev enp0s1

echo "Bridge $BRIDGE_NAME created. VMs $VM1 and $VM2 are connected!"
