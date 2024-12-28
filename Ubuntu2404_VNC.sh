#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: setup_x11vnc_virtual_display.sh
# Description: Automates the setup of x11vnc with a virtual display on Ubuntu 22.04
# Author: [Your Name]
# Date: [Current Date]
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e
	
apt update

echo "In next step select lightdm as default display Manager"
read -n 1 -s -r -p "Press any key to continue..."
apt install -y lightdm

# 4. Disable GDM3 and Enable LightDM
echo "Disabling GDM3 and enabling LightDM..."
systemctl disable gdm3
systemctl enable lightdm

# 5. Restart the Display Manager to Apply Changes
# This switches the display manager without rebooting
echo "Restarting LightDM to apply changes..."
# Stop GDM3 if it's running
systemctl stop gdm3 || true
# Start LightDM
systemctl start lightdm

# Give some time for LightDM to start properly
sleep 5


apt install -y x11vnc

#x11vnc -usepw
#ExecStart=/usr/bin/x11vnc -forever -display :0 -auth guess -passwdfile /home/$SUDO_USER/.vnc/passwd

echo "Configuring x11vnc systemd service..."
cat <<EOF > /lib/systemd/system/x11vnc.service
[Unit]
Description=x11vnc service
After=display-manager.service network.target syslog.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -forever -display :0 -auth guess -passwd my-password
ExecStop=/usr/bin/killall x11vnc
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable x11vnc.service
systemctl start x11vnc.service

ufw allow 5900/tcp
ufw reload