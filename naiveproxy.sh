#!/bin/bash

# Define variables
DOMAIN=""
EMAIL="" 
USER=""
PASS=""

# Functions

install() {

  # Install prerequisites
  sudo apt update
  sudo apt -y upgrade
  sudo apt-get install software-properties-common
  sudo add-apt-repository ppa:longsleep/golang-backports
  sudo apt-get install golang-go

  # System optimization
  echo 'net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control = bbr' | sudo tee -a /etc/sysctl.conf 

  # Install NaiveProxy
  sudo go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
  sudo ~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive

  # Create Caddyfile
  sudo mkdir /etc/caddy
  sudo touch /etc/caddy/Caddyfile

  cat <<EOF | sudo tee /etc/caddy/Caddyfile 
{
  order forward_proxy before file_server
}

:443, $DOMAIN {
  tls $EMAIL

  forward_proxy {
    basic_auth $USER $PASS 
    hide_ip
    hide_via 
    probe_resistance
  }

  file_server {
    root /var/www/html
  }
}
EOF

  # Install Caddy service
  sudo mv caddy /usr/bin/
  sudo groupadd --system caddy
  sudo useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin --comment "Caddy web server" caddy

  sudo tee /etc/systemd/system/caddy.service <<EOF 
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/ 
After=network.target network-online.target
Requires=network-online.target

[Service]
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]  
WantedBy=multi-user.target
EOF

  sudo ufw allow 80
  sudo ufw allow 443
  sudo ufw enable
  sudo systemctl enable caddy
  sudo systemctl start caddy
}

uninstall() {
  sudo systemctl stop caddy
  sudo systemctl disable caddy 
  sudo rm -rf /usr/bin/caddy
  sudo rm -rf /etc/caddy
  sudo rm /etc/systemd/system/caddy.service
  sudo ufw delete allow 80
  sudo ufw delete allow 443
}

edit_caddyfile() {
  sudo nano /etc/caddy/Caddyfile
}

# Main logic
while true; do

  echo "NaiveProxy Installer"
  echo "1. Install"
  echo "2. Uninstall"
  echo "3. Edit Caddyfile"
  echo "4. Exit"
  read -p "Enter your choice: " choice

  case $choice in
    1)
      read -p "Enter domain: " DOMAIN
      read -p "Enter TLS email: " EMAIL
      read -p "Enter NaiveProxy username: " USER
      read -p "Enter NaiveProxy password: " PASS
      install
      echo "NaiveProxy installed! To reload configs, run: sudo systemctl restart caddy"
      ;;
    2)  
      uninstall
      echo "NaiveProxy uninstalled!"
      ;;
    3)
      edit_caddyfile
      echo "Caddyfile edited!"
      ;;
    4)
      break
      ;;
    *)
      echo "Invalid choice"
      ;;
  esac
done

echo "Exiting..."
