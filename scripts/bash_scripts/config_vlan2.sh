#!/bin/bash
# List available bridges
echo -e "Listing available bridges...\n"
sudo ovs-vsctl list-br

vmbridge=

echo -e "\nDo you want to use one of the existing or you want to create your own bridge: choose [use/create]"
read option
if [[ "$option" == "create" ]]; then
    read -p "Enter the bridge name: " brname
    if [[ -z "$brname" ]]; then
        echo -e "Bridge name cannot be empty\n"
        exit 1
    fi
    echo -e "Creating bridge $brname...\n"
    sudo ovs-vsctl add-br "$brname" # creatgit rebase -i HEAD~10ing ovs
    if [[ $? -eq 0 ]]; then
        echo -e "$brname created successfully!!\n"
        vmbridge=$brname
        multipass set local.bridged-network=$brnamegit rebase -i HEAD~10
        echo -e "Failed to create bridge $brname\n"
        exit 1
    fi
elif [[ "$option" == "use" ]]; then
    read -p "Enter bridge name: " brname
    echo -e "You chose $brname\n"
    multipass set local.bridged-network=$brname
    vmbridge=$brname
else
    echo -e "Choose one of the above options\n"
    exit 1
fi
sudo ip link set $brname up

## Configuring VLANs
echo -e "\nConfiguring VLAN ...\n"

read -p "How many VLANs do you want to configure?: " vlannum

# Validate VLAN number
if ! [[ "$vlannum" =~ ^[0-9]+$ ]] || [ "$vlannum" -lt 1 ]; then
    echo -e "Please enter a valid number of VLANs\n"
    exit 1
fi

echo -e "Setting VLAN mode to native-untagged...\n"
if ! sudo ovs-vsctl set port "$brname" vlan_mode=native-untagged; then
    echo -e "Failed to set VLAN mode\n"
    exitgit rebase -i HEAD~10 1
fi

echo -e "Configuring VLAN trunks...\n"
if ! sudo ovs-vsctl set port "$brname" trunks="0,$(seq -s ',' 1 $((vlannum - 1)))"; then
    echo -e "Failed to configure VLAN trunks\n"
    exit 1
fi

echo -e "Successfully set up VLANs\n"

## Create VMs based on user specifications
read -p "Enter the default name prefix for your VMs: " vmname
read -p "Enter the number of VMs you want to create: " vmnumber
read -p "Enter the disk size for each instance (e.g., 10G): " vmdisk
read -p "Enter the memory size for each instance (e.g., 2G): " vmmem
read -p "Enter the number of CPUs for each instance: " vmcpu

echo -e "\nCreating $vmnumber VMs with:\n"
echo -e "- Name prefix: $vmname"
echo -e "- Disk size: $vmdisk"
echo -e "- Memory size: $vmmem"
echo -e "- CPUs: $vmcpu\n"

# Create VMs with NAT only first
for ((i = 1; i <= vmnumber; i++)); do
    echo -e "Creating VM $vmname$i...\n"
    multipass launch --name "$vmname$i" --disk "$vmdisk" --memory "$vmmem" --cpus "$vmcpu" --network virbr0 24.04
    if [[ $? -ne 0 ]]; then
        echo -e "Failed to create VM $vmname$i\n"
        exit 1
    fi
    # Stop VM and attach to OVS bridge
    multipass stop "$vmname$i"
    # MODIFIED: Get actual interface name dynamically
    interface_name=$(multipass exec "$vmname$i" -- ip -o link show | awk -F': ' '!/lo/ {print $2; exit}')
    if [[ -z "$interface_name" ]]; then
        echo -e "Error: Could not determine interface for $vmname$i\n"
        exit 1
    fi
    sudo ovs-vsctl add-port "$vmbridge" "$interface_name"
done

## MODIFIED: VLAN tagging with name input instead of count
echo -e "\nConfiguring VLAN tagging...\n"

for ((i = 0; i < vlannum; i++)); do
    read -p "Enter VM names for VLAN$i (space-separated): " -a vm_names
    echo -e "Configuring VLAN $i for VMs: ${vm_names[*]}...\n"

    for vm in "${vm_names[@]}"; do
        if ! multipass list | grep -q "$vm"; then
            echo -e "Error: VM $vm not found! Skipping...\n"
            continue
        fi

        # Get the actual interface name
        interface_name=$(multipass exec "$vm" -- ip -o link show | awk -F': ' '!/lo/ {print $2; exit}')

        if [[ -z "$interface_name" ]]; then
            echo -e "Error: Could not determine interface for $vm\n"
            continue
        fi

        echo -e "Setting VLAN $i for $vm (interface: $interface_name)...\n"
        multipass stop "$vm"
        sudo ovs-vsctl set port "${vm}-${interface_name}" tag=$i
        multipass start "$vm"
    done
done

## Optimized Network Configuration
echo -e "\nConfiguring Network Interfaces In VMs...\n"

for ((i = 1; i <= vmnumber; i++)); do
    vm="$vmname$i"
    echo -e "Configuring network for $vm...\n"

    # Fast interface detection (limited to common virtual NIC patterns)
    interface_name=$(multipass exec "$vm" -- ls /sys/class/net/ | grep -E '^e(n|th)[a-z0-9]+$' | head -1)

    # Fallback to ens3 if detection fails
    [[ -z "$interface_name" ]] && interface_name="ens3"

    # Get VLAN tag (with caching)
    vlan_tag=$(sudo ovs-vsctl get port "$interface_name" tag 2>/dev/null || echo "1")

    # Atomic configuration
    if multipass exec "$vm" -- sudo bash -c "
        ip link set $interface_name up
        ip addr flush dev $interface_name 2>/dev/null
        ip addr add 192.168.$vlan_tag.$((10 + i))/24 dev $interface_name
        ip route add default via 192.168.$vlan_tag.1
    " >/dev/null 2>&1; then
        echo -e "Success: $vm ($interface_name) → 192.168.$vlan_tag.$((10 + i))/24\n"
    else
        echo -e "Error: Failed to configure $vm\n"
        echo -e "Debug Info:"
        multipass exec "$vm" -- ip addr show 2>/dev/null || echo "Cannot connect to VM"
        continue
    fi
done

## Verifying Configuration of OVS
echo -e "\nChecking OVS configuration...\n"
sudo ovs-vsctl show
sudo ovs-vsctl list port

## Test connectivity between VMs in same VLAN
echo -e "\nTesting connectivity between VMs in the same VLAN...\n"
for ((i = 0; i < vlannum; i++)); do
    echo -e "Testing connectivity in VLAN $i...\n"
    vms_in_vlan=($(sudo ovs-vsctl list port | awk -v tag="$i" '/tag:/ && $2 == tag {print $1}'))

    if [[ ${#vms_in_vlan[@]} -ge 2 ]]; then
        first_vm=$(multipass list | awk -v iface="${vms_in_vlan[0]}" '$6 == iface {print $1}')
        second_vm=$(multipass list | awk -v iface="${vms_in_vlan[1]}" '$6 == iface {print $1}')

        if [[ -n "$first_vm" && -n "$second_vm" ]]; then
            target_ip="192.168.$i.$((10 + $(echo $second_vm | sed 's/[^0-9]//g')))"
            echo -e "Testing ping from $first_vm to $second_vm ($target_ip)...\n"
            multipass exec "$first_vm" -- ping -c 3 "$target_ip"
        fi
    else
        echo -e "Not enough VMs in VLAN $i for testing\n"
    fi
done

echo -e "\nConfiguration Completed successfully !!!\n"
