#!/bin/bash

# Enable IP forwarding
echo "Enabling IP forwarding..."
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Apply the changes
echo "Applying sysctl changes..."
sudo sysctl -p

# Get the Ethernet interface name
echo "Determining Ethernet interface name..."
ETH_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')

# Set up iptables for NAT
echo "Setting up iptables for NAT..."
sudo iptables -t nat -A POSTROUTING -o "$ETH_INTERFACE" -j MASQUERADE

# Install iptables-persistent to save iptables rules
echo "Installing iptables-persistent to save rules..."
sudo apt-get update
sudo apt-get install -y iptables-persistent netfilter-persistent

# Save the iptables rules
echo "Saving iptables rules..."
sudo netfilter-persistent save
sudo netfilter-persistent reload

echo "Setup complete."
