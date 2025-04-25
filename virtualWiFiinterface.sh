#!/bin/bash

# Check if the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# Function to get a list of wifi interfaces using iwconfig
get_wifi_interfaces() {
  local -n interfaces_array="$1"
  interfaces_array=()
  local index=0

  # Use iwconfig to get a list of wireless interfaces
  local iwconfig_output
  iwconfig_output=$(iwconfig 2>/dev/null)

  # Iterate through the lines of iwconfig output
  while read -r line; do
    # Check if the line contains "IEEE 802.11" which indicates a wireless interface
    if echo "$line" | grep -q "IEEE 802.11"; then
      # Extract the interface name, which is the first word in the line
      interface_name=$(echo "$line" | awk '{print $1}' | tr -d ':')
      interfaces_array+=("$interface_name")
    fi
  done <<< "$iwconfig_output"

  if [ ${#interfaces_array[@]} -eq 0 ]; then
    echo "No Wi-Fi interfaces found by iwconfig."
    echo "Output of iwconfig:"
    iwconfig
    return 1
  fi
  return 0
}

# Function to create a virtual interface and set it to monitor mode
create_virtual_interface_and_set_monitor() {
  local base_interface="$1"
  local vif_name="$2"
  local vif_type="$3"

  # Check if base interface exists
  if ! ip link show "$base_interface" >/dev/null 2>&1; then
    echo "Error: Base interface $base_interface does not exist."
    return 1
  fi

  # Check if the virtual interface name is already in use
  if ip link show "$vif_name" >/dev/null 2>&1; then
    echo "Error: Interface name $vif_name is already in use."
    return 1
  fi

  # Create the virtual interface
  echo "Creating virtual interface: iw dev \"$base_interface\" interface add \"$vif_name\" type \"$vif_type\""
  iw dev "$base_interface" interface add "$vif_name" type "$vif_type"
  if [ $? -ne 0 ]; then
    echo "Failed to create virtual interface $vif_name on $base_interface"
    return 1
  fi

  # Bring the interface up
  echo "Bringing up virtual interface: ip link set \"$vif_name\" up"
  ip link set "$vif_name" up
  if [ $? -ne 0 ]; then
    echo "Failed to bring up interface $vif_name"
    # Clean up.
    iw dev "$vif_name" del
    return 1
  fi
  echo "Created virtual interface $vif_name of type $vif_type on $base_interface"

  # Set the virtual interface to monitor mode
  echo "Setting virtual interface $vif_name to monitor mode..."
  ip link set "$vif_name" down
  iw dev "$vif_name" set type monitor
  ip link set "$vif_name" up
  if [ $? -ne 0 ]; then
    echo "Failed to set virtual interface $vif_name to monitor mode."
    return 1
  fi
  echo "Successfully set $vif_name to monitor mode."
  return 0
}

# Function to find the next available virtual interface name
find_next_virtual_interface_name() {
  local base_name="virt_$1"
  local index=0
  local next_name

  while true; do
    next_name="${base_name}${index}"
    if ! ip link show "$next_name" >/dev/null 2>&1; then
      printf "%s\n" "$next_name"
      return
    fi
    index=$((index + 1))
  done
}

# Function to remove all virtual interfaces
remove_all_virtual_interfaces() {
  local -a virtual_interfaces=()
  local index=0

  # Get all interfaces
  local all_interfaces
  all_interfaces=$(ip link show)

  # Filter for virtual interfaces (assuming they start with "virt_")
  while read -r line; do
    if [[ "$line" == *"virt_"* ]]; then
      interface_name=$(echo "$line" | awk '{print $2}' | tr -d ':')
      virtual_interfaces+=("$interface_name")
    fi
  done <<< "$all_interfaces"

  # Remove each virtual interface
  if [ ${#virtual_interfaces[@]} -gt 0 ]; then
    echo "Removing the following virtual interfaces:"
    for vif in "${virtual_interfaces[@]}"; do
      echo "  - $vif"
      ip link set "$vif" down
      iw dev "$vif" del
      if [ $? -ne 0 ]; then
        echo "Failed to remove virtual interface $vif"
      else
        echo "Successfully removed virtual interface $vif"
      fi
    done
  else
    echo "No virtual interfaces found to remove."
  fi
}

# Function to set the interface to monitor mode
set_interface_to_monitor() {
  local interface_name="$1"
  local current_type

  # Use airmon-ng to check for conflicting processes and set monitor mode
  echo "Putting interface $interface_name into monitor mode using airmon-ng..."
  airmon-ng check "$interface_name"
  if [ $? -eq 0 ]; then # airmon-ng check returns 0 if it finds conflicts
    echo "Found conflicting processes. Killing them..."
    airmon-ng check kill
  fi
  airmon-ng start "$interface_name"
  if [ $? -ne 0 ]; then
    echo "Failed to set interface $interface_name to monitor mode using airmon-ng."
    return 1
  else
    echo "Successfully set interface $interface_name to monitor mode."
  fi
  return 0
}

#
# Main Script
#

wifi_interfaces=()
get_wifi_interfaces wifi_interfaces

if [ $? -ne 0 ]; then
  exit 1 # Exit if no interfaces found
fi

# Display the Wi-Fi interfaces
echo "Available Wi-Fi interfaces:"
for i in "${!wifi_interfaces[@]}"; do
    echo "$((i+1)). ${wifi_interfaces[$i]}"
done
echo "R. Remove all virtual Wi-Fi interfaces" # Changed from U to R

# Prompt the user to choose an interface
read -p "Enter the number of the Wi-Fi interface to use, or 'R' to remove all virtual interfaces: " selected_interface_num # Changed from U to R

# Validate the user input
if [[ "$selected_interface_num" == "R" || "$selected_interface_num" == "r" ]]; then # Changed from U to R
  remove_all_virtual_interfaces
  exit 0
fi

if ! [[ "$selected_interface_num" -ge 1 && "$selected_interface_num" -le "${#wifi_interfaces[@]}" ]]; then
  echo "Invalid interface number."
  exit 1
fi

# Get the selected interface name
selected_interface_index=$((selected_interface_num - 1))
BASE_INTERFACE="${wifi_interfaces[$selected_interface_index]}"

echo "Using Wi-Fi interface: $BASE_INTERFACE"

# Check if the base interface is up
if ! ip link show "$BASE_INTERFACE" | grep -q "state UP"; then
  echo "Base interface $BASE_INTERFACE is not up, attempting to bring it up..."
  sudo ip link set "$BASE_INTERFACE" up
  if [ $? -ne 0 ]; then
    echo "Error: Failed to bring up interface $BASE_INTERFACE.  Exiting."
    exit 1
  else
    echo "Successfully brought up interface $BASE_INTERFACE"
  fi
fi

# Set the selected physical interface to monitor mode
set_interface_to_monitor "$BASE_INTERFACE"
if [ $? -ne 0 ]; then
  echo "Failed to set the physical interface $BASE_INTERFACE to monitor mode. Exiting."
  exit 1
fi

# Create one virtual interface
num_vifs=1 # Specify the number of virtual interfaces you want to create
echo "Creating $num_vifs virtual interfaces..."
for i in $(seq 1 $num_vifs); do
  echo "Iteration: $i"
  next_vif_name=$(find_next_virtual_interface_name "$BASE_INTERFACE")
  echo "Next vif name to use: $next_vif_name"
  if [ -z "$next_vif_name" ]; then
    echo "Error: Could not determine next available virtual interface name."
    exit 1
  fi
  create_virtual_interface_and_set_monitor "$BASE_INTERFACE" "$next_vif_name" "managed"
  if [ $? -ne 0 ]; then
    echo "Error creating interface $next_vif_name.  Exiting."
    exit 1
  fi
  echo "Virtual interface creation complete. Created interface: $next_vif_name and set it to monitor mode."
done
