# This project started with making small bash script to switch WiFi into monitor mode and now with big help of AI i/we made one that do that and making Virtual wifi interface/s when more is needed but you have only one . 
#  README.md is  made by AI with some edits by me .
# Tested on Debian , 6.10.11 .
**************************************************************************************************************************************


# Virtual WiFi Interface Creator and Monitor Mode Enabler

## Description

This script is a Bash script designed for Linux systems to create virtual Wi-Fi interfaces from a physical Wi-Fi adapter and set the virtual interface into monitor mode.  It also handles the necessary steps to ensure that conflicting processes (like `NetworkManager` and `wpa_supplicant`) do not interfere with the process.

Name of virtual wifi interface are generated like wlan0 to virt_wlan00 , virt_wlan01 , virt_wlan02 etc.  (wlan1 to virt_wlan10...) .
Option "R. Remove all Virtual Wi-Fi interfaces"  do what it says, remove all Virtual devices that are made .
It runs "airmon-ng check kill" i needed it for my project that this script are used and i had issues while physical device are in managed mode . 

### Scroll down to see pistures of bash scrip running. 
**************************************************************************************************************************************


## Features

* Requires root privileges to run.
* Creates a virtual Wi-Fi interface on top of an existing physical Wi-Fi interface.
* Sets the created virtual interface to monitor mode.
* Checks for conflicting processes (`NetworkManager`, `wpa_supplicant`) and terminates them using `airmon-ng`.
* Provides an option to remove all existing virtual Wi-Fi interfaces.


## Dependencies

The script relies on the following tools and utilities, which are commonly found on most Linux distributions:

* **bash:** The script is written in Bash.
* **iproute2:** Used for network interface management (`ip` command).
* **iw:** Used for configuring wireless interfaces.
* **iwconfig:** (May be required on some systems) Used to get a list of the wireless interfaces.
* **airmon-ng:** Part of the Aircrack-ng suite, used to manage wireless interfaces and handle conflicting processes.

### Installation

1.  **Aircrack-ng Suite:**

    * Debian/Ubuntu:
        ```bash
        sudo apt-get update
        sudo apt-get install aircrack-ng
        ```
    * Fedora/CentOS/RHEL:
        ```bash
        sudo dnf install aircrack-ng
        ```
    * Arch Linux:
        ```bash
        sudo pacman -S aircrack-ng
        ```

2.  **Other dependencies**

    * Debian/Ubuntu:
        ```bash
        sudo apt-get update
        sudo apt-get install iproute2 iw iwconfig #iwconfig may already be installed
        ```
     * Fedora/CentOS/RHEL:
        ```bash
        sudo dnf install iproute2 iw wireless-tools #wireless-tools provides iwconfig
        ```
     * Arch Linux:
        ```bash
        sudo pacman -S iproute2 iw  # iwconfig is often not needed on Arch
        ```

## Usage

1.  Clone the repository:
    ```bash
    git clone https://github.com/CoWsysNoot/virtualWiFiinterface.git
    ```
2.  CD to virtualWiFiinterface folder
    ```bash
    cd virtualWiFiinterface
    ```
4.  Make the script executable:
    ```bash
    chmod +x virtualWiFiinterface.sh
    ```

5.  Run the script as root:
    ```bash
    sudo ./virtualWiFiinterface.sh
    ```

6.  Follow instructions to select a Wi-Fi interface or remove all existing virtual interfaces.

## Script Operation

1.  The script checks if it is being run with root privileges. If not, it exits.
2.  It identifies the available Wi-Fi interfaces using `iwconfig`.
3.  It displays a list of available Wi-Fi interfaces and prompts the user to select one.
4.  The script provides an option to remove all existing virtual Wi-Fi interfaces before proceeding.
5.  It uses `airmon-ng` to check for conflicting processes (like `NetworkManager` and `wpa_supplicant`) and terminates them.
6.  It sets the selected physical Wi-Fi interface to monitor mode using `airmon-ng`.
7.  It creates a virtual Wi-Fi interface using `iw`.
8.  It sets the virtual interface to monitor mode using `ip link` and `iw`.
9.  It displays the name of the created virtual interface.

**************************************************************************************************************************************
# Pictures


## bash script running:
![Alt Text](https://iili.io/3VC2EMP.png)

##  wirtual interfaces active:
![Alt Text](https://iili.io/3VCB8il.png)

##  "iwconfig" results:
![Alt Text](https://iili.io/3VCKznp.png)
