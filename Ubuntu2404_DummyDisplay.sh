#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Function to print messages
echo_msg() {
    echo "========================================================"
    echo "$1"
    echo "========================================================"
}

# Ensure the script is run with sudo or as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo or as root" 
   exit 1
fi

# Step 1: Install the Dummy Video Driver
echo_msg "Step 1: Updating package list and installing xserver-xorg-video-dummy..."
apt update
apt install -y xserver-xorg-video-dummy

# Step 2: Create a Separate Xorg Configuration for Display :1
echo_msg "Step 2: Creating Xorg configuration for the dummy display on :1..."

# Define the Xorg configuration for the dummy display
tee /etc/dummy-xorg.conf > /dev/null <<EOL
Section "Device"
    Identifier "DummyDevice"
    Driver "dummy"
    VideoRam 256000
    Option "IgnoreEDID" "true"
EndSection

Section "Monitor"
    Identifier "DummyMonitor"
    HorizSync 28.0-80.0
    VertRefresh 48.0-75.0
    Modeline "1920x1080" 148.50 1920 2008 2052 2200 1080 1084 1089 1125
    Option "PreferredMode" "1920x1080"
EndSection

Section "Screen"
    Identifier "DummyScreen"
    Monitor "DummyMonitor"
    Device "DummyDevice"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080"
    EndSubSection
EndSection

Section "ServerLayout"
    Identifier "DummyLayout"
    Screen "DummyScreen"
EndSection
EOL

# Step 3: Create a Systemd Service to Launch the Dummy X Server on :1
echo_msg "Step 3: Creating systemd service for the dummy X Server on display :1..."

# Get the original logged-in username
USER_NAME=$(logname)

# Create the systemd service file
tee /etc/systemd/system/dummy-xserver.service > /dev/null <<EOL
[Unit]
Description=Dummy X Server on :1
After=display-manager.service network.target

[Service]
User=${USER_NAME}
ExecStart=/usr/bin/X :1 -config /etc/dummy-xorg.conf -nolisten tcp
Restart=always
Environment=DISPLAY=:1

[Install]
WantedBy=multi-user.target
EOL

# Step 4: Reload systemd, Enable, and Start the Dummy X Server Service
echo_msg "Step 4: Reloading systemd daemon, enabling, and starting the dummy X Server service..."
systemctl daemon-reload
systemctl enable dummy-xserver.service
systemctl start dummy-xserver.service

# Step 5: Verification
echo_msg "Step 5: Verifying the Dummy X Server setup..."

# Check if the service is active
if systemctl is-active --quiet dummy-xserver.service; then
    echo "✅ Dummy X Server is running on display :1."
else
    echo "❌ Failed to start the Dummy X Server. Please check the service logs."
    exit 1
fi

# Optional: Display instructions for testing the dummy display
echo_msg "Setup Complete"
echo "To test the dummy display, you can set the DISPLAY environment variable to :1 and run a graphical application."
echo "For example:"
echo "    DISPLAY=:1 xeyes &"
echo "Note: Since it's a dummy display, you won't see the application visually, but it should run without errors."