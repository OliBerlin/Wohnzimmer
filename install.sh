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
    # Generate a 32 character random password with special characters
    password=$(tr -dc 'A-Za-z0-9!#$%&()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c 32)
    echo "$password"
}

# Clone repository
echo "Cloning Wohnzimmer repository..."
git clone https://github.com/OliBerlin/Wohnzimmer
cd wohnzimmer
check_command "Repository clone"

# Generate passwords
echo "Generating secure passwords..."
MQTT_PASSWORD=$(generate_password)
ZIGBEE2MQTT_PASSWORD=$(generate_password)

# Save passwords to a secure file
echo "Saving passwords to secure file..."
cat > ./passwords.txt << EOF
MQTT Password: $MQTT_PASSWORD
Zigbee2MQTT Password: $ZIGBEE2MQTT_PASSWORD
EOF
chmod 600 ./passwords.txt

# Update Docker configuration with new passwords
echo "Updating Docker configuration..."
if [ -f "./docker/mqtt/config/mosquitto.conf" ]; then
    # Create password file for mosquitto
    echo "mqtt:$MQTT_PASSWORD" | sudo tee ./docker/mqtt/config/mosquitto.passwd > /dev/null
    sudo mosquitto_passwd -U ./docker/mqtt/config/mosquitto.passwd
fi

# Update Zigbee2MQTT configuration
if [ -f "./docker/zigbee2mqtt/data/configuration.yaml" ]; then
    sudo sed -i "s/password: .*/password: $ZIGBEE2MQTT_PASSWORD/" ./docker/zigbee2mqtt/data/configuration.yaml
fi

# Install prerequisites
echo "Installing prerequisites..."
sudo apt install -y apt-transport-https mosquitto-clients
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

# Set up Docker environment
echo "Setting up Docker environment..."
cd docker
sudo docker compose up -d
check_command "Docker setup"

# Configure system settings
echo "Configuring system settings..."
sudo sed -i 's/console=serial0,115200//' /boot/firmware/cmdline.txt
sudo sed -i 's/dtparam=audio=on/dtparam=audio=off/' /boot/firmware/config.txt
check_command "System configuration"

# Configure Raspotify
echo "Configuring Raspotify..."
sudo sed -i 's/#LIBRESPOT_BITRATE="160"/LIBRESPOT_BITRATE="320"/' /etc/raspotify/conf
sudo sed -i 's/#DEVICE_NAME="raspotify"/DEVICE_NAME="Wohnzimmer"/' /etc/raspotify/conf
check_command "Raspotify configuration"

# Configure UART
echo "Configuring UART..."
if ! grep -q '^\[all\]' /boot/firmware/config.txt; then
    echo -e "\n[all]\nenable_uart=1" | sudo tee -a /boot/firmware/config.txt
else
    sudo sed -i 's/enable_uart=0/enable_uart=1/' /boot/firmware/config.txt
    if ! grep -q 'enable_uart=1' /boot/firmware/config.txt; then
        sudo sed -i '/^\[all\]/a enable_uart=1' /boot/firmware/config.txt
    fi
fi
check_command "UART configuration"

echo "Installation completed successfully!"
echo "Passwords have been saved to ./passwords.txt"
echo "Please save these passwords in a secure location and delete passwords.txt after setup"
echo "Please reboot your system for changes to take effect."