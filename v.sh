#!/bin/bash
# Debian 11/12 VPS 一键初始化部署脚本（最终稳定版）
# 自动适配 bullseye + bookworm，已修复源问题 + 永不弹窗 + 去掉 btop
# 使用方法：curl -fsSL https://raw.githubusercontent.com/你的用户名/仓库/main/vps-init.sh | bash

set -e
export DEBIAN_FRONTEND=noninteractive

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Debian 11/12 VPS 一键初始化部署脚本（最终稳定版）${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误：请使用 root 权限运行此脚本！${NC}"
    exit 1
fi

# 自动修复 Debian 11 软件源
echo -e "${YELLOW}检测系统版本并修复软件源...${NC}"
if grep -q "bullseye" /etc/os-release; then
    echo -e "${YELLOW}检测到 Debian 11，正在修复 security 和 backports 源...${NC}"
    sed -i 's|http://security.debian.org[^ ]* bullseye/updates|http://security.debian.org/debian-security bullseye-security|g' /etc/apt/sources.list 2>/dev/null || true
    sed -i 's|http://deb.debian.org/debian bullseye-backports|http://archive.debian.org/debian bullseye-backports|g' /etc/apt/sources.list 2>/dev/null || true
fi

# 更新系统
apt update --allow-releaseinfo-change -y && apt upgrade -y

# 安装常用工具
echo -e "${YELLOW}安装常用工具...${NC}"
apt install -y curl wget git vim nano htop net-tools dnsutils unzip zip tar screen tmux rsync ca-certificates gnupg2 lsof lsb-release ufw fail2ban

# 1GB Swap
echo -e "${YELLOW}创建并启用 1GB Swap...${NC}"
if [ ! -f /swapfile ]; then
    fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 时区
echo -e "${YELLOW}设置时区为 Asia/Shanghai...${NC}"
timedatectl set-timezone Asia/Shanghai || (ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone)

# SSH 配置（root密码登录 + 端口61087）
echo -e "${YELLOW}配置 SSH（root登录 + 端口61087）...${NC}"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#\?Port 22/Port 61087/' /etc/ssh/sshd_config 2>/dev/null || echo "Port 61087" >> /etc/ssh/sshd_config

# UFW 防火墙
echo -e "${YELLOW}配置 UFW 防火墙（开放61087/80/443）...${NC}"
ufw allow 22/tcp
ufw allow 61087/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Fail2Ban
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

# 重启 SSH（新端口生效）
systemctl restart ssh
echo -e "${GREEN}✓ SSH 已修改为端口 61087${NC}"
echo -e "${YELLOW}★★★ 请立即使用新端口 61087 重新连接服务器！★★★${NC}"

# BBRv3（XanMod 内核）
echo -e "${YELLOW}安装 XanMod 内核并启用 BBRv3...${NC}"
wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/xanmod-release.list > /dev/null
apt update -y
apt install -y linux-xanmod-x64v3
update-grub

cat >> /etc/sysctl.conf << 'EOL'

# BBRv3 优化配置
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOL
sysctl -p > /dev/null
echo -e "${GREEN}✓ BBRv3 已安装并优化（重启后完全生效）${NC}"

# 显示 3 个安装快捷命令
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

# 询问是否重启
echo -e "\n${GREEN}所有配置已完成！${NC}"
read -p "是否立即重启系统（使 BBRv3 生效）？(y/N): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}系统将在 5 秒后重启...${NC}"
    sleep 5
    # 重启 SSH（新端口生效）
    systemctl restart ssh
    reboot
else
    echo -e "${YELLOW}请稍后手动执行 reboot${NC}"
    echo -e "${RED}重要提醒：务必使用新端口 61087 + root 密码登录！${NC}"
fi
