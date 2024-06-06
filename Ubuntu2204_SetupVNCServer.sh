#!/bin/bash

# Update package list and install GNOME desktop environment and TigerVNC server
sudo apt update
sudo apt install -y ubuntu-desktop gnome-shell tigervnc-standalone-server gnome-session gnome-terminal gnome-panel gnome-settings-daemon metacity nautilus xfce4 xfce4-goodies

# Set VNC password
echo "Setting VNC password..."
mkdir -p ~/.vnc
echo -e "pid914511\npid914511\nn" | vncpasswd

# Create VNC startup script
cat << 'EOF' > ~/.vnc/xstartup
#!/bin/bash
xrdb $HOME/.Xresources
dbus-launch --exit-with-session gnome-session &
EOF

# Make the xstartup script executable
chmod +x ~/.vnc/xstartup

# Create systemd service file for VNC server
sudo bash -c 'cat <<EOF > /etc/systemd/system/vncserver@.service
[Unit]
Description=Start VNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=pid
Group=pid
PAMName=login
Environment=HOME=/home/pid
Environment=USER=pid
Environment=XDG_RUNTIME_DIR=/run/user/%U
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1 || :
ExecStart=/usr/bin/vncserver -geometry 1920x1080 -depth 24 -localhost :%i
ExecStop=/usr/bin/vncserver -kill :%i
PIDFile=/home/pid/.vnc/%H%i.pid

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd daemon to read the new service file
sudo systemctl daemon-reload

# Enable and start the VNC server service
sudo systemctl enable vncserver@1.service
sudo systemctl start vncserver@1.service

echo "VNC server setup complete. You can connect to it using a VNC viewer on port 5901 (display :1)."