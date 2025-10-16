#!/bin/bash
#
# UGREEN NAS 一键安装LXDE桌面环境
# 适用于: UGOS Pro 1.9.0.0075
#

set -e

echo "================================"
echo "  UGREEN NAS 桌面环境安装脚本"
echo "  Desktop: LXDE (轻量级)"
echo "================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
    echo "使用: sudo bash $0"
    exit 1
fi

# 检查网络
echo -e "${YELLOW}[1/8] 检查网络连接...${NC}"
if ! ping -c 1 debian.org &> /dev/null; then
    echo -e "${RED}错误: 无法连接到互联网${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 网络正常${NC}"
echo ""

# 更新系统
echo -e "${YELLOW}[2/8] 更新系统软件包...${NC}"
apt update || { echo -e "${RED}更新失败${NC}"; exit 1; }
echo -e "${GREEN}✓ 更新完成${NC}"
echo ""

# 安装X服务器
echo -e "${YELLOW}[3/8] 安装X Window系统...${NC}"
apt install -y xorg xserver-xorg-video-intel || { echo -e "${RED}安装失败${NC}"; exit 1; }
echo -e "${GREEN}✓ X服务器安装完成${NC}"
echo ""

# 安装LXDE桌面
echo -e "${YELLOW}[4/8] 安装LXDE桌面环境...${NC}"
apt install -y lxde-core lightdm || { echo -e "${RED}安装失败${NC}"; exit 1; }
echo -e "${GREEN}✓ LXDE安装完成${NC}"
echo ""

# 安装常用应用
echo -e "${YELLOW}[5/8] 安装常用应用程序...${NC}"
apt install -y \
    pcmanfm \
    lxterminal \
    firefox-esr \
    gedit \
    scrot \
    htop \
    mesa-utils \
    -y || { echo -e "${RED}安装失败${NC}"; exit 1; }
echo -e "${GREEN}✓ 应用程序安装完成${NC}"
echo ""

# 安装中文支持
echo -e "${YELLOW}[6/8] 安装中文字体和输入法...${NC}"
apt install -y \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    fonts-noto-cjk \
    fcitx \
    fcitx-googlepinyin \
    -y 2>/dev/null || echo "中文支持安装可能有问题，但继续..."
echo -e "${GREEN}✓ 中文支持安装完成${NC}"
echo ""

# 配置图形启动
echo -e "${YELLOW}[7/8] 配置开机启动图形界面...${NC}"
systemctl set-default graphical.target
systemctl enable lightdm
echo -e "${GREEN}✓ 配置完成${NC}"
echo ""

# 创建桌面快捷方式
echo -e "${YELLOW}[8/8] 创建桌面快捷方式...${NC}"
mkdir -p /root/Desktop

cat > /root/Desktop/Terminal.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Terminal
Icon=utilities-terminal
Exec=lxterminal
EOF

cat > /root/Desktop/FileManager.desktop <<EOF
[Desktop Entry]
Type=Application
Name=File Manager
Icon=system-file-manager
Exec=pcmanfm
EOF

cat > /root/Desktop/Firefox.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Firefox
Icon=firefox
Exec=firefox-esr
EOF

chmod +x /root/Desktop/*.desktop
echo -e "${GREEN}✓ 快捷方式创建完成${NC}"
echo ""

# 显示安装信息
echo ""
echo "================================"
echo -e "${GREEN}  安装完成！${NC}"
echo "================================"
echo ""
echo "安装的组件:"
echo "  • X Window系统"
echo "  • LXDE桌面环境"
echo "  • Firefox浏览器"
echo "  • 文件管理器"
echo "  • 终端"
echo "  • 中文字体和输入法"
echo ""
echo "下一步操作:"
echo "  1. 连接HDMI显示器"
echo "  2. 执行以下命令之一:"
echo ""
echo "     立即启动桌面:"
echo -e "     ${YELLOW}systemctl start lightdm${NC}"
echo ""
echo "     重启系统:"
echo -e "     ${YELLOW}reboot${NC}"
echo ""
echo "  3. 默认用户名: root"
echo "     默认密码: (您的root密码)"
echo ""
echo "提示:"
echo "  • 切换回命令行: Ctrl+Alt+F1"
echo "  • 返回图形界面: Ctrl+Alt+F7"
echo "  • 关闭图形界面: systemctl stop lightdm"
echo ""
echo "================================"

