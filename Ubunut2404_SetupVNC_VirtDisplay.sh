#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: setup_x11vnc_virtual_display.sh
# Description: Automates the setup of x11vnc with a virtual display on Ubuntu 22.04
# Author: [Your Name]
# Date: [Current Date]
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
VNC_PASSWORD_FILE="$HOME/.vnc/passwd"
SERVICE_FILE="/lib/systemd/system/x11vnc.service"
XORG_CONFIG_DIR="/etc/X11/xorg.conf.d"
DUMMY_CONF_FILE="$XORG_CONFIG_DIR/10-dummy.conf"
DISPLAY_MANAGER="lightdm"
VNC_PORT=5900
RESOLUTION="1920x1080"

# Function: Check if the script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ This script must be run as root. Use sudo ./setup_x11vnc_virtual_display.sh"
        exit 1
    fi
}

# Function: Update and upgrade the system
system_update() {
    echo "🔄 Updating package lists..."
    apt update -y

    echo "🔄 Upgrading existing packages..."
    apt upgrade -y
}

# Function: Install required packages
install_packages() {
    echo "📦 Installing required packages: lightdm, x11vnc, xserver-xorg-video-dummy, ufw..."
    apt install -y lightdm x11vnc xserver-xorg-video-dummy ufw
}

# Function: Configure lightdm as the default display manager
configure_display_manager() {
    echo "⚙️ Configuring $DISPLAY_MANAGER as the default display manager..."

    # Suppress the interactive prompt by pre-selecting lightdm
    echo "lightdm lightdm/select-default boolean true" | debconf-set-selections
    echo "lightdm lightdm/reconfigure-always boolean false" | debconf-set-selections

    dpkg-reconfigure lightdm -f noninteractive

    echo "✅ $DISPLAY_MANAGER has been set as the default display manager."
}

# Function: Create Xorg dummy configuration
setup_virtual_display() {
    echo "🖥️ Setting up virtual display using Dummy Video Driver..."

    # Create the configuration directory if it doesn't exist
    mkdir -p "$XORG_CONFIG_DIR"

    # Backup existing dummy configuration if it exists
    if [ -f "$DUMMY_CONF_FILE" ]; then
        echo "📂 Backing up existing dummy Xorg configuration to 10-dummy.conf.bak"
        cp "$DUMMY_CONF_FILE" "${DUMMY_CONF_FILE}.bak"
    fi

    # Create the dummy Xorg configuration file
    cat > "$DUMMY_CONF_FILE" <<EOL
Section "Device"
    Identifier "DummyDevice"
    Driver "dummy"
    VideoRam 256000
EndSection

Section "Monitor"
    Identifier "DummyMonitor"
    HorizSync 28.0-80.0
    VertRefresh 48.0-75.0
    Modeline "$(cvt $(echo $RESOLUTION | cut -dx -f1) $(echo $RESOLUTION | cut -dx -f2) | grep -oP '(?<=Modeline ")[^"]+')"
    Option "PreferredMode" "$RESOLUTION"
EndSection

Section "Screen"
    Identifier "DummyScreen"
    Monitor "DummyMonitor"
    Device "DummyDevice"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "$RESOLUTION"
    EndSubSection
EndSection

Section "ServerLayout"
    Identifier "Layout0"
    Screen "DummyScreen" 0 0
EndSection
EOL

    echo "✅ Dummy Xorg configuration created at $DUMMY_CONF_FILE"
}

# Function: Generate VNC password
setup_vnc_password() {
    echo "🔒 Setting up VNC password..."

    # Install 'expect' if it's not already installed (for automating password input)
    if ! command -v expect &> /dev/null; then
        echo "📦 Installing 'expect' for automating VNC password setup..."
        apt install -y expect
    fi

    # Check if password file already exists
    if [ -f "$VNC_PASSWORD_FILE" ]; then
        echo "✅ VNC password file already exists at $VNC_PASSWORD_FILE"
    else
        # Prompt the user for a VNC password
        read -sp "Enter a password for VNC: " VNC_PASS
        echo
        read -sp "Confirm the password: " VNC_PASS_CONFIRM
        echo

        if [ "$VNC_PASS" != "$VNC_PASS_CONFIRM" ]; then
            echo "❌ Passwords do not match. Exiting."
            exit 1
        fi

        # Create the .vnc directory if it doesn't exist
        mkdir -p "$(dirname "$VNC_PASSWORD_FILE")"

        # Use x11vnc to store the password
        # Utilize 'expect' to automate the password input
        /usr/bin/x11vnc -storepasswd "$VNC_PASS" "$VNC_PASSWORD_FILE"

        echo "✅ VNC password has been set and stored securely."
    fi
}

# Function: Create and configure x11vnc systemd service
setup_x11vnc_service() {
    echo "🛠️ Creating x11vnc systemd service..."

    # Backup existing service file if it exists
    if [ -f "$SERVICE_FILE" ]; then
        echo "📂 Backing up existing x11vnc service file to x11vnc.service.bak"
        cp "$SERVICE_FILE" "${SERVICE_FILE}.bak"
    fi

    # Create the x11vnc.service file
    cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=x11vnc service
After=display-manager.service network.target syslog.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -forever -usepw -display :0 -auth guess
ExecStop=/usr/bin/killall x11vnc
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    echo "✅ x11vnc systemd service file created at $SERVICE_FILE"
}

# Function: Enable and start x11vnc service
enable_start_service() {
    echo "🚀 Enabling and starting x11vnc service..."

    # Reload systemd daemon to recognize the new service
    systemctl daemon-reload

    # Enable the service to start on boot
    systemctl enable x11vnc.service

    # Start the service
    systemctl start x11vnc.service

    echo "✅ x11vnc service is enabled and started."
}

# Function: Configure UFW firewall
configure_firewall() {
    echo "🛡️ Configuring UFW firewall to allow VNC connections on port $VNC_PORT/tcp..."

    # Allow VNC port
    ufw allow "$VNC_PORT/tcp"

    # Reload UFW to apply changes
    ufw reload

    echo "✅ Firewall configured to allow VNC connections."
}

# Function: Restart display manager to apply Xorg configurations
restart_display_manager() {
    echo "🔄 Restarting $DISPLAY_MANAGER to apply changes..."

    systemctl restart "$DISPLAY_MANAGER"

    echo "✅ $DISPLAY_MANAGER has been restarted."
}

# Function: Final instructions
final_instructions() {
    echo "🎉 Setup Complete!"
    echo "----------------------------------------"
    echo "• x11vnc has been installed and configured."
    echo "• A virtual display has been set up using the Dummy Video Driver."
    echo "• VNC is accessible on port $VNC_PORT."
    echo "• You can connect using any VNC client with the set password."
    echo ""
    echo "To verify the x11vnc service status, you can run:"
    echo "  sudo systemctl status x11vnc.service"
    echo ""
    echo "If you encounter any issues, check the system logs using:"
    echo "  sudo journalctl -u x11vnc.service"
    echo "----------------------------------------"
}

# Main execution flow
main() {
    check_root
    system_update
    install_packages
    configure_display_manager
    setup_virtual_display
    setup_vnc_password
    setup_x11vnc_service
    configure_firewall
    enable_start_service
    restart_display_manager
    final_instructions
}

# Execute the main function
main