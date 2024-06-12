#!/bin/bash

WORKING_DIR=$(pwd)

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
    echo "Setting up SSH..."
    sudo apt update
    sudo apt install -y openssh-server
    sudo systemctl enable ssh
    sudo systemctl start ssh
    sudo ufw allow ssh
    sudo ufw enable
    sudo ufw status
    echo "SSH setup complete."
else
    echo "SSH setup aborted."
fi


# Function to modify /etc/apt/sources.list to replace amd64 with arm64
modify_sources_list() {
    sudo sed -i 's/amd64/arm64/g' /etc/apt/sources.list
}

# Modify architecture in sources.list
#modify_sources_list


# Update and upgrade the system
sudo apt update
sudo apt upgrade -y


# Install necessary dependencies for ROS2
sudo apt install -y software-properties-common
sudo add-apt-repository universe
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# Add ROS2 repository to the sources list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Update and upgrade the system
sudo apt update
sudo apt upgrade -y

# Install ROS2 Humble Desktop and ROS Development Tools
sudo apt install -y ros-humble-desktop ros-dev-tools
sudo apt install -y python3-colcon-common-extensions

# Source the ROS2 environment setup script in .bashrc
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc

# Source the .bashrc file to apply changes
source ~/.bashrc

# Clone the ctrlx-automation-sdk-ros2 repository
cd ~
git clone https://github.com/boschrexroth/ctrlx-automation-sdk-ros2


# Update and upgrade the system
sudo apt update
sudo apt upgrade -y

# Change to work directory
cd ~

# Clone and install SDK
sudo chmod +x ${WORKING_DIR}/ctrlX_SDK/clone-install-sdk.sh
${WORKING_DIR}/ctrlX_SDK/clone-install-sdk.sh

#wget "https://github.com/boschrexroth/ctrlx-automation-sdk/releases/download/2.6.0/ctrlx-automation-sdk-2.6.0.zip"
#unzip ctrlx-automation-sdk-2.6.0.zip -d ~
#cd ~/ctrlx-automation-sdk/scripts

# Download and execute install-required-packages.sh
#wget https://raw.githubusercontent.com/boschrexroth/ctrlx-automation-sdk/main/scripts/install-required-packages.sh
#chmod a+x install-required-packages.sh
#./install-required-packages.sh

# Download and execute install-snapcraft.sh
#wget https://raw.githubusercontent.com/boschrexroth/ctrlx-automation-sdk/main/scripts/install-snapcraft.sh
#chmod a+x install-snapcraft.sh
#./install-snapcraft.sh

# Download and execute clone-install-sdk.sh
#wget https://raw.githubusercontent.com/boschrexroth/ctrlx-automation-sdk/main/scripts/clone-install-sdk.sh
#chmod a+x clone-install-sdk.sh
#./clone-install-sdk.sh

cd ~

echo "Setup completed successfully!"