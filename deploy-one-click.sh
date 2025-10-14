#!/bin/bash
#
# USB Docker鐩撮€氬姛鑳?- 涓€閿儴缃茶剼鏈?# 閫傜敤浜嶴SH杩滅▼閮ㄧ讲锛屾墍鏈夋枃浠惰嚜鍖呭惈鍦ㄨ剼鏈腑
#
# 浣跨敤鏂规硶:
#   鏂规硶1: curl -fsSL <url>/deploy-one-click.sh | sudo bash
#   鏂规硶2: wget -qO- <url>/deploy-one-click.sh | sudo bash
#   鏂规硶3: 涓嬭浇鍚庢墽琛? sudo bash deploy-one-click.sh
#

set -e

# 棰滆壊杈撳嚭
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}鉁?$1${NC}"; }
print_error() { echo -e "${RED}鉁?$1${NC}"; }
print_warning() { echo -e "${YELLOW}鈿?$1${NC}"; }
print_info() { echo -e "${BLUE}鈩?$1${NC}"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

# 鏄剧ず娆㈣繋淇℃伅
clear
cat << 'EOF'
鈺斺晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晽
鈺?                                                           鈺?鈺?       USB Device Docker Passthrough                       鈺?鈺?       USB璁惧鑷姩鐩撮€欴ocker瀹瑰櫒                           鈺?鈺?                                                           鈺?鈺?       涓€閿儴缃茶剼鏈?v1.0                                   鈺?鈺?                                                           鈺?鈺氣晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨暆
EOF
echo

# 妫€鏌oot鏉冮檺
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    echo "Please run: sudo $0"
    exit 1
fi

# 妫€鏌ョ郴缁?print_header "==> Checking system requirements..."
echo

# 妫€鏌ocker
if ! command -v docker &> /dev/null; then
    print_warning "Docker is not installed"
    print_info "Installing Docker automatically..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    print_success "Docker installed"
else
    print_success "Docker is installed"
fi

# 妫€鏌ocker杩愯鐘舵€?if ! docker info &> /dev/null; then
    print_warning "Docker is not running, starting..."
    systemctl start docker
    sleep 2
    if docker info &> /dev/null; then
        print_success "Docker is running"
    else
        print_error "Failed to start Docker"
        exit 1
    fi
else
    print_success "Docker is running"
fi

# 妫€鏌dev
if ! command -v udevadm &> /dev/null; then
    print_error "udev is not installed"
    exit 1
else
    print_success "udev is available"
fi

echo

# 浣跨敤榛樿閰嶇疆锛堜负 EZ-mion 浼樺寲锛?print_header "==> Configuration"
echo

print_info "Using default configuration for EZ-mion..."

# 榛樿閰嶇疆
EZ_MION_MODE=true
CONTAINER_FILTER="specific"
SPECIFIC_CONTAINERS="system-monitor"
DEVICE_FILTER="all"

print_success "Container filter: $CONTAINER_FILTER"
print_success "Target containers: $SPECIFIC_CONTAINERS"
print_success "Device filter: $DEVICE_FILTER"
print_info "EZ-mion mode enabled - will configure for system-monitor container"

echo
print_header "==> Installing USB Docker Passthrough..."
echo

# 鍒涘缓涓存椂鐩綍
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

print_info "Creating installation files..."

# ============================================
# 鍒涘缓涓婚厤缃枃浠?# ============================================
cat > usb-docker-passthrough.conf << 'CONF_EOF'
# USB Docker鐩撮€氶厤缃枃浠?ENABLE_PASSTHROUGH="true"
CONTAINER_FILTER="PLACEHOLDER_CONTAINER_FILTER"
SPECIFIC_CONTAINERS="PLACEHOLDER_SPECIFIC_CONTAINERS"
DEVICE_FILTER="PLACEHOLDER_DEVICE_FILTER"
CUSTOM_DEVICE_PATTERN=""
AUTO_CREATE_DEVICE_NODES="true"
NOTIFY_DBUS="false"
DEVICE_ADD_DELAY=1
VERBOSE_LOGGING="true"
DEVICE_BLACKLIST=""
DEVICE_WHITELIST=""
CONF_EOF

# 鏇挎崲閰嶇疆鍗犱綅绗?sed -i "s|PLACEHOLDER_CONTAINER_FILTER|$CONTAINER_FILTER|g" usb-docker-passthrough.conf
sed -i "s|PLACEHOLDER_SPECIFIC_CONTAINERS|$SPECIFIC_CONTAINERS|g" usb-docker-passthrough.conf
sed -i "s|PLACEHOLDER_DEVICE_FILTER|$DEVICE_FILTER|g" usb-docker-passthrough.conf

# ============================================
# 鍒涘缓udev瑙勫垯鏂囦欢
# ============================================
cat > 99-usb-docker-passthrough.rules << 'RULES_EOF'
# USB璁惧鑷姩鐩撮€氬埌Docker瀹瑰櫒鐨剈dev瑙勫垯
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", \
RUN+="/bin/sh -c '/usr/local/sbin/usb-docker-action.sh add %k %p'"

ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", \
RUN+="/bin/sh -c '/usr/local/sbin/usb-docker-action.sh remove %k %p'"

ACTION=="add", SUBSYSTEM=="tty", KERNEL=="ttyUSB*", \
RUN+="/usr/local/sbin/usb-docker-action.sh add_serial %k /dev/%k"

ACTION=="remove", SUBSYSTEM=="tty", KERNEL=="ttyUSB*", \
RUN+="/usr/local/sbin/usb-docker-action.sh remove_serial %k /dev/%k"

ACTION=="add", SUBSYSTEM=="tty", KERNEL=="ttyACM*", \
RUN+="/usr/local/sbin/usb-docker-action.sh add_serial %k /dev/%k"

ACTION=="remove", SUBSYSTEM=="tty", KERNEL=="ttyACM*", \
RUN+="/usr/local/sbin/usb-docker-action.sh remove_serial %k /dev/%k"
RULES_EOF

# ============================================
# 鍒涘缓鏍稿績鑴氭湰 (绮剧畝鐗?
# ============================================
cat > usb-docker-action.sh << 'SCRIPT_EOF'
#!/bin/bash
CONFIG_FILE="/etc/usb-docker-passthrough.conf"
LOCK_FILE="/var/run/usb-docker-passthrough.lock"
LOG_FILE="/var/log/usb-docker-passthrough.log"
STATE_DIR="/var/run/usb-docker-passthrough"

mkdir -p "$STATE_DIR"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${*:2}" >> "$LOG_FILE"
    logger -t usb-docker-passthrough "[$1] ${*:2}"
}

