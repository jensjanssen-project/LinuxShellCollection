#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: setup_x11vnc_virtual_display.sh
# Description: Automates the setup of x11vnc with a virtual display on Ubuntu 22.04
# Author: [Your Name]
# Date: [Current Date]
# -----------------------------------------------------------------------------

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
	
#systemctl restart gdm3
	
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