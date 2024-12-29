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

wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu2404_VNC.sh"
chmod +x Ubuntu2404_VNC.sh
sudo ./Ubuntu2404_VNC.sh

wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu2404_VirtualDisplay.sh"
chmod +x Ubuntu2404_VirtualDisplay.sh
sudo ./Ubuntu2404_VirtualDisplay.sh

wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu22_InstallDocker.sh"
chmod +x Ubuntu22_InstallDocker.sh
./Ubuntu22_InstallDocker.sh

# Install terminal program terminator
sudo apt install -y terminator

# Install Curl
sudo apt install -y curl

# Install Snap and Arduino CLI
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
echo 'export PATH=$PATH:~/bin' >> ~/.bashrc
source ~/.bashrc


echo "Setup completed successfully!"

echo "In next step we make a reboot, remove the display cable from the Pi"
read -n 1 -s -r -p "Press any key to continue..."
sudo reboot