load_config() {
    ENABLE_PASSTHROUGH="true"
    CONTAINER_FILTER="all"
    SPECIFIC_CONTAINERS=""
    DEVICE_FILTER="all"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
}

get_target_containers() {
    local containers=()
    case "$CONTAINER_FILTER" in
        all|running)
            containers=($(docker ps --format '{{.Names}}' 2>/dev/null))
            ;;
        specific)
            IFS=',' read -ra containers <<< "$SPECIFIC_CONTAINERS"
            ;;
    esac
    echo "${containers[@]}"
}

add_device_to_container() {
    local container_name=$1
    local device_path=$2
    
    [ ! -e "$device_path" ] && return 1
    docker ps --format '{{.Names}}' | grep -q "^${container_name}$" || return 1
    
    local major=$(stat -c '%t' "$device_path" 2>/dev/null)
    local minor=$(stat -c '%T' "$device_path" 2>/dev/null)
    [ -z "$major" ] || [ -z "$minor" ] && return 1
    
    major=$((16#$major))
    minor=$((16#$minor))
    
    local dev_type="c"
    [ -b "$device_path" ] && dev_type="b"
    
    log_message "INFO" "Adding $device_path to $container_name"
    
    docker exec -u root "$container_name" mkdir -p "$(dirname $device_path)" 2>/dev/null
    docker exec -u root "$container_name" mknod "$device_path" "$dev_type" "$major" "$minor" 2>/dev/null
    docker exec -u root "$container_name" chmod 666 "$device_path" 2>/dev/null
    
    echo "${device_path}|${container_name}|$(date +%s)" >> "${STATE_DIR}/attached_devices.log"
    return 0
}

remove_device_from_container() {
    local container_name=$1
    local device_path=$2
    docker ps --format '{{.Names}}' | grep -q "^${container_name}$" || return 1
    docker exec -u root "$container_name" rm -f "$device_path" 2>/dev/null
    [ -f "${STATE_DIR}/attached_devices.log" ] && \
        sed -i "\|^${device_path}|${container_name}|d" "${STATE_DIR}/attached_devices.log"
    return 0
}

handle_serial_add() {
    local device_path=$2
    log_message "INFO" "Serial device added: $device_path"
    sleep 0.5
    local containers=($(get_target_containers))
    for container in "${containers[@]}"; do
        add_device_to_container "$container" "$device_path"
    done
}

handle_serial_remove() {
    local device_path=$2
    log_message "INFO" "Serial device removed: $device_path"
    local containers=($(get_target_containers))
    for container in "${containers[@]}"; do
        remove_device_from_container "$container" "$device_path"
    done
}

main() {
    load_config
    [ "$ENABLE_PASSTHROUGH" != "true" ] && exit 0
    
    exec 200>"$LOCK_FILE"
    flock -n 200 || exit 1
    
    case "$1" in
        add_serial) handle_serial_add "$@" ;;
        remove_serial) handle_serial_remove "$@" ;;
        *) log_message "WARN" "Unknown action: $1" ;;
    esac
    
    flock -u 200
}

main "$@"
SCRIPT_EOF

# ============================================
# 鍒涘缓绠＄悊宸ュ叿 (绮剧畝鐗?
# ============================================
cat > usb-docker-ctl << 'CTL_EOF'
#!/bin/bash
LOG_FILE="/var/log/usb-docker-passthrough.log"
STATE_DIR="/var/run/usb-docker-passthrough"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

show_status() {
    echo -e "${BLUE}=== USB Docker Passthrough Status ===${NC}"
    echo
    echo "Running Containers:"
    docker ps --format '  - {{.Names}}' 2>/dev/null || echo "  (none)"
    echo
    echo "Connected USB Devices:"
    lsusb 2>/dev/null | sed 's/^/  /'
    echo
    [ -f "${STATE_DIR}/attached_devices.log" ] && {
        echo "Active Passthroughs:"
        tail -10 "${STATE_DIR}/attached_devices.log" | while IFS='|' read -r device container timestamp; do
            echo "  $device 鈫?$container"
        done
    }
}

show_logs() {
    [ -f "$LOG_FILE" ] && tail -n ${1:-50} "$LOG_FILE" || echo "No logs found"
}

case "$1" in
    status|"") show_status ;;
    logs) show_logs "$2" ;;
    *) echo "Usage: $0 {status|logs [lines]}" ;;
