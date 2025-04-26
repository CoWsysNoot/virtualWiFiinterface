#!/bin/bash

# Check if the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
  echo -e "\e[31mThis script must be run as root.\e[0m"
  exit 1
fi

# Define color codes
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
ORANGE="\e[38;5;208m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

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
      # Exclude wlan0 from the list
      if [[ "$interface_name" != "wlan0" ]]; then
        interfaces_array+=("$interface_name")
      fi
    fi
  done <<< "$iwconfig_output"

  if [ ${#interfaces_array[@]} -eq 0 ]; then
    echo -e "${RED}No Wi-Fi interfaces found by iwconfig (excluding wlan0).${RESET}"
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
    echo -e "${RED}Error: Base interface $base_interface does not exist.${RESET}"
    return 1
  fi

  # Check if the virtual interface name is already in use
  if ip link show "$vif_name" >/dev/null 2>&1; then
    echo -e "${RED}Error: Interface name $vif_name is already in use.${RESET}"
    return 1
  fi

  # Create the virtual interface
  iw dev "$base_interface" interface add "$vif_name" type "$vif_type"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create virtual interface $vif_name on $base_interface${RESET}"
    return 1
  fi

  # Bring the interface up
  ip link set "$vif_name" up
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to bring up interface $vif_name${RESET}"
    # Clean up.
    iw dev "$vif_name" del
    return 1
  fi

  # Set the virtual interface to monitor mode
  ip link set "$vif_name" down
  iw dev "$vif_name" set type monitor
  ip link set "$vif_name" up
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to set virtual interface $vif_name to monitor mode.${RESET}"
    return 1
  fi
  echo -e "${GREEN}Successfully created interface: ${CYAN}$vif_name${GREEN} and set it to monitor mode.${RESET}"
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
    echo -e "${ORANGE}Removing the following virtual interfaces:${RESET}"
    for vif in "${virtual_interfaces[@]}"; do
      echo -e "  - ${CYAN}$vif${RESET}"
      ip link set "$vif" down
      iw dev "$vif" del
      if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to remove virtual interface $vif${RESET}"
      else
        echo -e "${GREEN}Successfully removed virtual interface $vif${RESET}"
      fi
    done
  else
    echo -e "${GREEN}No virtual interfaces found to remove.${RESET}"
  fi
  service NetworkManager start

}

# Function to set the interface to monitor mode
set_interface_to_monitor() {
  local interface_name="$1"

  # Use ifconfig and iw to set monitor mode, and keep original name
  sudo ifconfig "$interface_name" down
  sudo iw dev "$interface_name" set type monitor
  sudo ifconfig "$interface_name" up

  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to set interface $interface_name to monitor mode using ifconfig and iw.${RESET}"
    return 1
  fi

  # Use airmon-ng to check for conflicting processes and kill them
  airmon-ng check kill
  if [ $? -ne 0 ]; then
    echo -e "${RED}Found conflicting processes. Killing them...  ${RESET}"
  else
     echo -e "${YELLOW}Killed conflicting processes. ${RESET}"
  fi
  return 0
}

#
# Main Script
#
while true; do #added loop
  wifi_interfaces=()
  get_wifi_interfaces wifi_interfaces

  if [ $? -ne 0 ]; then
    exit 1 # Exit if no interfaces found
  fi

  # Display the Wi-Fi interfaces
  echo -e "${GREEN}Available Wi-Fi interfaces:${RESET}"
  for i in "${!wifi_interfaces[@]}"; do
    interface_name="${wifi_interfaces[$i]}"
    if [[ "$interface_name" == "virt_"* ]]; then
      echo -e "$((i+1)). ${BLUE}${interface_name}${RESET}" # Blue for virtual
    else
      echo -e "$((i+1)). ${GREEN}${interface_name}${RESET}" # Green for physical
    fi
  done
  echo -e "${ORANGE}R. Remove all virtual Wi-Fi interfaces${RESET}"
  echo -e "${RED}X. Exit script${RESET}" # added option X

  # Prompt the user to choose an interface
  read -p "Enter the number of the physical Wi-Fi adapter , 'R' to remove or 'X' to exit: " selected_interface_num

  # Validate the user input
  if [[ "$selected_interface_num" == "R" || "$selected_interface_num" == "r" ]]; then
    remove_all_virtual_interfaces
    continue # Continue to the beginning of the loop
  elif [[ "$selected_interface_num" == "X" || "$selected_interface_num" == "x" ]]; then # added option X
    echo -e "${RED}Exiting script.${RESET}"
    exit 0
  elif ! [[ "$selected_interface_num" -ge 1 && "$selected_interface_num" -le "${#wifi_interfaces[@]}" ]]; then
    echo -e "${RED}Invalid interface number. Please try again.${RESET}"
    continue # Continue to the beginning of the loop
  fi

  # Get the selected interface name
  selected_interface_index=$((selected_interface_num - 1))
  BASE_INTERFACE="${wifi_interfaces[$selected_interface_index]}"

  # Check if the selected interface is a virtual interface
  if [[ "$BASE_INTERFACE" == "virt_"* ]]; then
    echo -e "${RED}Error: Virtual interface ${BLUE}$BASE_INTERFACE${RED} cannot be selected. Please choose a physical Wi-Fi interface.${RESET}"
    continue # Go back to the beginning of the loop
  fi

  echo -e "${GREEN}Using Wi-Fi interface: ${GREEN}$BASE_INTERFACE${RESET}"

  # Check if the base interface is up
  if ! ip link show "$BASE_INTERFACE" | grep -q "state UP"; then
    echo -e "${RED}Base interface ${GREEN}$BASE_INTERFACE${RED} is not up, attempting to bring it up...${RESET}"
    sudo ip link set "$BASE_INTERFACE" up
    if [ $? -ne 0 ]; then
      echo -e "${RED}Error: Failed to bring up interface ${GREEN}$BASE_INTERFACE${RED}.  Exiting.${RESET}"
      exit 1 # Exit the script if bringing up the interface fails
    else
      echo -e "${GREEN}Successfully brought up interface ${GREEN}$BASE_INTERFACE${RESET}"
    fi
  fi

  # Set the selected physical interface to monitor mode
  set_interface_to_monitor "$BASE_INTERFACE"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to set the physical interface ${GREEN}$BASE_INTERFACE${RED} to monitor mode. Exiting.${RESET}"
    exit 1 # Exit if setting monitor mode fails
  fi

  # Create one virtual interface
  num_vifs=1 # Specify the number of virtual interfaces you want to create
  for i in $(seq 1 $num_vifs); do
    next_vif_name=$(find_next_virtual_interface_name "$BASE_INTERFACE")
    echo -e "${GREEN}Created interface: ${CYAN}$next_vif_name ${RESET}"
    if [ -z "$next_vif_name" ]; then
      echo -e "${RED}Error: Could not determine next available virtual interface name.${RESET}"
      exit 1
    fi
    create_virtual_interface_and_set_monitor "$BASE_INTERFACE" "$next_vif_name" "managed"
    if [ $? -ne 0 ]; then
      echo -e "${RED}Error creating interface $next_vif_name.  Exiting.${RESET}"
      exit 1
    fi
  done
  airmon-ng
done #end loop
