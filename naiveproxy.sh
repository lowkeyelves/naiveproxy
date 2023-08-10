#!/bin/bash

# 同步服务器与本地时间
sudo timedatectl set-timezone Asia/Hong_Kong
sudo timedatectl set-ntp on
date

# 更新系统
sudo apt update
sudo apt -y upgrade

# 添加BBR优化网络配置
sudo sh -c 'echo "
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
" >> /etc/sysctl.conf'

# 安装go编译环境
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:longsleep/golang-backports
sudo apt-get install -y golang-go

# 安装naïve fork of Caddy forwardproxy
sudo go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# 编译naïve fork of Caddy forwardproxy
sudo ~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive

# 创建Caddyfile
sudo mkdir /etc/caddy
sudo touch /etc/caddy/Caddyfile

# Caddyfile配置模板
caddyfile_template="
{
  order forward_proxy before file_server
}
:443, {domain} {
  tls {email}
  forward_proxy {
    basic_auth {username} {password}
    hide_ip
    hide_via
    probe_resistance
  }
  file_server {
    root /var/www/html
  }
}"
read -p "请输入您的域名: " domain
read -p "请输入您的TLS邮箱: " email
read -p "请输入NaïveProxy的用户名: " username
read -p "请输入NaïveProxy的密码: " password

# 替换Caddyfile模板中的占位符
caddyfile_content="${caddyfile_template/\{domain\}/$domain}"
caddyfile_content="${caddyfile_content/\{email\}/$email}"
caddyfile_content="${caddyfile_content/\{username\}/$username}"
caddyfile_content="${caddyfile_content/\{password\}/$password}"

# 写入Caddyfile
echo "$caddyfile_content" | sudo tee /etc/caddy/Caddyfile > /dev/null

# 安装caddy执行文件
sudo chmod +x caddy
sudo mv caddy /usr/bin/

# 创建caddy用户和组
sudo groupadd --system caddy
sudo useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin --comment "Caddy web server" caddy

# 创建caddy.service
caddy_service="[Unit]
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
WantedBy=multi-user.target"

# 写入caddy.service
echo "$caddy_service" | sudo tee /etc/systemd/system/caddy.service > /dev/null

# 开启必要的端口
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 443/udp
sudo ufw enable

# 启动caddy
sudo systemctl daemon-reload
sudo systemctl enable caddy
sudo systemctl start caddy

# 交互界面
while true; do
    echo "
    1. 安装NaïveProxy
    2. 卸载NaïveProxy
    3. 编辑Caddyfile
    4. 退出脚本
    "
    read -p "请输入命令编号: " choice
    
    case $choice in
        1)
            echo "正在安装NaïveProxy..."
            sudo systemctl start caddy
            echo "NaïveProxy安装完成！"
            ;;
        2)
            echo "正在卸载NaïveProxy..."
            sudo systemctl stop caddy
            sudo rm -rf /usr/bin/caddy
            sudo rm -rf /etc/caddy
            sudo rm /etc/systemd/system/caddy.service
            echo "NaïveProxy卸载完成！"
            ;;
        3)
            sudo nano /etc/caddy/Caddyfile
            sudo systemctl restart caddy
            echo "Caddyfile已更新并重启Caddy服务！"
            ;;
        4)
            echo "感谢使用！再见！"
            exit 0
            ;;
        *)
            echo "无效的命令编号，请重新输入。"
            ;;
    esac
done
