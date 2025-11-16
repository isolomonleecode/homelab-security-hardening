#!/bin/bash
# Local Device Monitoring Setup Script
# Run this script ON the device you want to monitor (not from capcorp9000)
# This script will:
# 1. Install Docker (if needed)
# 2. Deploy Promtail + node_exporter containers
# 3. Configure firewall for monitoring
# 4. Set up SSH keys for remote management

set -e

# Configuration
LOKI_SERVER="192.168.0.19:3100"
PROMETHEUS_SERVER="192.168.0.19:9090"
MONITORING_NETWORK="192.168.0.0/24"
COMMAND_CENTER="capcorp9000"
COMMAND_CENTER_IP="192.168.0.52"
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICe80VCDZRggo/cDaEdpEZIM7MakB4PxTT4UfVemakjo ssjlox@capcorp9000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Home SOC: Local Device Monitoring Setup"
echo "=========================================="
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
else
    echo "${RED}❌ Cannot detect OS. /etc/os-release not found${NC}"
    exit 1
fi

HOSTNAME=$(hostname)
CURRENT_USER=$(whoami)

echo "Detected Configuration:"
echo "  Hostname: $HOSTNAME"
echo "  User: $CURRENT_USER"
echo "  OS: $OS $OS_VERSION"
echo "  Loki Server: $LOKI_SERVER"
echo ""
read -p "Continue with setup? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi
echo ""

# ============================================
# STEP 1: Install Docker
# ============================================
echo "[1/7] Checking Docker installation..."

if command -v docker &> /dev/null; then
    echo "${GREEN}✅ Docker is already installed${NC}"
    docker --version
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
            echo "${RED}❌ Unsupported OS: $OS${NC}"
            echo "Please install Docker manually and re-run this script."
            exit 1
            ;;
    esac

    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker

    # Add user to docker group
    sudo usermod -aG docker $CURRENT_USER

    echo "${GREEN}✅ Docker installed successfully${NC}"
    echo "${YELLOW}⚠️  You may need to log out and back in for group changes to take effect${NC}"
fi
echo ""

# ============================================
# STEP 2: Create Promtail Configuration
# ============================================
echo "[2/7] Creating Promtail configuration..."

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
EOF

touch ~/monitoring/promtail/positions.yaml

echo "${GREEN}✅ Promtail configuration created${NC}"
echo ""

# ============================================
# STEP 3: Deploy Promtail Container
# ============================================
echo "[3/7] Deploying Promtail container..."

# Stop and remove existing container if it exists
docker stop promtail-${HOSTNAME} 2>/dev/null || true
docker rm promtail-${HOSTNAME} 2>/dev/null || true

# Deploy Promtail
docker run -d \
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
  -config.file=/etc/promtail/config.yml

echo "${GREEN}✅ Promtail deployed${NC}"
echo ""

# ============================================
# STEP 4: Deploy node_exporter Container
# ============================================
echo "[4/7] Deploying node_exporter container..."

# Stop and remove existing container if it exists
docker stop node-exporter-${HOSTNAME} 2>/dev/null || true
docker rm node-exporter-${HOSTNAME} 2>/dev/null || true

# Deploy node_exporter
docker run -d \
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
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($|/)'

echo "${GREEN}✅ node_exporter deployed${NC}"
echo ""

# ============================================
# STEP 5: Configure Firewall
# ============================================
echo "[5/7] Configuring firewall..."

FIREWALL_CONFIGURED=false

# Check for firewalld
if systemctl is-active --quiet firewalld 2>/dev/null; then
    echo "Detected: firewalld"

    # Add rules for node_exporter and Promtail
    sudo firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" source address=\"${MONITORING_NETWORK}\" port port=\"9100\" protocol=\"tcp\" accept" 2>/dev/null || \
    sudo firewall-cmd --permanent --zone=public --add-port=9100/tcp

    sudo firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" source address=\"${MONITORING_NETWORK}\" port port=\"9080\" protocol=\"tcp\" accept" 2>/dev/null || \
    sudo firewall-cmd --permanent --zone=public --add-port=9080/tcp

    sudo firewall-cmd --reload

    echo "${GREEN}✅ firewalld configured${NC}"
    echo "Open ports:"
    sudo firewall-cmd --list-ports | grep -E "(9100|9080)"
    FIREWALL_CONFIGURED=true

# Check for UFW
elif command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "Detected: UFW"

    sudo ufw allow from ${MONITORING_NETWORK} to any port 9100 proto tcp comment 'node_exporter metrics'
    sudo ufw allow from ${MONITORING_NETWORK} to any port 9080 proto tcp comment 'promtail logs'

    echo "${GREEN}✅ UFW configured${NC}"
    sudo ufw status numbered | grep -E "(9100|9080)"
    FIREWALL_CONFIGURED=true

else
    echo "${YELLOW}⚠️  No firewall detected (firewalld or UFW)${NC}"
    echo "Ports 9100 and 9080 should be accessible without additional configuration"
    FIREWALL_CONFIGURED=true
fi
echo ""

# ============================================
# STEP 6: Set Up SSH Keys
# ============================================
echo "[6/7] Setting up SSH keys for remote management..."

mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add command center's public key to authorized_keys
if grep -q "${SSH_PUBLIC_KEY}" ~/.ssh/authorized_keys 2>/dev/null; then
    echo "${GREEN}✅ SSH key already configured${NC}"
else
    echo "${SSH_PUBLIC_KEY}" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "${GREEN}✅ SSH key added${NC}"
fi

# Enable SSH service if not running
if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
    echo "${GREEN}✅ SSH service is running${NC}"
else
    echo "${YELLOW}⚠️  Enabling SSH service...${NC}"
    sudo systemctl enable sshd 2>/dev/null || sudo systemctl enable ssh 2>/dev/null || true
    sudo systemctl start sshd 2>/dev/null || sudo systemctl start ssh 2>/dev/null || true
    echo "${GREEN}✅ SSH service started${NC}"
fi
echo ""

# ============================================
# STEP 7: Verify Deployment
# ============================================
echo "[7/7] Verifying deployment..."

sleep 5

echo ""
echo "Container Status:"
docker ps --filter "name=promtail-${HOSTNAME}" --filter "name=node-exporter-${HOSTNAME}" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""

# Test node_exporter endpoint
echo "Testing node_exporter endpoint..."
if curl -s http://localhost:9100/metrics | head -1 | grep -q "HELP"; then
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

# ============================================
# Summary
# ============================================
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "${GREEN}✅ Monitoring agents deployed on $HOSTNAME${NC}"
echo ""
echo "What was configured:"
echo "  • Promtail: Shipping logs to Loki at $LOKI_SERVER"
echo "  • node_exporter: Exposing metrics on port 9100"
echo "  • Firewall: Ports 9100 and 9080 opened for ${MONITORING_NETWORK}"
echo "  • SSH: Remote access from ${COMMAND_CENTER} enabled"
echo ""
echo "Next Steps:"
echo "1. Add this device to Prometheus scrape config on Raspberry Pi"
echo "   Target: $(hostname -I | awk '{print $1}'):9100"
echo "   Hostname: $HOSTNAME"
echo ""
echo "2. Wait 30 seconds and verify logs in Loki:"
echo "   ssh automation@100.112.203.63 \"curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq\""
echo ""
echo "3. Check Grafana: http://192.168.0.19:3000"
echo "   Query: {hostname=\"$HOSTNAME\"}"
echo ""
echo "For troubleshooting, see: docs/DEVICE-ONBOARDING-RUNBOOK.md"
echo ""
