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


wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu2404_X11Enable.sh"
chmod +x Ubuntu2404_X11Enable.sh
sudo ./Ubuntu2404_X11Enable.sh


wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu22_InstallDocker.sh"
chmod +x Ubuntu22_InstallDocker.sh
./Ubuntu22_InstallDocker.sh


wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu2204_RDP.sh"
chmod +x Ubuntu2204_RDP.sh
./Ubuntu2204_RDP.sh


# Allow necessary ports (HTTP and HTTPS)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow communication for Ros/plc/NodeRobotic
sudo ufw allow 1000:60000/tcp
sudo ufw allow 1000:60000/udp


# Accept all incoming TCP traffic
sudo iptables -A INPUT -p tcp -j ACCEPT

# Accept all incoming UDP traffic
sudo iptables -A INPUT -p udp -j ACCEPT

# Save the rules
sudo iptables-save

# Install net-tools
sudo apt install -y net-tools

# Install terminal program terminator
sudo apt install -y terminator

# Install Curl
sudo apt install -y curl

# install MidnigthCommander
sudo apt install -y mc

echo "Setup completed successfully!"

echo "In next step we make a reboot, remove the display cable from the Pi"
read -n 1 -s -r -p "Press any key to continue..."
sudo reboot