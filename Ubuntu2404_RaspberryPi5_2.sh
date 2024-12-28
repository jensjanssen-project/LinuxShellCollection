#!/bin/bash

# Script Name: setup_complete.sh
# Description: Installs SSH (optional), sets up various services, and ensures the script
#              continues execution after a system reboot.


# Function to setup systemd service for post-reboot execution
setup_post_reboot() {
    # Create a systemd service file
    sudo tee /etc/systemd/system/setup_complete_post_reboot.service > /dev/null <<EOF
[Unit]
Description=Resume Setup Script After Reboot
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash $(realpath "$0") --post-reboot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to recognize the new service
    sudo systemctl daemon-reload

    # Enable the service to run at boot
    sudo systemctl enable setup_complete_post_reboot.service
}

# Function to cleanup the systemd service after post-reboot execution
cleanup_post_reboot() {
    sudo systemctl disable setup_complete_post_reboot.service
    sudo rm -f /etc/systemd/system/setup_complete_post_reboot.service
    sudo systemctl daemon-reload
}

# Main script logic
if [[ "$1" != "--post-reboot" ]]; then
    # Initial Execution


	echo "Setting up SSH..."
	wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu_SetupSSH.sh" -O Ubuntu_SetupSSH.sh
	chmod +x Ubuntu_SetupSSH.sh
	sudo ./Ubuntu_SetupSSH.sh

	# Setup post-reboot execution
	echo "Setting up script to resume after reboot..."
	setup_post_reboot

	echo "Rebooting the system to continue setup..."
	sudo reboot

else
    # Post-Reboot Execution

    echo "Resuming setup after reboot..."

    # Proceed with remaining setup steps
    wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu2404_X11Enable.sh" -O Ubuntu2404_X11Enable.sh
    chmod +x Ubuntu2404_X11Enable.sh
    sudo ./Ubuntu2404_X11Enable.sh

    wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu2404_VNC.sh" -O Ubuntu2404_VNC.sh
    chmod +x Ubuntu2404_VNC.sh
    sudo ./Ubuntu2404_VNC.sh

    wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu2404_VirtualDisplay.sh" -O Ubuntu2404_VirtualDisplay.sh
    chmod +x Ubuntu2404_VirtualDisplay.sh
    sudo ./Ubuntu2404_VirtualDisplay.sh

    wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu22_InstallDocker.sh" -O Ubuntu22_InstallDocker.sh
    chmod +x Ubuntu22_InstallDocker.sh
    sudo ./Ubuntu22_InstallDocker.sh

    echo "Setup completed successfully!"

    # Cleanup the systemd service
    cleanup_post_reboot

    # Optionally, reboot again or exit
    # Uncomment the following line if you want to reboot after setup completion
    # sudo reboot
fi