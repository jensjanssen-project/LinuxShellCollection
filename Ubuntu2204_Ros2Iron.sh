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



# Install ROS2 Iron Desktop and ROS Development Tools
sudo apt install -y ros-iron-desktop ros-dev-tools ros-iron-rmw-cyclonedds-cpp
sudo apt install -y ros-iron-ros2-control ros-iron-ros2-controllers ros-iron-control-msgs ros-iron-test-msgs 

sudo apt install -y python3-colcon-common-extensions

# Update and upgrade the system
sudo apt update
sudo apt upgrade -y

# install bootstrap tools
sudo apt-get update && apt-get install --no-install-recommends -y \
    build-essential \
    git \
    nano \
    iputils-ping \
    wget \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-rosdep \
    python3-vcstool \
    python3-pip \
	python3-flask \
	python3-werkzeug \
    && rm -rf /var/lib/apt/lists/*

sudo rosdep init && rosdep update --rosdistro jazzy

# install some more tools
sudo apt install ros-noetic-laser-proc
sudo apt install ros-iron-rosbridge-server
sudo apt install ros-iron-navigation2
sudo apt install ros-iron-nav2-bringup

pip install flask flask-socketio eventlet


# Update and upgrade the system
sudo apt update
sudo apt upgrade -y

# Change to work directory
cd ~

mkdir ros2_ws

# Source the ROS2 environment setup script in .bashrc
echo "source /opt/ros/iron/setup.bash" >> ~/.bashrc
echo "source ~/ros2_ws/install/setup.bash" >> ~/.bashrc

# Source the .bashrc file to apply changes
source ~/.bashrc

echo "Setup completed successfully!"