#!/bin/bash

# Step 1: Install the Dummy Video Driver
sudo apt update
sudo apt install -y xserver-xorg-video-dummy

# Step 2: Configure Xorg for the Virtual Display
sudo mkdir -p /etc/X11/xorg.conf.d/

sudo tee /etc/X11/xorg.conf.d/10-dummy.conf > /dev/null <<EOL
Section "Device"
    Identifier "DummyDevice"
    Driver "dummy"
    VideoRam 256000
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

# Step 3: Restart the Display Manager
# Detect the current display manager
DM_SERVICE=$(basename "$(readlink /etc/systemd/system/display-manager.service)")

if [ -n "$DM_SERVICE" ]; then
    sudo systemctl restart "$DM_SERVICE"
    echo "Restarted display manager: $DM_SERVICE"
else
    echo "Display manager not detected. Please restart your system manually."
fi