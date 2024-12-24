#!/bin/bash

# Exit on error
set -e

echo "Starting Wohnzimmer installation..."

# Function to check command success
check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed"
        exit 1
    fi
}

# Function to generate secure random password
generate_password() {
    tr -dc 'A-Za-z0-9!#$%&()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c 32
}

echo "Installing git..."
sudo apt install git -y
check_command "git installation"

# Clone repository
echo "Cloning Wohnzimmer repository..."
git clone https://github.com/OliBerlin/Wohnzimmer
cd Wohnzimmer
check_command "Repository clone"

# Generate MQTT password
MQTT_PASSWORD=$(generate_password)
echo "Generated MQTT password: $MQTT_PASSWORD"
echo "Please save this password for configuring Home Assistant!"

# Install prerequisites
echo "Installing prerequisites..."
sudo apt install -y apt-transport-https
check_command "apt-transport-https installation"

# Add repository keys
echo "Adding repository keys..."
curl -sSL https://dtcooper.github.io/raspotify/key.asc | sudo apt-key add -v -
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
check_command "Key addition"

# Add repositories
echo "Adding repositories to sources..."
echo 'deb https://dtcooper.github.io/raspotify raspotify main' | sudo tee /etc/apt/sources.list.d/raspotify.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
check_command "Repository addition"

# Update package lists
echo "Updating package lists..."
sudo apt update
check_command "Package list update"

# Install required packages
echo "Installing Raspotify and Docker..."
sudo apt install -y raspotify docker-ce docker-ce-cli containerd.io
check_command "Package installation"

# Configure Raspotify
echo "Configuring Raspotify..."
sudo sed -i 's/#LIBRESPOT_BITRATE="160"/LIBRESPOT_BITRATE="320"/' /etc/raspotify/conf
sudo sed -i 's/#DEVICE_NAME="raspotify"/DEVICE_NAME="Wohnzimmer"/' /etc/raspotify/conf
check_command "Raspotify configuration"

# Configure firmware settings
echo "Configuring firmware settings..."
# Remove console from cmdline.txt
sudo sed -i 's/console=serial0,115200//' /boot/firmware/cmdline.txt

# Update config.txt
sudo sed -i 's/dtparam=audio=on/dtparam=audio=off/' /boot/firmware/config.txt
if ! grep -q '^\[all\]' /boot/firmware/config.txt; then
    echo -e "\n[all]\nenable_uart=1" | sudo tee -a /boot/firmware/config.txt
else
    sudo sed -i 's/enable_uart=0/enable_uart=1/' /boot/firmware/config.txt
    if ! grep -q 'enable_uart=1' /boot/firmware/config.txt; then
        sudo sed -i '/^\[all\]/a enable_uart=1' /boot/firmware/config.txt
    fi
fi
check_command "Firmware configuration"

# Start Docker containers
echo "Starting Docker containers..."
cd docker
sudo docker compose up -d
check_command "Docker startup"

echo "Installation completed successfully!"
echo "======================================"
echo "Access points:"
echo "Home Assistant: http://<raspberry-ip>:8123"
echo "Zigbee2MQTT: http://<raspberry-ip>:8080"
echo "MQTT: mqtt://<raspberry-ip>:1883"
echo "======================================"
echo "MQTT password: $MQTT_PASSWORD"
echo "Please save this password for configuring Home Assistant!"
echo "Please reboot your system for all changes to take effect."
