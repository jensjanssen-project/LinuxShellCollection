#!/bin/bash

# Allow necessary ports (HTTP and HTTPS)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow communication for Ros/plc/NodeRobotic
sudo ufw allow 1000:60000/tcp
sudo ufw allow 1000:60000/udp

sudo iptables -A INPUT -p tcp --dport 5000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5005 -j ACCEPT
sudo iptables-save

# Ensure IP forwarding is enabled in UFW configuration
UFW_CONFIG_FILE="/etc/default/ufw"
if grep -q "^DEFAULT_FORWARD_POLICY" $UFW_CONFIG_FILE; then
    sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' $UFW_CONFIG_FILE
else
    echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' | sudo tee -a $UFW_CONFIG_FILE
fi

# Add forwarding rules in UFW before.rules (if needed)
#UFW_BEFORE_RULES="/etc/ufw/before.rules"
#if ! grep -q "*nat" $UFW_BEFORE_RULES; then
#    echo "*nat" | sudo tee -a $UFW_BEFORE_RULES
#    echo ":POSTROUTING ACCEPT [0:0]" | sudo tee -a $UFW_BEFORE_RULES
#    echo "-A POSTROUTING -o eth0 -j MASQUERADE" | sudo tee -a $UFW_BEFORE_RULES
#    echo "COMMIT" | sudo tee -a $UFW_BEFORE_RULES
#fi

# Reload UFW to apply changes
sudo ufw reload


sudo apt install ros-iron-slam-toolbox

sudo apt install ros-iron-navigation2
sudo apt install ros-iron-nav2-bringup



#Per hand
#sudo systemctl edit NODE_ROBOT_AUTONOMY@pid.service
#sudo systemctl daemon-reload
#sudo systemctl enable NODE_ROBOT_AUTONOMY@"${USER}".service
 
#sudo systemctl restart NODE_ROBOT_AUTONOMY@"${USER}".service
 

