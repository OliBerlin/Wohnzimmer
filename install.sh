#!/bin/bash

# Exit on error
set -e

echo "Starting Wohnzimmer installation..."

# Function to generate secure random password
generate_password() {
    tr -dc 'A-Za-z0-9!#$%&()*+,-.' </dev/urandom | head -c 32
}

# Install prerequisites
echo "Installing prerequisites..."
sudo apt install -y git mosquitto


# Add repository keys
echo "Adding repository keys..."
curl -sSL https://dtcooper.github.io/raspotify/key.asc | gpg --dearmor | sudo tee /usr/share/keyrings/raspotify-archive-keyring.gpg > /dev/null
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null

# Add repositories
echo "Adding repositories to sources..."
echo 'deb https://dtcooper.github.io/raspotify raspotify main' | sudo tee /etc/apt/sources.list.d/raspotify.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Clone repository
echo "Cloning Wohnzimmer repository..."
git clone https://github.com/OliBerlin/Wohnzimmer
cd Wohnzimmer

# Generate and configure mosquitto 
zigbee2MQTT_PASSWORD=$(generate_password)
homeassistant2MQTT_PASSWORD=$(generate_password)
sudo mosquitto_passwd -H sha512-pbkdf2 -b -c /etc/mosquitto/wohnzimmer.pwd zigbee2MQTT $zigbee2MQTT_PASSWORD
sudo mosquitto_passwd -H sha512-pbkdf2 -b /etc/mosquitto/wohnzimmer.pwd homeassistant $homeassistant2MQTT_PASSWORD
sudo cp mosquitto/mosquitto.conf /etc/mosquitto/conf.d/wohnzimmer.conf
sudo cp mosquitto/wohnzimmer.acl /etc/mosquitto/wohnzimmer.acl

# Update Zigbee2MQTT configuration with MQTT password
echo "Updating Zigbee2MQTT configuration..."
echo "user: zigbee2mqtt" >> docker/zigbee2mqtt-data/configuration.yaml
echo "password: $ZIGBEE2MQTT_PASSWORD" >> docker/zigbee2mqtt-data/configuration.yaml

# Update and upgrade system
echo "Updating system packages..."
sudo apt update
echo "Upgrading system packages..."
sudo apt upgrade -y

# Install required packages
echo "Installing Raspotify and Docker..."
sudo apt install -y raspotify docker-ce docker-ce-cli containerd.io

# Configure Raspotify
echo "Configuring Raspotify..."
sudo sed -i 's/#LIBRESPOT_BITRATE="160"/LIBRESPOT_BITRATE="320"/' /etc/raspotify/conf
sudo sed -i 's/#LIBRESPOT_NAME="Librespot"/LIBRESPOT_NAME="Wohnzimmer"/' /etc/raspotify/conf

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

# Start Docker containers
echo "Starting Docker containers..."
cd docker
sudo docker compose up -d

echo "Installation completed successfully!"
echo "======================================"
echo "Access points:"
echo "Home Assistant: http://<raspberry-ip>:8123"
echo "Zigbee2MQTT: http://<raspberry-ip>:8080"
echo "MQTT: mqtt://<raspberry-ip>:1883"
echo "======================================"
echo "MQTT Credentials for home assistant:"
echo "Username: homeassistant"
echo "Generated MQTT password: $homeassistant2MQTT_PASSWORD"
echo "Please save this password for configuring Home Assistant!"
echo "Please reboot your system for all changes to take effect."
