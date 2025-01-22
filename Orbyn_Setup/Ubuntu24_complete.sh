#!/bin/bash


# Function to prompt the user for input
ask_for_installation() {
    echo "Do you want to install and setup SSH? (yes/no) [default: no]"
    read -r user_input
    user_input=${user_input:-no}

    if [[ "$user_input" == "yes" ]]; then
        return 0  # Return 0 for success
    else
        return 1  # Return 1 for failure
    fi
}

# Main script logic
if ask_for_installation; then
    # Setup & enable SSH
	wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu_SetupSSH.sh"
	chmod +x Ubuntu_SetupSSH.sh
	sudo ./Ubuntu_SetupSSH.sh
	
	echo "In next step we make a reboot, execute the file again only over SSH!"
	read -n 1 -s -r -p "Press any key to continue..."
	sudo reboot
else
    echo "SSH setup aborted."
fi




setup_ethernet_port(){
##### Setup IP of ethernet ports #####
# Create the netplan configuration
cat > /etc/netplan/00-installer-config.yaml << 'EOL'
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:
      addresses:
        - 192.168.137.100/24
      routes:
        - to: default
          via: 192.168.137.1
        - to: 172.31.254.2/32
          via: 192.168.137.1
        - to: 172.31.254.3/32
          via: 192.168.137.1		  
EOL

# Set correct ownership and permissions
chown root:root /etc/netplan/00-installer-config.yaml
chmod 600 /etc/netplan/00-installer-config.yaml

# Apply the configuration
netplan apply

echo "Static IP configuration complete!"
}

enable_x11(){
	# Exit immediately if a command exits with a non-zero status
	set -e

	echo "✋ Disabling Wayland in GDM3..."

	if [ -f /etc/gdm3/custom.conf ]; then
		# Check if WaylandEnable is already set to false
		if grep -q "^WaylandEnable=false" /etc/gdm3/custom.conf; then
			echo "✅ Wayland is already disabled in GDM3."
		else
			# Uncomment the WaylandEnable=false line if it's commented
			sed -i 's/^#\s*WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf

			# If WaylandEnable=false was not found, append it
			if ! grep -q "^WaylandEnable=false" /etc/gdm3/custom.conf; then
				echo "WaylandEnable=false" >> /etc/gdm3/custom.conf
			fi

			echo "✅ Wayland has been disabled in GDM3."
		fi
	else
		echo "⚠️ /etc/gdm3/custom.conf does not exist. Skipping Wayland disable."
	fi

	systemctl restart gdm3
}

install_docker(){
	# Add Docker's official GPG key:
	sudo apt-get update
	sudo apt-get install -y ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
	  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update

	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

	# Add the current user to the docker group
	sudo usermod -aG docker $USER

	# Restart the Docker daemon
	sudo systemctl restart docker

	# Note: The following command will only affect the current script session
	# The user will still need to log out and back in for the changes
	# to take effect in their terminal
	newgrp docker
}

install_xrdp(){
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
    #sudo ufw allow 3389/tcp

    echo "XRDP setup complete."
}

setup_iptables(){
	# Accept all incoming TCP traffic
	sudo iptables -A INPUT -p tcp -j ACCEPT

	# Accept all incoming UDP traffic
	sudo iptables -A INPUT -p udp -j ACCEPT

	# Save the rules
	sudo iptables-save
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

install_tools(){
	# Install net-tools
	sudo apt install -y net-tools

	# Install terminal program terminator
	sudo apt install -y terminator

	# Install Curl
	sudo apt install -y curl

	# install MidnigthCommander
	sudo apt install -y mc
}

generate_ssh(){
	##### Generate SSH key #####
	echo "Setting up SSH key..."

	# Create .ssh directory if it doesn't exist and set proper permissions
	mkdir -p ~/.ssh
	chmod 700 ~/.ssh

	# Generate ed25519 key without prompts and without passphrase
	ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q

	# Add to authorized_keys and set proper permissions
	cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
	chmod 600 ~/.ssh/authorized_keys

	echo "SSH key setup complete!"
	echo "Your key is:"
	cat ~/.ssh/id_ed25519
}




setup_ethernet_port
enable_x11
install_docker
install_xrdp
setup_iptables
setup_nat
install_tools
generate_ssh

echo "Setup completed successfully!"

echo "In next step we make a reboot"
read -n 1 -s -r -p "Press any key to continue..."
sudo reboot