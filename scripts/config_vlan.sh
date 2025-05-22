#!/bin/bash
sudo ovs-vsctl list-br

vmbridge=

echo "Do you want to use one of the existing or you want to creat your own bridge: choose [use/create]"
read option
if [[ "$option" == "create" ]]; then
	read -p "Enter the bridge name: " brname
	sudo ovs-vsctl add-br $brname # creating ovs
	echo "$brname created successfully!!"
	vmbridge=$brname
elif [[ "$option" == "use" ]] ; then
	read -p "Enter bridge name: " brname
	echo "You choosed $brname"
	vmbridge=$brname
else
	echo "Choose one of the above options"
	exit 1
fi

## configuring VLANs
echo "Configuring VLAN ..."

read -p "How many VLAN do you want to configure ?: " vlannum
sudo ovs-vsctl set port $brname vlan_mode=native-untagged
sudo ovs-vsctl set port $brname trunks="0,$(seq -s ',' 1 $($vlannum-1))"

# checking if vlann has been configured successfully

if [[ $? -eq 0 ]]; then
	echo "VLANs configuration was not successful"
fi

echo "Succcessfully set up VLANs"


## Create VMs base on the number of machines the user choose and the default name

read -p "Enter the number of default name for you VMs: " vmname
read -p "Enter the number of VM you want to create: " vmnumber
read -p "Enter the disk size for each instance: " vmdisk
read -p "Enter the memory size for each instance: " vmmem
read -p "Enter the number of CPU for each instance: " vmcpu

## Creating VM with the flavor precised by the user

echo "Creating $vmnumber with default name $vmname, disk size $vmdisk, memory size $vmmem and number of CPUs $vmcpu"

for i in {1..$vmnumber}; do
	multipass launch --name $vmname$i --disk $vmdisk --memory $vmmem --cpus $vmcpu --network name=$vmbridge --network name=default
done

## configuring VLAN tagging

echo "Configuring VLAN tagging"

for i in {0..$vlannum}; do 
	read -p "How many machines do you want on VLAN$i?: " group"$i"num

	for j in {0..$group"$i"num}; do
		sudo ovs-vsctl set $vmname-eth0 tag=$i
	done

done

## Configuring Network Interfaces  In VMs

echo "Configuring Network Interfaces In VMs"
for i in {1..$vmnumber}; do
	multipass exec $vmname$i -- sudo ip link set eth0 up
	multipass exec $vmname$i -- sudo ip addr add 192.168.$vlannum.10$i/24 dev eth0
done
	
## Verifying Configuration of OVS
echo "Checking OVS configuration "
sudo ovs-vsctl show
sudo ovs-vsctl list port

## Test connectivity 

multipass exec $vmname1 -- ping -c 5 192.168.$vlannum.10$i