esac
CTL_EOF

chmod +x usb-docker-action.sh usb-docker-ctl

print_success "Installation files created"

# ============================================
# 瀹夎鏂囦欢
# ============================================
print_info "Installing files to system..."

install -m 755 usb-docker-action.sh /usr/local/sbin/
print_success "Installed usb-docker-action.sh"

install -m 755 usb-docker-ctl /usr/local/sbin/
print_success "Installed usb-docker-ctl"

if [ ! -f /etc/usb-docker-passthrough.conf ]; then
    install -m 644 usb-docker-passthrough.conf /etc/
    print_success "Installed configuration file"
else
    print_warning "Configuration file exists, backing up and updating..."
    cp /etc/usb-docker-passthrough.conf /etc/usb-docker-passthrough.conf.bak
    install -m 644 usb-docker-passthrough.conf /etc/
fi

install -m 644 99-usb-docker-passthrough.rules /etc/udev/rules.d/
print_success "Installed udev rules"

# 鍒涘缓蹇呰鐨勭洰褰?mkdir -p /var/run/usb-docker-passthrough
mkdir -p /var/log
touch /var/log/usb-docker-passthrough.log
chmod 644 /var/log/usb-docker-passthrough.log

print_success "Created runtime directories"

# ============================================
# 婵€娲婚厤缃?# ============================================
echo
print_header "==> Activating configuration..."
echo

