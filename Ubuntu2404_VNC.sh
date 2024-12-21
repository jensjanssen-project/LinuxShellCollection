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
apt install -y lightdm
# reboot
apt install -y x11vnc

x11vnc -usepw

echo "Configuring x11vnc systemd service..."
cat <<EOF > /lib/systemd/system/x11vnc.service
[Unit]
Description=x11vnc service
After=display-manager.service network.target syslog.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -forever -display :0 -auth guess -passwdfile /home/$SUDO_USER/.vnc/passwd
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