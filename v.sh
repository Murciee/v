#!/bin/bash
# Debian 12 VPS 一键初始化部署脚本（精简优化版）
# BBRv3 已直接彻底安装完成
# 使用方法：curl -fsSL https://raw.githubusercontent.com/你的用户名/仓库/main/vps-init.sh | bash

set -e

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Debian 12 新VPS 一键初始化部署脚本${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误：请使用 root 权限运行此脚本！${NC}"
    exit 1
fi

# 1. 更新系统并安装常用工具
echo -e "${YELLOW}正在更新系统并安装常用工具...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget git vim nano htop btop net-tools dnsutils unzip zip tar screen tmux rsync ca-certificates gnupg2 lsof lsb-release ufw fail2ban

# 2. 设置 1GB Swap
echo -e "${YELLOW}创建 1GB Swap 虚拟内存...${NC}"
if [ ! -f /swapfile ]; then
    fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo -e "${GREEN}✓ 1GB Swap 已启用${NC}"
fi

# 3. 设置时区
echo -e "${YELLOW}设置时区为 Asia/Shanghai...${NC}"
timedatectl set-timezone Asia/Shanghai || (ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone)
echo -e "${GREEN}✓ 时区已设置${NC}"

# 4. 配置 SSH（root密码登录 + 端口61087）
echo -e "${YELLOW}配置 SSH（root登录 + 端口61087）...${NC}"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#\?Port 22/Port 61087/' /etc/ssh/sshd_config 2>/dev/null || echo "Port 61087" >> /etc/ssh/sshd_config

# 5. 配置 UFW
echo -e "${YELLOW}配置 UFW 防火墙（开放61087/80/443）...${NC}"
ufw allow 22/tcp
ufw allow 61087/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 6. 配置 Fail2Ban
echo -e "${YELLOW}配置 Fail2Ban（防护61087端口）...${NC}"
cat > /etc/fail2ban/jail.local << 'EOL'
[DEFAULT]
bantime  = 1d
findtime = 10m
maxretry = 5

[sshd]
enabled  = true
port     = 61087
EOL
systemctl restart fail2ban

systemctl restart ssh
echo -e "${GREEN}✓ SSH 已修改为端口 61087${NC}"
echo -e "${YELLOW}★★★ 请立即用新端口 61087 重新连接！★★★${NC}"

# 7. 直接安装 XanMod + BBRv3
echo -e "${YELLOW}安装 XanMod 内核并启用 BBRv3...${NC}"
wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/xanmod-release.list > /dev/null
apt update -y
apt install -y linux-xanmod-x64v3
update-grub

cat >> /etc/sysctl.conf << 'EOL'

# BBRv3 优化
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOL
sysctl -p > /dev/null
echo -e "${GREEN}✓ BBRv3 已安装并优化（重启后生效）${NC}"

# 8. 安装快捷命令
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                  一键安装工具快捷命令${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}【1】 1Panel 面板${NC}"
echo -e "${BLUE}bash -c \"\$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)\"${NC}"

echo -e "\n${YELLOW}【2】 科技lion 一键工具箱${NC}"
echo -e "${BLUE}bash <(curl -sL kejilion.sh)${NC}"

echo -e "\n${YELLOW}【3】 Sing-box 安装${NC}"
echo -e "${BLUE}bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)${NC}"

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}BBRv3 内核已直接安装并优化完成（重启后立即生效）${NC}"

# 9. 是否重启
echo -e "\n${GREEN}所有配置已完成！${NC}"
read -p "是否立即重启系统？(y/N): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}5秒后重启...${NC}"
    sleep 5
    reboot
else
    echo -e "${YELLOW}请稍后手动 reboot 使 BBRv3 生效${NC}"
    echo -e "${RED}重要：务必用新端口 61087 登录！${NC}"
fi
