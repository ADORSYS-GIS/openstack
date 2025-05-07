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
    sudo ovs-vsctl add-br "$brname" # creating ovs
    if [[ $? -eq 0 ]]; then
        echo -e "$brname created successfully!!\n"
        vmbridge=$brname
        multipass set local.bridged-network=$brname
    else
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
    exit 1
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

# Create VMs
for ((i = 1; i <= vmnumber; i++)); do
    echo -e "Creating VM $vmname$i...\n"
    
    # First create VM with default network only
    multipass launch --verbose --name "$vmname$i" \
        --disk "$vmdisk" \
        --memory "$vmmem" \
        --cpus "$vmcpu" \
        --network virbr0 \
        24.04
    
    if [[ $? -ne 0 ]]; then
        echo -e "Failed to create VM $vmname$i\n"
        exit 1
    fi
    
    # Stop VM and attach to OVS bridge
    multipass stop "$vmname$i"
    sudo ovs-vsctl add-port "$vmbridge" "${vmname}${i}-eth0"
    multipass start "$vmname$i"
done

## Configuring VLAN tagging
## Configuring VLAN tagging - Updated Version
echo -e "\nConfiguring VLAN tagging...\n"

for ((i = 0; i < vlannum; i++)); do
    read -p "Enter VM names for VLAN$i (space-separated): " -a vm_names
    echo -e "Configuring VLAN $i for VMs: ${vm_names[*]}...\n"
    
    for vm in "${vm_names[@]}"; do
        if multipass list | grep -q "$vm"; then
            interface_name=$(multipass info "$vm" | grep -A 1 "Network" | grep -o "eth[0-9]")
            echo -e "Setting VLAN $i for $vm (interface: $interface_name)...\n"
            sudo ovs-vsctl set port "$interface_name" tag=$i
        else
            echo -e "VM $vm not found! Skipping...\n"
        fi
    done
done

## Configuring Network Interfaces In VMs
echo -e "\nConfiguring Network Interfaces In VMs...\n"

for ((i = 1; i <= vmnumber; i++)); do
    echo -e "Configuring network for $vmname$i...\n"
    multipass exec "$vmname$i" -- sudo ip link set eth0 up
    multipass exec "$vmname$i" -- sudo ip addr add "192.168.$i.10/24" dev eth0
    if [[ $? -eq 0 ]]; then
        echo -e "Network configured successfully for $vmname$i\n"
    else
        echo -e "Failed to configure network for $vmname$i\n"
    fi
done

## Verifying Configuration of OVS
echo -e "\nChecking OVS configuration...\n"
sudo ovs-vsctl show
sudo ovs-vsctl list port

## Test connectivity between VMs in same VLAN
echo -e "\nTesting connectivity between VMs in the same VLAN...\n"
for ((i = 0; i <= vlannum; i++)); do
    if [[ ${vlan_groups[$i]} -gt 1 ]]; then
        echo -e "Testing connectivity in VLAN $i...\n"
        # Find first two VMs in this VLAN
        vm1=""
        vm2=""
        vm_count=0
        for ((j = 1; j <= vmnumber; j++)); do
            if [[ "$(sudo ovs-vsctl get port "$vmname$j-eth0" tag)" == "$i" ]]; then
                if [[ -z "$vm1" ]]; then
                    vm1="$vmname$j"
                elif [[ -z "$vm2" ]]; then
                    vm2="$vmname$j"
                    break
                fi
            fi
        done
        if [[ -n "$vm1" && -n "$vm2" ]]; then
            echo -e "Testing ping from $vm1 to $vm2...\n"
            multipass exec "$vm1" -- ping -c 3 "192.168.$i.10"
        fi
    fi
done
echo -e "\nConfiguration Completed successfully !!!\n"
