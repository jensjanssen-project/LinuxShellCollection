#!/bin/bash

# Get the Docker network interface name (e.g., docker0)
DOCKER_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep '^docker')

# Check if the Docker interface was found
if [ -z "$DOCKER_INTERFACE" ]; then
    echo "Docker network interface not found."
    exit 1
fi

echo "Docker network interface found: $DOCKER_INTERFACE"

# Get the subnet associated with the Docker interface
DOCKER_SUBNET=$(ip -o -f inet addr show "$DOCKER_INTERFACE" | awk '{print $4}')

# Check if the Docker subnet was found
if [ -z "$DOCKER_SUBNET" ]; then
    echo "Docker subnet not found."
    exit 1
fi

echo "Docker subnet is: $DOCKER_SUBNET"

# Add the UFW rule to allow traffic from the Docker subnet
echo "Adding UFW rule to allow traffic from $DOCKER_SUBNET"
sudo ufw allow from "$DOCKER_SUBNET"

# Reload UFW to apply changes
echo "Reloading UFW to apply changes..."
sudo ufw reload

echo "UFW has been updated to allow traffic from the Docker subnet."