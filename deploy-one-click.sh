#!/bin/bash
#
# USB Docker Passthrough - One-Click Deployment Script
# Suitable for SSH remote deployment, all files are self-contained in the script
#
# Usage:
#   Method 1: curl -fsSL <url>/deploy-one-click.sh | sudo bash
#   Method 2: wget -qO- <url>/deploy-one-click.sh | sudo bash
#   Method 3: Download and run: sudo bash deploy-one-click.sh
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}[OK] $1${NC}"; }
print_error() { echo -e "${RED}[ERROR] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }
print_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

# Display welcome message
clear
cat << 'EOF'
================================================================
                                                                
        USB Device Docker Passthrough                           
        Auto USB Device Passthrough to Docker Container         
                                                                
        One-Click Deployment Script v1.0                        
                                                                
================================================================
EOF
echo

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    echo "Please run: sudo $0"
    exit 1
fi

# Check system requirements
print_header "==> Checking system requirements..."
echo

# Check Docker
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

# Check Docker running status
if ! docker info &> /dev/null; then
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

# Check udev
if ! command -v udevadm &> /dev/null; then
    print_error "udev is not installed"
    exit 1
else
    print_success "udev is available"
fi

echo

# Use default configuration (optimized for EZ-mion)
print_header "==> Configuration"
echo

print_info "Using default configuration for EZ-mion..."

# Default configuration
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

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

print_info "Creating installation files..."

# ============================================
# Create main configuration file
# ============================================
cat > usb-docker-passthrough.conf << 'CONF_EOF'
# USB Docker Passthrough Configuration File
ENABLE_PASSTHROUGH="true"
CONTAINER_FILTER="PLACEHOLDER_CONTAINER_FILTER"
SPECIFIC_CONTAINERS="PLACEHOLDER_SPECIFIC_CONTAINERS"
DEVICE_FILTER="PLACEHOLDER_DEVICE_FILTER"
AUTO_CREATE_DEVICE_NODES="true"
VERBOSE_LOGGING="true"
CONF_EOF

# Replace configuration placeholders
sed -i "s|PLACEHOLDER_CONTAINER_FILTER|$CONTAINER_FILTER|g" usb-docker-passthrough.conf
sed -i "s|PLACEHOLDER_SPECIFIC_CONTAINERS|$SPECIFIC_CONTAINERS|g" usb-docker-passthrough.conf
sed -i "s|PLACEHOLDER_DEVICE_FILTER|$DEVICE_FILTER|g" usb-docker-passthrough.conf

# ============================================
# Create udev rules file
# ============================================
cat > 99-usb-docker-passthrough.rules << 'RULES_EOF'
# udev rules for automatic USB device passthrough to Docker containers
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", \
RUN+="/bin/sh -c '/usr/local/sbin/usb-docker-action.sh add %k %p'"

ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", \
RUN+="/bin/sh -c '/usr/local/sbin/usb-docker-action.sh remove %k %p'"

ACTION=="add", SUBSYSTEM=="tty", KERNEL=="ttyUSB*", \
RUN+="/usr/local/sbin/usb-docker-action.sh add_serial %k /dev/%k"

ACTION=="add", SUBSYSTEM=="tty", KERNEL=="ttyACM*", \
RUN+="/usr/local/sbin/usb-docker-action.sh add_serial %k /dev/%k"

ACTION=="remove", SUBSYSTEM=="tty", KERNEL=="ttyUSB*", \
RUN+="/usr/local/sbin/usb-docker-action.sh remove_serial %k /dev/%k"

ACTION=="remove", SUBSYSTEM=="tty", KERNEL=="ttyACM*", \
RUN+="/usr/local/sbin/usb-docker-action.sh remove_serial %k /dev/%k"
RULES_EOF

# ============================================
# Create core script (simplified version)
# ============================================
cat > usb-docker-action.sh << 'SCRIPT_EOF'
#!/bin/bash
CONFIG_FILE="/etc/usb-docker-passthrough.conf"
LOG_FILE="/var/log/usb-docker-passthrough.log"
STATE_DIR="/var/run/usb-docker-passthrough"

mkdir -p "$STATE_DIR"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${*:2}" >> "$LOG_FILE"
}

