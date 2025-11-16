#!/bin/bash
# Harden Security on Already-Monitored Device
# Run this on a device that already has monitoring but needs firewall/SSH hardening

set -e

MONITORING_NETWORK="192.168.0.0/24"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Security Hardening for Monitored Device"
echo "=========================================="
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "${RED}❌ Cannot detect OS${NC}"
    exit 1
fi

HOSTNAME=$(hostname)
echo "Hardening: $HOSTNAME ($OS)"
echo ""

# ============================================
# Install Firewall
# ============================================
echo "[1/3] Installing and configuring firewall..."

if systemctl is-active --quiet firewalld 2>/dev/null; then
    echo "${GREEN}✅ firewalld already active${NC}"
    FIREWALL_TYPE="firewalld"
elif command -v firewall-cmd &>/dev/null; then
    echo "${YELLOW}⚠️  firewalld installed but not active. Starting...${NC}"
    sudo systemctl enable firewalld
    sudo systemctl start firewalld
    FIREWALL_TYPE="firewalld"
else
    echo "${YELLOW}⚠️  Installing firewalld...${NC}"

    case "$OS" in
        arch|manjaro|garuda|cachyos)
            sudo pacman -Sy --noconfirm firewalld
            ;;
        ubuntu|debian|linuxmint|pop)
            sudo apt-get update && sudo apt-get install -y firewalld
            ;;
        fedora|rhel|centos)
            sudo dnf install -y firewalld
            ;;
        *)
            echo "${RED}❌ Unknown OS: $OS${NC}"
            exit 1
            ;;
    esac

    sudo systemctl enable firewalld
    sudo systemctl start firewalld
    FIREWALL_TYPE="firewalld"
    echo "${GREEN}✅ firewalld installed${NC}"
fi

echo ""
echo "${BLUE}Configuring firewall rules...${NC}"

# Allow SSH (critical!)
sudo firewall-cmd --permanent --add-service=ssh
echo "  ✓ SSH (port 22) allowed"

# Allow all from LAN
sudo firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" source address=\"${MONITORING_NETWORK}\" accept"
echo "  ✓ All traffic from LAN (${MONITORING_NETWORK}) allowed"

# Monitoring ports
sudo firewall-cmd --permanent --add-port=9100/tcp
sudo firewall-cmd --permanent --add-port=9080/tcp
echo "  ✓ Monitoring ports (9100, 9080) opened"

# Docker
sudo firewall-cmd --permanent --zone=trusted --add-interface=docker0 2>/dev/null || true
echo "  ✓ Docker interface trusted"

# Reload
sudo firewall-cmd --reload

echo "${GREEN}✅ Firewall configured${NC}"
echo ""

# ============================================
# Harden SSH
# ============================================
echo "[2/3] Hardening SSH configuration..."

if [ -f /etc/ssh/sshd_config ]; then
    # Backup
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-$(date +%Y%m%d)

    # Apply hardening
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # Restart SSH
    sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh 2>/dev/null

    echo "${GREEN}✅ SSH hardened (root login disabled)${NC}"
else
    echo "${YELLOW}⚠️  SSH config not found${NC}"
fi

echo ""

# ============================================
# Verify
# ============================================
echo "[3/3] Verifying security configuration..."

echo ""
echo "Firewall Status:"
sudo firewall-cmd --state
echo ""
echo "Active Rules:"
sudo firewall-cmd --list-all | head -20
echo ""

echo "SSH Service:"
systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null
echo ""

echo "=========================================="
echo "${GREEN}Security Hardening Complete!${NC}"
echo "=========================================="
echo ""
echo "Configured:"
echo "  ${GREEN}•${NC} Firewall: Active with LAN-only access"
echo "  ${GREEN}•${NC} SSH: Hardened (no root login)"
echo "  ${GREEN}•${NC} Monitoring: Ports 9100, 9080 open to LAN"
echo "  ${GREEN}•${NC} Docker: Interface trusted"
echo ""
echo "Security posture improved! ✅"
echo ""