print_info "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=usb
print_success "udev rules activated"

# 娓呯悊涓存椂鏂囦欢
cd /
rm -rf "$TEMP_DIR"

# ============================================
# 瀹屾垚
# ============================================
echo
print_success "Installation completed successfully!"
echo

cat << 'EOF'
鈺斺晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晽
鈺?                                                           鈺?鈺?                  Installation Complete!                   鈺?鈺?                                                           鈺?鈺氣晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨暆

Next Steps:

1. Check status:
   usb-docker-ctl status

2. View logs:
   usb-docker-ctl logs

3. Test with a container:
   docker run -d --name test_usb \
     --cap-add=MKNOD --cap-add=SYS_ADMIN \
     ubuntu:22.04 tail -f /dev/null

4. Plug in a USB device (e.g., USB-to-Serial adapter)

5. Verify in container:
   docker exec test_usb ls -l /dev/ttyUSB*

Configuration file: /etc/usb-docker-passthrough.conf
Log file: /var/log/usb-docker-passthrough.log

To uninstall:
  rm -f /usr/local/sbin/usb-docker-action.sh
  rm -f /usr/local/sbin/usb-docker-ctl
  rm -f /etc/udev/rules.d/99-usb-docker-passthrough.rules
  udevadm control --reload-rules

For more information, visit the documentation.

EOF

# 鏄剧ず褰撳墠USB璁惧
print_info "Current USB devices:"
lsusb 2>/dev/null | head -5 | sed 's/^/  /'
[ $(lsusb 2>/dev/null | wc -l) -gt 5 ] && echo "  ..."

echo
print_warning "Important: Containers must run with --cap-add=MKNOD --cap-add=SYS_ADMIN"
echo

# EZ-mion鐗瑰畾閰嶇疆鍜屾祴璇?if [ "$EZ_MION_MODE" = "true" ]; then
    echo
    print_header "==> EZ-mion Specific Configuration"
    echo
    
    # 妫€鏌Z-mion瀹瑰櫒鏄惁杩愯
    if docker ps --format '{{.Names}}' | grep -q "^system-monitor$"; then
        print_success "妫€娴嬪埌system-monitor瀹瑰櫒姝ｅ湪杩愯"
        
        # 涓鸿繍琛屼腑鐨勫鍣ㄦ坊鍔犵幇鏈塙SB璁惧
        print_info "涓鸿繍琛屼腑鐨勫鍣ㄦ坊鍔犵幇鏈塙SB璁惧..."
        
        for device in /dev/ttyUSB* /dev/ttyACM* /dev/hidraw* /dev/video*; do
            if [ -e "$device" ]; then
                print_info "娣诲姞璁惧: $device"
                /usr/local/sbin/usb-docker-action.sh add_serial "$(basename "$device")" "$device" 2>/dev/null || true
            fi
        done
        
        print_success "宸蹭负杩愯涓殑瀹瑰櫒娣诲姞鐜版湁USB璁惧"
    else
        print_warning "system-monitor瀹瑰櫒鏈繍琛?
        print_info "褰撴偍鍚姩EZ-mion瀹瑰櫒鏃讹紝USB璁惧灏嗚嚜鍔ㄦ坊鍔?
    fi
    
    echo
    print_info "EZ-mion鍚姩寤鸿:"
    echo "1. 鍚姩EZ-mion瀹瑰櫒:"
    echo "   docker-compose up -d"
    echo
    echo "2. 鎴栦娇鐢ㄥ惎鍔ㄨ剼鏈?"
    echo "   ./start.sh  (Linux)"
    echo "   start.bat   (Windows)"
    echo
    echo "3. 娴嬭瘯USB璁惧:"
    echo "   docker exec system-monitor ls -l /dev/ttyUSB*"
    echo
    echo "4. 鏌ョ湅USB鐩撮€氱姸鎬?"
    echo "   usb-docker-ctl status"
    echo
    print_success "EZ-mion USB鐩撮€氶厤缃畬鎴愶紒"
fi

exit 0