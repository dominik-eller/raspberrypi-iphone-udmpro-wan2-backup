#!/bin/bash
set -e

echo "📦 Installiere benötigte Pakete..."
sudo apt update
sudo apt install -y dnsmasq iptables-persistent usbmuxd ipheth-utils libimobiledevice6

echo "🔁 Starte usbmuxd neu..."
sudo systemctl restart usbmuxd

echo "⏳ Warte auf iPhone-Verbindung über eth1..."
sleep 10

# Warten auf gültige IP (iPhone-Hotspot via eth1)
echo "🌐 Warte auf gültige iPhone-IP via eth1..."
for i in {1..20}; do
    IP=$(ip -4 addr show dev eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)
    if [[ "$IP" == 172.20.10.* ]]; then
        echo "✅ eth1 hat IP $IP – setze Standardroute..."
        sudo ip route replace default via 172.20.10.1 dev eth1
        break
    fi
    echo "⏳ [$i/20] Noch keine IP auf eth1 – warte..."
    sleep 1
done

echo "🛡 Setze NAT-Regeln (eth1 → eth0)..."
sudo iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT
sudo iptables -A FORWARD -i eth1 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo netfilter-persistent save

echo "📡 Konfiguriere DHCP-Server für eth0..."
sudo tee /etc/dnsmasq.conf >/dev/null <<EOF
interface=eth0
dhcp-range=192.168.101.10,192.168.101.20,255.255.255.0,12h
EOF
sudo systemctl restart dnsmasq

echo "🔁 Aktiviere IP-Forwarding..."
sudo sed -i 's/^#\?net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

echo "💾 Erstelle systemd-Route für eth1..."
sudo tee /etc/systemd/system/iphone-route.service >/dev/null <<EOF
[Unit]
Description=Set default route via iPhone (eth1)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/sbin/ip route replace default via 172.20.10.1 dev eth1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable iphone-route.service

echo "⚠️ SSH-Schutz aktiv – eth0 bleibt vorerst auf DHCP."
echo "🔄 Drücke ENTER, um eth0 jetzt auf statische IP (192.168.101.1) umzustellen und neuzustarten."
read -p "Fortfahren? [ENTER]"

echo "🌐 Setze statische IP auf eth0..."
sudo tee /etc/systemd/network/10-eth0-static.network >/dev/null <<EOF
[Match]
Name=eth0

[Network]
Address=192.168.101.1/24
DHCP=no
EOF

sudo systemctl enable systemd-networkd
sudo systemctl restart systemd-networkd

echo "♻️ Neustart empfohlen."
read -p "Jetzt neustarten? [ENTER]"
sudo reboot
