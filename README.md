Als Hardware kommt ein Raspberry Pi 3B+ sowie ein Raspbee II als GPIO-Stecker zum Einsatz. Um nicht ständig den Brummton durch den Klinkenstecker zu hören, wurde HDMI als Audio-Ausgang gewählt.


# OS
Zum Einsatz kommt ein aktuelles debian 12 (Bookworm-arm64).

## Repositories
### Vorbereitungen
Um Repositorities hinzuzufügen, sind folgende Steps notwendig:
```bash
sudo apt install -y apt-transport-https
```
### Keys
Um die Signierung der Repositories zu überprüfen, sind die Keys in das System einzuspielen:
```bash
curl -sSL https://dtcooper.github.io/raspotify/key.asc | sudo apt-key add -v -
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```
### Repos
```bash
echo 'deb https://dtcooper.github.io/raspotify raspotify main' | sudo tee /etc/apt/sources.list.d/raspotify.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
```
## Firmware
Da ausschließlich HDMI als Output gewählt wird, wurde der Soundtreiber für den Klinkenausgang folgendermaßen in der Datei /boot/firmware/config.txt deaktiviert. Ebenfalls wurde die serielle Schnittstelle mittels GPIO aktiviert.
```plaintext
dtparam=audio=off
[all]
enable_uart=1
```
Damit die serielle Schnittstelle nutzbar ist, ist in der Datei der Eintrag console=serial0,115200 zu entfernen. **Achtung, diese Zeile kann u.U. anders aussehen**:
```plaintext
console=tty1 root=PARTUUID=a60345bb-02 rootfstype=ext4 fsck.repair=yes rootwait cfg80211.ieee80211_regdom=DE
```
# Spotify-Connect
Es gibt verschiedene Lösungen, um Spotify-Connect umzusetzen, hier wurde raspotify gewählt. Dazu sind folgendes Steps notwendig:

## Installation
```bash
sudo apt install raspotify
```
## Konfiguration 
/etc/raspotify/conf:
```
LIBRESPOT_NAME="Wohnzimmer"
LIBRESPOT_BITRATE="320"
```
# Docker
## Installation
```bash
sudo apt install docker-ce docker-ce-cli containerd.io
```
## Konfiguration
### Docker
```bash
mkdir docker
cd docker
```
nano docker-compose.yml
```yaml
services:
  # MQTT Broker (Eclipse Mosquitto) - Wird für die Kommunikation zwischen Zigbee2MQTT und Home Assistant verwendet
  mqtt:
    container_name: mqtt  # Name des Containers im Docker-System
    image: eclipse-mosquitto:latest  # Verwendet die neueste Version von Eclipse Mosquitto
    restart: unless-stopped  # Container wird automatisch neugestartet, außer bei manuellem Stopp
    network_mode: host  # Verwendet das Host-Netzwerk für bessere Kompatibilität
    volumes:  # Persistente Datenspeicherung
      - ./mosquitto-data:/mosquitto  # Hauptverzeichnis für MQTT-Daten
      - ./mosquitto-data/config:/mosquitto/config  # Konfigurationsdateien
      - ./mosquitto-data/log:/mosquitto/log  # Logdateien
    user: "1000:1000"  # Läuft als nicht-root Benutzer für bessere Sicherheit

  # Zigbee2MQTT - Bridge zwischen Zigbee-Geräten und MQTT
  zigbee2mqtt:
    container_name: zigbee2mqtt
    image: koenkk/zigbee2mqtt  # Offizielles Zigbee2MQTT Image
    restart: unless-stopped
    network_mode: host  # Notwendig für die Kommunikation mit dem MQTT-Broker
    environment:
      - TZ=Europe/Berlin  # Setzt die Zeitzone für korrekte Zeitstempel
    volumes:
      - ./zigbee2mqtt-data:/app/data  # Speichert Konfiguration und Daten
      - /run/udev:/run/udev:ro  # Notwendig für USB-Geräteerkennung
    devices:
      - /dev/ttyS0:/dev/ttyS0  # Gibt dem Container Zugriff auf den Conbee II Adapter
    privileged: true  # Notwendig für Hardware-Zugriff
    depends_on:  # Startet erst nach dem MQTT-Broker
      - mqtt

  # Home Assistant
  homeassistant:
    image: homeassistant/home-assistant:2024.12  # Spezifische Version für Stabilität
    container_name: homeassistant
    restart: unless-stopped
    network_mode: host  # Ermöglicht die Erkennung von Geräten im Netzwerk
    environment:
      - TZ=Europe/Berlin  # Zeitzoneneinstellung für korrekte Zeitanzeige
    volumes:
      - ./homeassistant-data:/config # Persistente Speicherung der Home Assistant Konfiguration
      - /etc/localtime:/etc/localtime:ro # Synchronisiert die Systemzeit mit dem Host
      - /run/dbus:/run/dbus:ro   # Notwendig für verschiedene Systemintegrationen (Bluetooth, Sound, etc.)
    depends_on:  # Definiert die Startreihenfolge
      - mqtt        # Startet nach MQTT
      - zigbee2mqtt # Startet nach Zigbee2MQTT
```
### MQTT
./mosquitto-data/config/mosquitto-data/config

```plaintext
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
# Erlaubt anonymen Zugriff (nur für Test/Entwicklung)
allow_anonymous true
listener 1883
```
### zigbee2mqtt
./zigbee2mqtt-data/configuration.yaml
```yaml
permit_join: true
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://localhost:1883
  include_device_information: true
  keepalive: 60
  reject_unauthorized: true
  version: 4
serial:
  port: /dev/ttyS0
  adapter: deconz
frontend:
  port: 8080
  host: 0.0.0.0
availability: true
homeassistant: true
```
## Compose
```bash
sudo docker compose up -d
```
# Zugriffe
Home Assistant: http://*raspberry-ip*:8123

Zigbee2MQTT: http://*raspberry-ip*:8080

MQTT: mqtt://*raspberry-ip*:1883
