#!/bin/bash

# Wazuh Agent Installation Script for Arch Linux
# Author: Latrent Childs
# Purpose: Install Wazuh agent to monitor host system

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════"
echo "  Wazuh Agent Installation for Arch Linux"
echo "  Author: Latrent Childs | Security+ Certified"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Manager IP
MANAGER_IP="192.168.0.52"

echo -e "${YELLOW}[INFO]${NC} Manager IP: $MANAGER_IP"
echo ""

# Create necessary directories
echo -e "${YELLOW}[INFO]${NC} Creating Wazuh directories..."
sudo mkdir -p /var/ossec/{bin,etc,logs,queue,var,tmp}
sudo mkdir -p /var/ossec/etc/shared

# Download compiled agent
echo -e "${YELLOW}[INFO]${NC} Downloading Wazuh agent..."
cd /tmp

# Try to download pre-compiled agent
if ! wget -q https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.0-1_amd64.deb; then
    echo -e "${RED}[ERROR]${NC} Failed to download agent package"
    exit 1
fi

# Extract DEB package
echo -e "${YELLOW}[INFO]${NC} Extracting package..."
ar x wazuh-agent_4.9.0-1_amd64.deb
tar -xzf data.tar.gz -C /

echo -e "${GREEN}[✓]${NC} Agent files extracted"

# Create wazuh user
echo -e "${YELLOW}[INFO]${NC} Creating wazuh user..."
if ! id -u wazuh >/dev/null 2>&1; then
    sudo groupadd -r wazuh
    sudo useradd -r -g wazuh -d /var/ossec -s /sbin/nologin wazuh
fi

# Set ownership
echo -e "${YELLOW}[INFO]${NC} Setting permissions..."
sudo chown -R wazuh:wazuh /var/ossec
sudo chmod 750 /var/ossec

# Configure manager IP
echo -e "${YELLOW}[INFO]${NC} Configuring manager IP..."
sudo sed -i "s/<address>MANAGER_IP<\/address>/<address>$MANAGER_IP<\/address>/g" /var/ossec/etc/ossec.conf

# Create systemd service
echo -e "${YELLOW}[INFO]${NC} Creating systemd service..."
sudo tee /etc/systemd/system/wazuh-agent.service > /dev/null << 'EOF'
[Unit]
Description=Wazuh agent
After=network.target

[Service]
Type=simple
ExecStart=/var/ossec/bin/wazuh-control start
ExecStop=/var/ossec/bin/wazuh-control stop
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

echo ""
echo -e "${GREEN}[✓]${NC} Wazuh agent installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Start agent:  sudo systemctl start wazuh-agent"
echo "  2. Enable agent: sudo systemctl enable wazuh-agent"
echo "  3. Check status: sudo systemctl status wazuh-agent"
echo "  4. View logs:    sudo tail -f /var/ossec/logs/ossec.log"
echo ""
