#!/bin/sh
# cleanup.sh
# Streams Ansible playbook output and destroys Vagrant VMs if successful.

set -e

# ANSI color codes
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BOLD="\033[1m"
COLOR_UNDERLINE="\033[4m"
COLOR_RESET="\033[0m"

# Logging functions
log_section() {
    echo "${COLOR_BOLD}${COLOR_UNDERLINE}===== $1 =====${COLOR_RESET}"
}

log_info() {
    echo "${COLOR_GREEN}[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1${COLOR_RESET}"
}

log_warning() {
    echo "${COLOR_YELLOW}[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1${COLOR_RESET}"
}

log_error() {
    echo "${COLOR_RED}[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1${COLOR_RESET}" >&2
    exit 1
}

# Parse arguments
FORCE=false
TIMEOUT=3600  # Increased to 1 hour
while [ $# -gt 0 ]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        --timeout=*)
            TIMEOUT=$(echo "$1" | cut -d= -f2)
            shift
            ;;
        *) log_error "Unknown argument: $1" ;;
    esac
done

log_section "Starting Cleanup"

# Verify vagrant command
command -v vagrant >/dev/null 2>&1 || log_error "Vagrant not installed."

# Verify Vagrantfile
[ -f Vagrantfile ] || log_error "Vagrantfile not found in current directory."
# Warn if libvirt provider is not configured
grep "provider.*libvirt" Vagrantfile >/dev/null 2>&1 || log_warning "Vagrantfile may not be configured for libvirt provider."

# Check if VMs are running
log_section "Checking VM Status"
if stdbuf -oL vagrant status | grep -E "controller.*running|compute.*running" | wc -l | grep "^2$" >/dev/null 2>&1; then
    log_info "Both controller and compute VMs are running."
else
    log_error "VMs (controller and compute) are not both running. Current status:\n$(vagrant status)"
fi

# Skip playbook check if --force is used
if [ "$FORCE" = true ]; then
    log_info "Force mode enabled. Skipping playbook success check."
else
    # Wait for Ansible playbook completion while streaming output
    log_section "Streaming Ansible Playbook Output"
    [ -f vagrant_up.log ] || log_error "vagrant_up.log not found. Run './setup.sh' to provision VMs."
    log_info "Streaming output of Ansible playbook (site.yml) from vagrant_up.log (timeout: ${TIMEOUT} seconds)..." # Use ${TIMEOUT}
    ELAPSED=0
    SLEEP=10
    tail -n 0 -f vagrant_up.log &
    TAIL_PID=$!
    while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
        if grep "PLAY RECAP" vagrant_up.log >/dev/null 2>&1; then
            kill $TAIL_PID 2>/dev/null || true
            log_info "Ansible playbook completed."
            break
        fi
        sleep "$SLEEP"
        ELAPSED=$(expr $ELAPSED + $SLEEP)
    done

    # Ensure tail process is terminated
    kill $TAIL_PID 2>/dev/null || true
    wait $TAIL_PID 2>/dev/null || true

    if ! grep "PLAY RECAP" vagrant_up.log >/dev/null 2>&1; then
        log_error "Ansible playbook did not complete within ${TIMEOUT} seconds. Check vagrant_up.log or increase --timeout. VMs preserved." # Use ${TIMEOUT}
    fi

    # Verify failed=0 for controller and compute
    log_section "Verifying Playbook Success"
    for host in controller compute; do
        if grep -A 2 "PLAY RECAP.*$host" vagrant_up.log | grep "failed=0" >/dev/null 2>&1; then
            : # No-op
        else
            log_error "Ansible playbook reported failures for $host. Check vagrant_up.log (search 'PLAY RECAP'). VMs preserved."
        fi
    done
    log_info "Ansible playbook (site.yml) completed successfully with no reported failures."
fi

# Destroy VMs
log_section "Destroying Vagrant VMs"
if stdbuf -oL vagrant destroy -f >vagrant_destroy.log 2>&1; then
    rm -f vagrant_destroy.log
    log_info "Vagrant VMs destroyed successfully."
else
    log_error "Failed to destroy VMs:\n$(cat vagrant_destroy.log)"
fi

# Verify libvirt domains are removed
log_section "Verifying libvirt Domain Cleanup"
if stdbuf -oL virsh -c qemu:///system list --all | grep -E "controller|compute" >/dev/null 2>&1; then
    log_warning "libvirt domains still exist. Attempting manual cleanup..."
    for domain in controller compute; do
        stdbuf -oL virsh -c qemu:///system destroy "$domain" 2>/dev/null || true
        stdbuf -oL virsh -c qemu:///system undefine "$domain" 2>/dev/null || true
    done
    if stdbuf -oL virsh -c qemu:///system list --all | grep -E "controller|compute" >/dev/null 2>&1; then
        log_error "Failed to remove libvirt domains after manual attempt. Manual intervention required."
    fi
fi
log_info "libvirt domains removed successfully."

log_section "Cleanup Complete"
