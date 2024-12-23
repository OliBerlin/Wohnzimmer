git clone https://github.com/OliBerlin/Wohnzimmer
cd wohnzimmer
sudo apt install -y apt-transport-https
curl -sSL https://dtcooper.github.io/raspotify/key.asc | sudo apt-key add -v -
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo 'deb https://dtcooper.github.io/raspotify raspotify main' | sudo tee /etc/apt/sources.list.d/raspotify.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install raspotify
sudo apt install docker-ce docker-ce-cli containerd.io
cd docker
sudo docker compose up -d
sudo sed -i 's/console=serial0,115200//' /boot/firmware/cmdline.txt
sudo sed -i 's/dtparam=audio=on/dtparam=audio=off/' /boot/firmware/config.txt
sudo sed -i 's/#LIBRESPOT_BITRATE="160"/LIBRESPOT_BITRATE="320"/' /etc/raspotify/conf
sudo sed -i 's/#DEVICE_NAME="raspotify"/DEVICE_NAME="Wohnzimmer"/' /etc/raspotify/conf
if ! grep -q '^\[all\]' /boot/firmware/config.txt; then
    echo -e "\n[all]\nenable_uart=1" | sudo tee -a /boot/firmware/config.txt
else
    # Change enable_uart=0 to enable_uart=1 if present
    sudo sed -i 's/enable_uart=0/enable_uart=1/' /boot/firmware/config.txt
    # Add enable_uart=1 under [all] if not already present
    if ! grep -q 'enable_uart=1' /boot/firmware/config.txt; then
        sudo sed -i '/^\[all\]/a enable_uart=1' /boot/firmware/config.txt
    fi
fi