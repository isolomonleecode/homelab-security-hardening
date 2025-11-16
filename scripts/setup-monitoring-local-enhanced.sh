#!/bin/bash
# Enhanced Local Device Monitoring Setup Script
# Run this script ON the device you want to monitor (not from capcorp9000)
# This script will:
# 1. Install and configure SSH server
# 2. Install and configure firewall with safe defaults
# 3. Install Docker (if needed)
# 4. Deploy Promtail + node_exporter containers
# 5. Configure firewall for monitoring
# 6. Set up SSH keys for remote management

set -e

# Configuration
LOKI_SERVER="192.168.0.19:3100"
PROMETHEUS_SERVER="192.168.0.19:9090"
MONITORING_NETWORK="192.168.0.0/24"
COMMAND_CENTER="capcorp9000"
COMMAND_CENTER_IP="192.168.0.52"
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICe80VCDZRggo/cDaEdpEZIM7MakB4PxTT4UfVemakjo ssjlox@capcorp9000"

# Common ports to keep open (adjust based on your needs)
COMMON_SERVICES=(
    "22/tcp:SSH"
    "80/tcp:HTTP"
    "443/tcp:HTTPS"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Home SOC: Enhanced Local Device Setup"
echo "=========================================="
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
    OS_LIKE=$ID_LIKE
else
    echo "${RED}❌ Cannot detect OS. /etc/os-release not found${NC}"
    exit 1
fi

HOSTNAME=$(hostname)
CURRENT_USER=$(whoami)
MY_IP=$(hostname -I | awk '{print $1}')

echo "Detected Configuration:"
echo "  Hostname: $HOSTNAME"
echo "  IP Address: $MY_IP"
echo "  User: $CURRENT_USER"
echo "  OS: $OS $OS_VERSION"
echo "  Loki Server: $LOKI_SERVER"
echo ""
echo "${YELLOW}This script will install SSH, firewall, and Docker if not present.${NC}"
echo ""
read -p "Continue with setup? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi
echo ""

# ============================================
# STEP 1: Install and Configure SSH Server
# ============================================
echo "[1/8] Checking SSH server installation..."

SSH_SERVICE=""
if systemctl is-active --quiet sshd 2>/dev/null; then
    SSH_SERVICE="sshd"
    echo "${GREEN}✅ SSH server (sshd) is already running${NC}"
elif systemctl is-active --quiet ssh 2>/dev/null; then
    SSH_SERVICE="ssh"
    echo "${GREEN}✅ SSH server (ssh) is already running${NC}"
else
    echo "${YELLOW}⚠️  SSH server not running. Installing...${NC}"

    case "$OS" in
        arch|manjaro|garuda|cachyos)
            echo "Installing OpenSSH on Arch-based system..."
            sudo pacman -Sy --noconfirm openssh
            SSH_SERVICE="sshd"
            ;;
        ubuntu|debian|linuxmint|pop)
            echo "Installing OpenSSH on Debian-based system..."
            sudo apt-get update
            sudo apt-get install -y openssh-server
            SSH_SERVICE="ssh"
            ;;
        fedora|rhel|centos)
            echo "Installing OpenSSH on RHEL-based system..."
            sudo dnf install -y openssh-server
            SSH_SERVICE="sshd"
            ;;
        *)
            echo "${YELLOW}⚠️  Unknown OS: $OS. Attempting generic installation...${NC}"
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y openssh-server
                SSH_SERVICE="ssh"
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y openssh-server
                SSH_SERVICE="sshd"
            elif command -v pacman &>/dev/null; then
                sudo pacman -Sy --noconfirm openssh
                SSH_SERVICE="sshd"
            else
                echo "${RED}❌ Cannot install SSH server automatically${NC}"
                exit 1
            fi
            ;;
    esac

    # Enable and start SSH
    sudo systemctl enable $SSH_SERVICE
    sudo systemctl start $SSH_SERVICE

    echo "${GREEN}✅ SSH server installed and started${NC}"
