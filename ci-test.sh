#!/bin/bash
set -e

# 1. Bring up the Vagrant VM and run provisioning
echo "[CI] Starting Vagrant VM..."
vagrant up --provider=libvirt

# 2. Get the VM's IP address (using the default libvirt network)
VM_IP=$(vagrant ssh -c "hostname -I | awk '{print \$2}'" | tr -d '\r')
echo "[CI] VM IP: $VM_IP"

# 3. Test Keystone API endpoint (default port 5000)
echo "[CI] Checking Keystone API..."
vagrant ssh -c "curl -sf http://localhost:5000/v3/" || {
    echo "❌ Keystone API not responding!"
    vagrant destroy -f
    exit 1
}

echo "✅ Keystone API is up!"

# 4. Clean up
echo "[CI] Destroying Vagrant VM..."
vagrant destroy -f
