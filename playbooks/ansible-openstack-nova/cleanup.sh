#!/bin/sh

# Waits for Ansible playbook (site.yml) to complete, then destroys Vagrant VMs if successful.

set -e

# Parse arguments
FORCE=false
TIMEOUT=1800 # 30 minutes in seconds
while [ "$#" -gt 0 ]; do # POSIX: Use "$#" for argument count
    case "$1" in
        --force) FORCE=true; shift ;;
        --timeout=*)
            TIMEOUT=$(echo "$1" | cut -d'=' -f2)
            shift
            ;;
        *) echo "Error: Unknown argument: $1"; exit 1 ;;
    esac
done

echo "Starting cleanup..."

# Verify vagrant command
command -v vagrant >/dev/null || { echo "Error: Vagrant not installed. Exiting."; exit 1; }

# Verify Vagrantfile
[ -f Vagrantfile ] || { echo "Error: Vagrantfile not found in current directory. Exiting."; exit 1; }
# Removed brittle grep check for provider, Vagrant handles this.
# grep -q "provider.*libvirt" Vagrantfile || { echo "Warning: Vagrantfile may not be configured for libvirt provider."; }

# Check if VMs are running
echo "Checking if VMs are running..."
# Using grep -E for extended regex |
if ! vagrant status | grep -E "controller.*running|compute.*running" | wc -l | grep -q "^2$"; then
    echo "Error: VMs (controller and compute) are not both running. Nothing to destroy."
    vagrant status
    exit 1
fi
echo "Both controller and compute VMs are running."

# Skip playbook check if --force is used
if [ "$FORCE" = true ]; then # POSIX: Use = instead of == for string comparison
    echo "Force mode enabled. Skipping playbook success check."
else
    # Wait for Ansible playbook completion
    if [ ! -f vagrant_up.log ]; then
        echo "Error: vagrant_up.log not found. Please ensure './setup.sh' was run to provision VMs. Exiting."
        exit 1
    fi

    echo "Waiting for Ansible playbook (site.yml) to complete (timeout: $TIMEOUT seconds)..."
    ELAPSED=0
    SLEEP=10
    while [ "$ELAPSED" -lt "$TIMEOUT" ]; do # POSIX: Use = instead of == for string comparison
        if grep -q "PLAY RECAP" vagrant_up.log; then
            echo "Ansible playbook completed."
            break
        fi
        sleep "$SLEEP" # POSIX: Quote variables in sleep
        ELAPSED=$((ELAPSED + SLEEP)) # POSIX: Arithmetic expansion is fine
        echo "Waited $ELAPSED seconds..."
    done

    if ! grep -q "PLAY RECAP" vagrant_up.log; then
        echo "Error: Ansible playbook did not complete within $TIMEOUT seconds."
        echo "Check vagrant_up.log or increase --timeout. VMs preserved for debugging. Exiting."
        exit 1
    fi

    # Verify failed=0 for controller and compute
    # NOTE: `grep -A` is a GNU grep extension. For strict POSIX `sh` compatibility,
    # more complex parsing with `awk` or `sed` would be needed.
    # However, GNU grep is widely available on most Linux systems.
    echo "Verifying Ansible playbook success..."
    for host in controller compute; do
        if ! grep -A 2 "PLAY RECAP.*$host" vagrant_up.log | grep -q "failed=0"; then
            echo "Error: Ansible playbook reported failures for $host."
            echo "Check vagrant_up.log (search for 'PLAY RECAP' and '$host'). VMs preserved for debugging. Exiting."
            exit 1
        fi
    done
    echo "Ansible playbook (site.yml) completed successfully with no reported failures."
fi

# Destroy VMs
echo "Destroying Vagrant VMs..."
vagrant destroy -f >vagrant_destroy.log 2>&1 || { echo "Error: Failed to destroy VMs. Check vagrant_destroy.log for details. Exiting."; cat vagrant_destroy.log; exit 1; }
rm -f vagrant_destroy.log # Clean up temp log file

# Verify libvirt domains are removed
echo "Verifying libvirt domains are removed..."
if virsh -c qemu:///system list --all | grep -E "controller|compute" >/dev/null; then
    echo "Warning: libvirt domains still exist. Attempting manual cleanup..."
    for domain in controller compute; do
        virsh -c qemu:///system destroy "$domain" 2>/dev/null || true # Attempt to destroy if still running
        virsh -c qemu:///system undefine "$domain" 2>/dev/null || true # Attempt to undefine
    done
    if virsh -c qemu:///system list --all | grep -E "controller|compute" >/dev/null; then
        echo "Error: Failed to remove libvirt domains after manual attempt. Manual intervention may be required. Exiting."
        exit 1
    fi
fi
echo "Vagrant VMs and associated libvirt domains destroyed successfully."

echo "Cleanup complete."