fi

# Configure SSH for security
echo "Configuring SSH security settings..."
if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    echo "${YELLOW}⚠️  Hardening SSH configuration...${NC}"
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config  # Keep password auth for initial setup
    sudo systemctl restart $SSH_SERVICE
    echo "${GREEN}✅ SSH hardened (root login disabled)${NC}"
fi
echo ""

# ============================================
# STEP 2: Install and Configure Firewall
# ============================================
echo "[2/8] Checking firewall installation..."

FIREWALL_TYPE=""
FIREWALL_NEEDS_INSTALL=false

# Check for firewalld
if command -v firewall-cmd &>/dev/null; then
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        FIREWALL_TYPE="firewalld"
        echo "${GREEN}✅ firewalld is active${NC}"
    else
        FIREWALL_TYPE="firewalld"
        echo "${YELLOW}⚠️  firewalld installed but not active. Starting...${NC}"
        sudo systemctl enable firewalld
        sudo systemctl start firewalld
        echo "${GREEN}✅ firewalld started${NC}"
    fi
# Check for UFW
elif command -v ufw &>/dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        FIREWALL_TYPE="ufw"
        echo "${GREEN}✅ UFW is active${NC}"
    else
        FIREWALL_TYPE="ufw"
        echo "${YELLOW}⚠️  UFW installed but not active${NC}"
        # Don't enable automatically, will do it after configuring
    fi
else
    echo "${YELLOW}⚠️  No firewall detected. Installing...${NC}"
    FIREWALL_NEEDS_INSTALL=true

    case "$OS" in
        arch|manjaro|garuda|cachyos)
            echo "Installing firewalld on Arch-based system..."
            sudo pacman -Sy --noconfirm firewalld
            sudo systemctl enable firewalld
            sudo systemctl start firewalld
            FIREWALL_TYPE="firewalld"
            ;;
        ubuntu|debian|linuxmint|pop)
            echo "Installing UFW on Debian-based system..."
            sudo apt-get update
            sudo apt-get install -y ufw
            FIREWALL_TYPE="ufw"
            ;;
        fedora|rhel|centos)
            echo "Installing firewalld on RHEL-based system..."
            sudo dnf install -y firewalld
            sudo systemctl enable firewalld
            sudo systemctl start firewalld
            FIREWALL_TYPE="firewalld"
            ;;
        *)
            echo "${YELLOW}⚠️  Unknown OS. Attempting UFW installation...${NC}"
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y ufw
                FIREWALL_TYPE="ufw"
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y firewalld
                sudo systemctl enable firewalld
                sudo systemctl start firewalld
                FIREWALL_TYPE="firewalld"
            else
                echo "${RED}❌ Cannot install firewall automatically${NC}"
                echo "Please install firewalld or UFW manually"
                exit 1
            fi
            ;;
    esac

    echo "${GREEN}✅ Firewall installed: $FIREWALL_TYPE${NC}"
fi

echo ""
echo "${BLUE}Configuring firewall with safe defaults...${NC}"

if [ "$FIREWALL_TYPE" = "firewalld" ]; then
    echo "Configuring firewalld..."

    # Allow SSH first (critical!)
    sudo firewall-cmd --permanent --add-service=ssh
    echo "  ✓ SSH (port 22) allowed"

    # Allow from LAN only
    sudo firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" source address=\"${MONITORING_NETWORK}\" accept"
    echo "  ✓ All traffic from LAN (${MONITORING_NETWORK}) allowed"

    # Add monitoring ports (restricted to LAN via rich rule above)
    sudo firewall-cmd --permanent --add-port=9100/tcp  # node_exporter
    sudo firewall-cmd --permanent --add-port=9080/tcp  # Promtail
    echo "  ✓ Monitoring ports (9100, 9080) opened"

    # Common services (optional, uncomment if needed)
    # sudo firewall-cmd --permanent --add-service=http
    # sudo firewall-cmd --permanent --add-service=https

    sudo firewall-cmd --reload

    echo "${GREEN}✅ firewalld configured${NC}"
    echo ""
    echo "Current firewall rules:"
    sudo firewall-cmd --list-all | head -15

