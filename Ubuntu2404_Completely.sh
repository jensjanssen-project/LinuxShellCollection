#!/bin/bash



echo "Ubuntu Setup SSH"
wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu_SetupSSH.sh"
chmod +x Ubuntu_SetupSSH.sh
sudo ./Ubuntu_SetupSSH.sh

echo "Ubuntu 22 Install Docker engine"
wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubuntu22_InstallDocker.sh"
chmod +x Ubuntu22_InstallDocker.sh
sudo ./Ubuntu22_InstallDocker.sh

echo "Ubuntu 24.04 Install VNC Server and Virtual Display"
wget "https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Ubunut2404_SetupVNC_VirtDisplay.sh"
chmod +x Ubunut2404_SetupVNC_VirtDisplay.sh
sudo ./Ubunut2404_SetupVNC_VirtDisplay.sh

