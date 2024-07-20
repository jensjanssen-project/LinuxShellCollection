
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

    echo "Applying sysctl changes..."
    sudo sysctl -p

    echo "Determining Ethernet interface name..."
    ETH_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')

    echo "Setting up iptables for NAT..."
    sudo iptables -t nat -A POSTROUTING -o "$ETH_INTERFACE" -j MASQUERADE

    echo "Installing iptables-persistent to save rules..."
    sudo apt-get update
    sudo apt-get install -y iptables-persistent netfilter-persistent

    echo "Saving iptables rules..."
    sudo netfilter-persistent save
    sudo netfilter-persistent reload

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