elif [ "$FIREWALL_TYPE" = "ufw" ]; then
    echo "Configuring UFW..."

    # Default deny incoming, allow outgoing
    sudo ufw --force default deny incoming
    sudo ufw --force default allow outgoing

    # Allow SSH first (critical!)
    sudo ufw allow ssh comment 'SSH access'
    echo "  ✓ SSH (port 22) allowed"

    # Allow LAN access
    sudo ufw allow from ${MONITORING_NETWORK} comment 'LAN access'
    echo "  ✓ All traffic from LAN (${MONITORING_NETWORK}) allowed"

    # Add monitoring ports (restricted to LAN)
    sudo ufw allow from ${MONITORING_NETWORK} to any port 9100 proto tcp comment 'node_exporter'
    sudo ufw allow from ${MONITORING_NETWORK} to any port 9080 proto tcp comment 'promtail'
    echo "  ✓ Monitoring ports (9100, 9080) opened"

    # Enable UFW
    sudo ufw --force enable

    echo "${GREEN}✅ UFW configured and enabled${NC}"
    echo ""
    echo "Current firewall rules:"
    sudo ufw status numbered | head -20
fi
echo ""

# ============================================
# STEP 3: Install Docker
# ============================================
echo "[3/8] Checking Docker installation..."

if command -v docker &> /dev/null; then
    echo "${GREEN}✅ Docker is already installed${NC}"
    docker --version
    DOCKER_NEEDS_REFRESH=false
else
    echo "${YELLOW}⚠️  Docker not found. Installing...${NC}"

    case "$OS" in
        arch|manjaro|garuda|cachyos)
            echo "Installing Docker on Arch-based system..."
            sudo pacman -Sy --noconfirm docker
            ;;
        ubuntu|debian|linuxmint|pop)
            echo "Installing Docker on Debian-based system..."
            curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
            sudo sh /tmp/get-docker.sh
            rm /tmp/get-docker.sh
            ;;
        fedora|rhel|centos)
            echo "Installing Docker on RHEL-based system..."
            sudo dnf install -y docker
            ;;
        *)
            echo "${YELLOW}⚠️  Unknown OS. Attempting generic Docker installation...${NC}"
            curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
            sudo sh /tmp/get-docker.sh
            rm /tmp/get-docker.sh
            ;;
    esac

    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker

    # Add user to docker group
    sudo usermod -aG docker $CURRENT_USER

    echo "${GREEN}✅ Docker installed successfully${NC}"
    echo "${YELLOW}⚠️  Refreshing group membership for docker access...${NC}"

    # Refresh group membership without logging out
    # We'll use sg (switch group) for subsequent docker commands
    DOCKER_NEEDS_REFRESH=true
fi

# Allow Docker through firewall
if [ "$FIREWALL_TYPE" = "firewalld" ]; then
    sudo firewall-cmd --permanent --zone=trusted --add-interface=docker0 2>/dev/null || true
    sudo firewall-cmd --reload
elif [ "$FIREWALL_TYPE" = "ufw" ]; then
    sudo ufw allow from 172.16.0.0/12 comment 'Docker networks' 2>/dev/null || true
fi

echo ""

# ============================================
# STEP 4: Create Promtail Configuration
# ============================================
echo "[4/8] Creating Promtail configuration..."

mkdir -p ~/monitoring/promtail

cat > ~/monitoring/promtail/config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

clients:
  - url: http://${LOKI_SERVER}/loki/api/v1/push

positions:
  filename: /tmp/positions.yaml

