# Raspberry Pi USB-Tethering als WAN-Failover für UDM Pro

Dieses Repository enthält ein Shell-Skript zur Einrichtung eines Raspberry Pi (z. B. Pi 1 Model B mit Raspberry Pi OS Bookworm Lite) als Backup-Internetquelle über USB-Tethering mit einem iPhone. Der Pi leitet das Internet per Ethernet an den WAN2-Port einer UniFi Dream Machine Pro (UDM Pro) weiter.

---

## ⚙️ Voraussetzungen

- Raspberry Pi (getestet: Model 1 B)
- Raspberry Pi OS Bookworm Lite (frisch geflasht)
- iPhone mit aktivem USB-Hotspot (Bildschirm während der Nutzung offen lassen)
- Original Lightning-Datenkabel (kein reines Ladekabel!)
- Ethernetverbindung vom Pi zur UDM Pro (WAN2)
- SSH-Zugriff auf den Pi während der Einrichtung (z. B. über Port 3 am UDM Pro)

---

## 🔐 Hinweis zur SSH-Verbindung

Das Skript ist so aufgebaut, dass `eth0` zunächst über DHCP läuft, um eine stabile SSH-Verbindung während der Einrichtung zu gewährleisten. Erst am Ende – nach deiner Bestätigung – wird `eth0` auf eine statische IP (`192.168.101.1`) umgestellt. Danach kann das Kabel auf den WAN2-Port der UDM Pro umgesteckt werden.

---

## 📦 Funktionen

- Installation aller benötigten Pakete:
  - `usbmuxd`, `ipheth-utils`, `libimobiledevice6` (für iPhone-Tethering)
  - `dnsmasq` (DHCP-Server)
  - `iptables-persistent` (für dauerhaftes NAT)
- Konfiguration von:
  - `eth1` (USB-iPhone-Hotspot) als Internetquelle
  - `eth0` als statisches LAN-Gateway für UDM Pro WAN2
- Einrichtung von:
  - NAT-Weiterleitung (eth1 → eth0)
  - DHCP-Server auf `eth0`
  - systemd-Route-Service für automatische Default-Route bei jedem Boot

---

## 🛠 Installation

1. Raspberry Pi OS Bookworm Lite auf SD-Karte flashen  
2. Eine leere Datei namens `ssh` in `/boot` erstellen, um SSH zu aktivieren  
3. Pi per Ethernet (eth0) z. B. mit Port 3 vom UDM Pro verbinden  
4. iPhone per USB anschließen und **Hotspot aktivieren**  
5. Per SSH mit dem Pi verbinden  
6. Repository klonen und Skript ausführen:

```bash
git clone https://github.com/DEIN-BENUTZERNAME/raspberrypi-udmpro-usbwan.git
cd raspberrypi-udmpro-usbwan
chmod +x setup-udm-usb.sh
sudo ./setup-udm-usb.sh
```

7. Folge den Anweisungen im Skript:

    - Erst wird das System vollständig eingerichtet  
    - Dann wirst du zur Umstellung auf eine statische IP für `eth0` (192.168.101.1) aufgefordert  
    - Anschließend wird der Pi neu gestartet  
    - Nach dem Reboot kannst du das Ethernet-Kabel vom Pi in den WAN2-Port der UDM Pro stecken

---

## 🚨 Fehlerbehandlung

Falls das iPhone beim Start des Skripts nicht rechtzeitig (innerhalb 20 Sekunden) eine IP-Adresse auf `eth1` vergibt, wird die Standardroute nicht gesetzt. Du kannst das manuell nachholen:

### 1. Prüfen, ob `eth1` eine IP hat:

```bash
ip a show eth1
```

Erwartet wird eine Adresse wie `inet 172.20.10.X/28`.

### 2. Default-Route setzen:

```bash
sudo ip route replace default via 172.20.10.1 dev eth1
```

### 3. Verbindung testen

```bash
ping -c 3 1.1.1.1
```

### 4. systemd-Service manuell starten (falls nötig):

```bash
sudo systemctl start iphone-route.service
```

## 📷 Netzwerkübersicht

```csharp
[iPhone Hotspot]
        │
  Lightning-USB
        │
[Raspberry Pi]
   ├─ eth1 = Internet (vom iPhone)
   └─ eth0 = 192.168.101.1 → DHCP → [UDM Pro WAN2]
```