load_config() {
    ENABLE_PASSTHROUGH="true"
    CONTAINER_FILTER="specific"
    SPECIFIC_CONTAINERS="system-monitor"
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
    
    case "$1" in
        add_serial) handle_serial_add "$@" ;;
        remove_serial) handle_serial_remove "$@" ;;
        *) log_message "WARN" "Unknown action: $1" ;;
    esac
}

main "$@"
SCRIPT_EOF

# ============================================
# Create management tool (simplified version)
# ============================================
cat > usb-docker-ctl << 'CTL_EOF'
#!/bin/bash
LOG_FILE="/var/log/usb-docker-passthrough.log"
STATE_DIR="/var/run/usb-docker-passthrough"

show_status() {
    echo "=== USB Docker Passthrough Status ==="
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
            echo "  $device -> $container"
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

# Set execute permissions
chmod +x usb-docker-action.sh usb-docker-ctl

# ============================================
# Install files
# ============================================
print_info "Installing files to system..."

install -m 755 usb-docker-action.sh /usr/local/sbin/
print_success "Installed action script"

install -m 755 usb-docker-ctl /usr/local/sbin/
print_success "Installed management tool"

install -m 644 usb-docker-passthrough.conf /etc/
print_success "Installed configuration file"

install -m 644 99-usb-docker-passthrough.rules /etc/udev/rules.d/
print_success "Installed udev rules"

# Create necessary directories
mkdir -p /var/run/usb-docker-passthrough
mkdir -p /var/log
touch /var/log/usb-docker-passthrough.log
chmod 644 /var/log/usb-docker-passthrough.log
print_success "Created runtime directories"

# ============================================
# Activate configuration
# ============================================
echo
print_header "==> Activating configuration..."
echo

udevadm control --reload-rules
udevadm trigger --subsystem-match=usb
print_success "udev rules activated"

# Clean up temporary files
cd /
rm -rf "$TEMP_DIR"

# ============================================
# Complete
# ============================================
echo
print_header "==> Installation Complete!"
echo

cat << 'EOF'
================================================================
                                                                
                   Installation Complete!                       
                                                                
================================================================

Next Steps:

1. Check system status:
   usb-docker-ctl status

2. View passthrough logs:
   usb-docker-ctl logs

3. Test with a container:
   docker run -d --name test_container \
     --cap-add=MKNOD --cap-add=SYS_ADMIN \
     ubuntu:22.04 tail -f /dev/null

EOF

# Display current USB devices
print_info "Current USB devices:"
lsusb 2>/dev/null | head -5 | sed 's/^/  /'
echo

# EZ-mion specific configuration and testing
if [ "$EZ_MION_MODE" = "true" ]; then
    echo
    print_header "==> EZ-mion Specific Configuration"
    echo
    
    # Check if EZ-mion container is running
    if docker ps --format '{{.Names}}' | grep -q "^system-monitor$"; then
        print_success "Detected system-monitor container is running"
        
        # Add existing USB devices to running container
        print_info "Adding existing USB devices to running container..."
        
        for device in /dev/ttyUSB* /dev/ttyACM* /dev/hidraw* /dev/video*; do
            if [ -e "$device" ]; then
                print_info "Adding device: $device"
                /usr/local/sbin/usb-docker-action.sh add_serial "$(basename "$device")" "$device" 2>/dev/null || true
            fi
        done
        
        print_success "Added existing USB devices to running container"
    else
        print_warning "system-monitor container is not running"
        print_info "USB devices will be automatically added when you start the EZ-mion container"
    fi
    
    echo
    print_info "EZ-mion startup recommendations:"
    echo "1. Start EZ-mion container:"
    echo "   docker-compose up -d"
    echo
    echo "2. Or use startup script:"
    echo "   ./start.sh  (Linux)"
    echo "   start.bat   (Windows)"
    echo
    echo "3. Test USB devices:"
    echo "   docker exec system-monitor ls -l /dev/ttyUSB*"
    echo
    echo "4. Check USB passthrough status:"
    echo "   usb-docker-ctl status"
    echo
    print_success "EZ-mion USB passthrough configuration complete!"
fi
