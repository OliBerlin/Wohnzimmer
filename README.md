# Allgemeines
Da mein Verstärker kein Spotify-Connect unterstützt und erste Smarte Geräte im Haushalt vorhanden sind, bietet sich der Einsatz vom [Home Assistant](https://www.home-assistant.io/) an. Vorhanden ist auch bereits ein Zigbee-Connector (Phoscon RaspBee II). 

HAOS ist jedoch auf der vorhandenen Hardware (Raspberry Pi 3B+, 1GB RAM) etwas langsam. Dies zeigte sich an regelmäßigen Aussetzern bei dem Spotify-AddOn. Durch das Hosten von HA in einem Docker-Containter ist die Performance gestiegen und Spotify läuft stabil mit 320Bit.

Man muß jedoch auch den Nachteil von diesem Setup beachten:
- keine AddOns
- keine Updates (Updates müssen über Docker compose eingespielt werden)

So kann der Raspi ohne Probleme auch für weitere Projekte genutzt werden.

## Vorgehen
Für die ganz eiligen kann einfach der Installer gestartet werden😉 Während der Installation wird ein Random-PW für zigbee2mqtt sowie homeassistant in mosquitto erzeugt, welches später in HA angegeben werden muß.

Alternativ kann die Dokumentation von oben nach unten straight abgearbeitet werden.
```bash
wget https://github.com/OliBerlin/Wohnzimmer/raw/refs/heads/main/install.sh -O - | bash
```

# OS
Es wird die aktuelle Version Debian 12 (Bookworm-arm64) verwendet. Das ganze headless, sprich, ohne Desktop

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
Da ausschließlich HDMI als Output gewählt wird, wurde der Soundtreiber für den Klinkenausgang folgendermaßen in der Datei `/boot/firmware/config.txt` deaktiviert. Ebenfalls wurde die serielle Schnittstelle mittels GPIO aktiviert.
```plaintext
dtparam=audio=off

[all]
enable_uart=1
```
Damit die serielle Schnittstelle nutzbar ist, ist in der Datei `/boot/firmware/cmdline.txt` der Eintrag `console=serial0,115200` zu entfernen. **Achtung, diese Zeile kann u.U. anders aussehen**:
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
# mosquitto
## Installation
```bash
sudo apt install mosquitto
```
## Konfiguration
Da mosquitto noch ggf. für andere Dienste genutzt wird, sollte dieser möglichst abgesichert werden. Dies geschieht einerseits über Username/Password sowie über ACLs.
### ACLs
```plaintext
user zigbee2MQTT
topic readwrite zigbee2mqtt/#
topic write homeassistant/#

user homeassistant
topic read zigbee2mqtt/#
topic write zigbee2mqtt/+/set
topic readwrite homeassistant/#
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
`docker-compose.yml`
```yaml
services:
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
      - zigbee2mqtt # Startet nach Zigbee2MQTT
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

# Anmerkungen
Die compose-Datei und der Installer wurden mit Hilfe von [Claude AI](https://claude.ai) überarbeitet.
