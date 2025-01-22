
sudo apt upgrade
sudo apt install xfce4 xfce4-goodies -y

sudo apt install xrdp -y
echo xfce4-session > ~/.xsession

#sudo nano /etc/xrdp/startwm.sh
##Find and comment out or remove the lines that start with test -x and then add the following line before the # Test for X session line:


##Code kopieren
#. ~/.xsession
##Ensure the script looks something like this:

##bash
##Code kopieren
###!/bin/sh
### Uncomment the following line to use xfce4 session
#. ~/.xsession

sudo systemctl enable xrdp
sudo systemctl start xrdp


sudo usermod -a -G ssl-cert xrdp


sudo systemctl restart xrdp

sudo ufw allow 3389/tcp


#!/bin/bash

# Function to update and upgrade the system
update_system() {
    echo "Updating and upgrading the system..."
    sudo apt update && sudo apt upgrade -y
}

# Function to install XFCE and XRDP
install_xfce_xrdp() {
    echo "Installing XFCE and XFCE goodies..."
    sudo apt install xfce4 xfce4-goodies -y

    echo "Installing XRDP..."
    sudo apt install xrdp -y

    echo "Setting XFCE4 as the default session for XRDP..."
    echo xfce4-session > ~/.xsession

    # Modify /etc/xrdp/startwm.sh
    echo "Modifying /etc/xrdp/startwm.sh..."
    sudo sed -i '/^test -x.*$/s/^/#/' /etc/xrdp/startwm.sh
    sudo sed -i '/^# Test for X session/i . ~/.xsession' /etc/xrdp/startwm.sh

    echo "Enabling and starting XRDP service..."
    sudo systemctl enable xrdp
    sudo systemctl start xrdp

    echo "Adding xrdp user to ssl-cert group..."
    sudo usermod -a -G ssl-cert xrdp

    echo "Restarting XRDP service..."
    sudo systemctl restart xrdp

    echo "Allowing XRDP through UFW..."
    sudo ufw allow 3389/tcp

    echo "XRDP setup complete."
}

# Function to enable IP forwarding and set up NAT
setup_nat() {
    echo "Enabling IP forwarding..."
    sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    echo "Applying sysctl changes..."
    sudo sysctl -p
    sudo echo 1 > /proc/sys/net/ipv4/ip_forward

    echo "Available network interfaces:"
    ip -br link show

    # Get all available interfaces
    AVAILABLE_ETH=$(ip -br link show | grep -E "en|eth" | awk '{print $1}')
    AVAILABLE_WLAN=$(ip -br link show | grep -E "wl" | awk '{print $1}')

    # Show available interfaces
    echo -e "\nAvailable Ethernet interfaces:"
    echo "$AVAILABLE_ETH"
    echo -e "\nAvailable Wireless interfaces:"
    echo "$AVAILABLE_WLAN"

    # Let user select or confirm interfaces
    echo -e "\nPlease enter the Ethernet interface name to use:"
    read -p "[$AVAILABLE_ETH]: " ETH_INTERFACE
    ETH_INTERFACE=${ETH_INTERFACE:-$AVAILABLE_ETH}

    echo -e "\nPlease enter the Wireless interface name to use:"
    read -p "[$AVAILABLE_WLAN]: " WLAN_INTERFACE
    WLAN_INTERFACE=${WLAN_INTERFACE:-$AVAILABLE_WLAN}

    # Confirm selections
    echo -e "\nUsing the following interfaces:"
    echo "Ethernet (External): $ETH_INTERFACE"
    echo "Wireless (Internal): $WLAN_INTERFACE"
    read -p "Continue? [Y/n] " confirm
    confirm=${confirm:-Y}
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Aborted by user"
        return 1
    fi

    echo "Clearing existing NAT rules..."
    sudo iptables -t nat -F POSTROUTING

    echo "Setting up iptables for NAT..."
    # Add NAT rule for external interface
    sudo iptables -t nat -A POSTROUTING -o "$ETH_INTERFACE" -j MASQUERADE

    # Add forwarding rules specifically for WLAN to Ethernet
    sudo iptables -A FORWARD -i "$WLAN_INTERFACE" -o "$ETH_INTERFACE" -j ACCEPT
    sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    echo "Installing iptables-persistent..."
    sudo apt-get update
    sudo apt-get install -y iptables-persistent netfilter-persistent

    echo "Saving iptables rules..."
    sudo netfilter-persistent save
    sudo netfilter-persistent reload

    echo "Verifying NAT setup..."
    echo "NAT rules:"
    sudo iptables -t nat -L -v -n
    echo "Forward rules:"
    sudo iptables -L FORWARD -v -n
    echo "IP forwarding status:"
    cat /proc/sys/net/ipv4/ip_forward

    echo "NAT setup complete."
}

# Main script execution
main() {
    update_system
    setup_nat
    install_xfce_xrdp
    echo "Setup complete."
}

main
