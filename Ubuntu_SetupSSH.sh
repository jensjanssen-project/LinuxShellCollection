#!/bin/bash


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
