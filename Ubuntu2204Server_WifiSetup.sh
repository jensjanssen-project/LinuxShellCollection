#!/bin/bash

# Function to list available WiFi interfaces
list_wifi_interfaces() {
    iw dev | awk '$1=="Interface"{print $2}'
}

# Get available WiFi interfaces
interfaces=($(list_wifi_interfaces))

# Check if there are any WiFi interfaces available
if [ ${#interfaces[@]} -eq 0 ]; then
    echo "No WiFi interfaces found. Exiting."
    exit 1
fi

# Prompt user to select an interface if more than one is available
if [ ${#interfaces[@]} -eq 1 ]; then
    INTERFACE=${interfaces[0]}
    echo "Only one interface found: $INTERFACE"
else
    echo "Available WiFi interfaces:"
    for i in "${!interfaces[@]}"; do
        echo "$i) ${interfaces[$i]}"
    done
    read -p "Select an interface by number: " interface_index
    INTERFACE=${interfaces[$interface_index]}
fi

# Ask for user input for SSID and password
read -p "Enter the SSID of the WiFi network: " SSID
read -sp "Enter the password for the WiFi network: " PASSWORD
echo

# Check if NetworkManager is installed
if ! command -v nmcli &> /dev/null
then
    echo "nmcli (NetworkManager) could not be found. Installing NetworkManager..."
    sudo apt update
    sudo apt install -y network-manager
fi

# Enable the WiFi interface
echo "Enabling the WiFi interface: $INTERFACE"
sudo nmcli radio wifi on

# Connect to the WiFi network
echo "Connecting to the WiFi network: $SSID"
sudo nmcli dev wifi connect "$SSID" password "$PASSWORD" ifname "$INTERFACE"

# Check if the device is connected
if nmcli -t -f active,ssid dev wifi | grep -q "^yes:$SSID$"
then
    echo "Successfully connected to the WiFi network: $SSID"
else
    echo "Failed to connect to the WiFi network: $SSID"
    exit 1
fi