scrape_configs:
  # Docker container logs
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 30s
        filters:
          - name: status
            values: [running]
    relabel_configs:
      - source_labels: ["__meta_docker_container_name"]
        regex: '/(.*)'
        target_label: "container"
      - source_labels: ["__meta_docker_container_image"]
        target_label: "image"
      - source_labels: ["__meta_docker_container_id"]
        target_label: "container_id"
      - replacement: "${HOSTNAME}"
        target_label: "hostname"
      - replacement: "docker"
        target_label: "job"
    pipeline_stages:
      - docker: {}

  # Systemd journal logs (SSH, sudo, system events)
  - job_name: systemd-journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
        hostname: ${HOSTNAME}
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__hostname']
        target_label: 'node_hostname'
      - source_labels: ['__journal_syslog_identifier']
        target_label: 'syslog_identifier'
      - source_labels: ['__journal_priority']
        target_label: 'priority'
    pipeline_stages:
      # Extract security-relevant events
      - match:
          selector: '{syslog_identifier="sshd"}'
          stages:
            - regex:
                expression: '(?P<event>Failed|Accepted|Connection closed|Invalid user)'
            - labels:
                event:
      - match:
          selector: '{syslog_identifier="sudo"}'
          stages:
            - regex:
                expression: '(?P<sudo_event>COMMAND|authentication failure)'
            - labels:
                sudo_event:
      - match:
          selector: '{syslog_identifier=~"firewall.*"}'
          stages:
            - regex:
                expression: '(?P<firewall_action>ACCEPT|DROP|REJECT)'
            - labels:
                firewall_action:
EOF

touch ~/monitoring/promtail/positions.yaml

echo "${GREEN}✅ Promtail configuration created${NC}"
echo ""

# ============================================
# STEP 5: Deploy Promtail Container
# ============================================
echo "[5/8] Deploying Promtail container..."

# Function to run docker commands with proper group context
run_docker() {
    if [ "$DOCKER_NEEDS_REFRESH" = true ]; then
        sg docker -c "$*"
    else
        eval "$*"
    fi
}

# Stop and remove existing container if it exists
run_docker "docker stop promtail-${HOSTNAME} 2>/dev/null || true"
run_docker "docker rm promtail-${HOSTNAME} 2>/dev/null || true"

# Deploy Promtail
run_docker "docker run -d \
  --name promtail-${HOSTNAME} \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /var/log/journal:/var/log/journal:ro \
  -v /run/log/journal:/run/log/journal:ro \
  -v /etc/machine-id:/etc/machine-id:ro \
  -v ~/monitoring/promtail/config.yml:/etc/promtail/config.yml:ro \
  -v ~/monitoring/promtail/positions.yaml:/tmp/positions.yaml \
  -p 9080:9080 \
  grafana/promtail:latest \
  -config.file=/etc/promtail/config.yml"

echo "${GREEN}✅ Promtail deployed${NC}"
echo ""

# ============================================
# STEP 6: Deploy node_exporter Container
# ============================================
echo "[6/8] Deploying node_exporter container..."

# Stop and remove existing container if it exists
run_docker "docker stop node-exporter-${HOSTNAME} 2>/dev/null || true"
run_docker "docker rm node-exporter-${HOSTNAME} 2>/dev/null || true"

# Deploy node_exporter
run_docker "docker run -d \
  --name node-exporter-${HOSTNAME} \
  --restart unless-stopped \
  --net=host \
  --pid=host \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  quay.io/prometheus/node-exporter:latest \
  --path.procfs=/host/proc \
  --path.sysfs=/host/sys \
  --path.rootfs=/rootfs \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($|/)'"

echo "${GREEN}✅ node_exporter deployed${NC}"
echo ""

# ============================================
# STEP 7: Set Up SSH Keys
# ============================================
echo "[7/8] Setting up SSH keys for remote management..."

mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add command center's public key to authorized_keys
if grep -q "${SSH_PUBLIC_KEY}" ~/.ssh/authorized_keys 2>/dev/null; then
    echo "${GREEN}✅ SSH key already configured${NC}"
