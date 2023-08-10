#!/bin/bash

# Function to display the menu
show_menu() {
    clear
    echo "NaïveProxy 一键安装脚本"
    echo "------------------------"
    echo "1. 安装 NaïveProxy"
    echo "2. 卸载 NaïveProxy"
    echo "3. 编辑 Caddyfile"
    echo "4. 退出脚本"
    echo
    echo -n "请输入选项: "
}

# Function to install NaïveProxy
install_naiveproxy() {
    # Step 1: Synchronize server time
    sudo timedatectl set-timezone Asia/Hong_Kong
    sudo timedatectl set-ntp on
    date

    # Step 2: Update and upgrade system packages
    sudo apt update
    sudo apt -y upgrade

    # Step 3: Configure network optimizations
    sudo bash -c 'cat >> /etc/sysctl.conf <<EOF
# max open files
fs.file-max = 51200
# max read buffer
net.core.rmem_max = 67108864
# max write buffer
net.core.wmem_max = 67108864
# default read buffer
net.core.rmem_default = 65536
# default write buffer
net.core.wmem_default = 65536
# max processor input queue
net.core.netdev_max_backlog = 4096
# max backlog
net.core.somaxconn = 4096
# resist SYN flood attacks
net.ipv4.tcp_syncookies = 1
# reuse timewait sockets when safe
net.ipv4.tcp_tw_reuse = 1
# turn off fast timewait sockets recycling
net.ipv4.tcp_tw_recycle = 0
# short FIN timeout
net.ipv4.tcp_fin_timeout = 30
# short keepalive time
net.ipv4.tcp_keepalive_time = 1200
# outbound port range
net.ipv4.ip_local_port_range = 10000 65000
# max SYN backlog
net.ipv4.tcp_max_syn_backlog = 4096
# max timewait sockets held by system simultaneously
net.ipv4.tcp_max_tw_buckets = 5000
# TCP receive buffer
net.ipv4.tcp_rmem = 4096 87380 67108864
# TCP write buffer
net.ipv4.tcp_wmem = 4096 65536 67108864
# turn on path MTU discovery
net.ipv4.tcp_mtu_probing = 1
# for high-latency network
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control = bbr
EOF'

    sysctl -p

    # Step 4: Install Go compiler
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:longsleep/golang-backports
    sudo apt-get install -y golang-go

    # Step 5: Install naïve fork of Caddy forwardproxy
    sudo go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

    # Step 6: Build naïve fork of Caddy forwardproxy
    sudo ~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive

    # Step 7: Create Caddyfile
    sudo mkdir -p /etc/caddy
    sudo touch /etc/caddy/Caddyfile

    # Step 8: Write Caddyfile configuration template
    sudo bash -c 'cat > /etc/caddy/Caddyfile <<EOF
{
  order forward_proxy before file_server
}
:443, example.com {
  tls EMAIL_ADDRESS
  forward_proxy {
    basic_auth USERNAME PASSWORD
    hide_ip
    hide_via
    probe_resistance
  }
  file_server {
    root /var/www/html
  }
}
EOF'

    # Step 9: Set permissions and move caddy binary
    sudo chmod +x caddy
    sudo mv caddy /usr/bin/

    # Step 10: Create unique Linux group and user for caddy
    sudo groupadd --system caddy
    sudo useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin --comment "Caddy web server" caddy

    # Step 11: Create systemd service file for caddy
    sudo bash -c 'cat > /etc/systemd/system/caddy.service <<EOF
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
EOF'

    # Step 12: Open necessary ports
    sudo ufw allow 22
    sudo ufw allow 80
    sudo ufw allow 443
    sudo ufw allow 443/udp
    sudo ufw enable

    # Step 13: Start Caddy
    sudo systemctl daemon-reload
    sudo systemctl enable caddy
    sudo systemctl start caddy

    echo "NaïveProxy 安装完成！"
}

# Function to uninstall NaïveProxy
uninstall_naiveproxy() {
    sudo systemctl stop caddy
    sudo systemctl disable caddy
    sudo rm -rf /usr/bin/caddy
    sudo rm -rf /etc/caddy
    sudo userdel caddy
    sudo groupdel caddy
    echo "NaïveProxy 已卸载！"
}

# Function to edit Caddyfile
edit_caddyfile() {
    sudo nano /etc/caddy/Caddyfile
}

# Interactive menu loop
while true
do
    show_menu
    read choice
    case $choice in
        1) install_naiveproxy ;;
        2) uninstall_naiveproxy ;;
        3) edit_caddyfile ;;
        4) exit ;;
        *) echo "无效选项，请重新输入" ;;
    esac
    echo "按 Enter 键继续..."
    read enterKey
done