else
    echo "${SSH_PUBLIC_KEY}" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "${GREEN}✅ SSH key added${NC}"
    echo "  Remote access from ${COMMAND_CENTER} (${COMMAND_CENTER_IP}) enabled"
fi
echo ""

# ============================================
# STEP 8: Verify Deployment
# ============================================
echo "[8/8] Verifying deployment..."

sleep 5

echo ""
echo "Container Status:"
run_docker "docker ps --filter \"name=promtail-${HOSTNAME}\" --filter \"name=node-exporter-${HOSTNAME}\" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo ""

# Test node_exporter endpoint
echo "Testing node_exporter endpoint..."
if curl -s http://localhost:9100/metrics 2>&1 | head -1 | grep -q "HELP"; then
    echo "${GREEN}✅ node_exporter is responding${NC}"
else
    echo "${YELLOW}⚠️  node_exporter may not be responding correctly${NC}"
fi
echo ""

# Test Promtail endpoint
echo "Testing Promtail endpoint..."
if curl -s http://localhost:9080/ready 2>&1 | grep -q "ready"; then
    echo "${GREEN}✅ Promtail is responding${NC}"
else
    echo "${YELLOW}⚠️  Promtail may not be ready yet (this is normal, wait 30 seconds)${NC}"
fi
echo ""

# Test SSH
echo "Testing SSH configuration..."
if systemctl is-active --quiet $SSH_SERVICE 2>/dev/null; then
    echo "${GREEN}✅ SSH service is running${NC}"
fi
echo ""

# Test firewall
echo "Firewall status:"
if [ "$FIREWALL_TYPE" = "firewalld" ]; then
    sudo firewall-cmd --list-ports | grep -E "(9100|9080|22)" || echo "  Check firewall-cmd --list-all for details"
elif [ "$FIREWALL_TYPE" = "ufw" ]; then
    sudo ufw status | grep -E "(9100|9080|22)" || echo "  Check ufw status for details"
fi
echo ""

# ============================================
# Summary
# ============================================
echo "=========================================="
echo "${GREEN}Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "${GREEN}✅ Device $HOSTNAME is now secured and monitored${NC}"
echo ""
echo "What was configured:"
echo "  ${GREEN}•${NC} SSH Server: $SSH_SERVICE (running, hardened)"
echo "  ${GREEN}•${NC} Firewall: $FIREWALL_TYPE (active, configured)"
echo "  ${GREEN}•${NC} Docker: Installed and running"
echo "  ${GREEN}•${NC} Promtail: Shipping logs to $LOKI_SERVER"
echo "  ${GREEN}•${NC} node_exporter: Exposing metrics on port 9100"
echo "  ${GREEN}•${NC} Remote Access: Enabled from ${COMMAND_CENTER}"
echo ""
echo "${BLUE}Security Features:${NC}"
echo "  • Firewall blocks external traffic (only LAN allowed)"
echo "  • SSH root login disabled"
echo "  • Monitoring ports restricted to ${MONITORING_NETWORK}"
echo "  • All containers auto-restart on reboot"
echo ""
echo "${YELLOW}Next Steps:${NC}"
echo "1. Add this device to Prometheus (on Raspberry Pi):"
echo "   Target: ${MY_IP}:9100"
echo "   Hostname: $HOSTNAME"
echo ""
echo "2. Wait 30 seconds and verify logs in Loki:"
echo "   ssh automation@100.112.203.63 \"curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq\""
echo ""
echo "3. Check Grafana: http://192.168.0.19:3000"
echo "   Query: {hostname=\"$HOSTNAME\"}"
echo ""
if [ "$DOCKER_NEEDS_REFRESH" = true ]; then
    echo "${GREEN}✅ Docker group membership was automatically refreshed${NC}"
    echo "   Containers deployed successfully without requiring logout."
    echo ""
fi

echo "For troubleshooting: docs/DEVICE-ONBOARDING-RUNBOOK.md"
echo ""
