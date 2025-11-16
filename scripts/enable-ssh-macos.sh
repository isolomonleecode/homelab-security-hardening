#!/bin/bash
# Enable SSH on macOS
# This allows remote access via SSH

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "macOS SSH Setup"
echo "=========================================="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "${RED}✗${NC} This script is for macOS only"
    exit 1
fi

HOSTNAME=$(hostname -s)
CURRENT_USER=$(whoami)
IP_ADDR=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "N/A")

echo "Current system:"
echo "  Hostname: $HOSTNAME"
echo "  User: $CURRENT_USER"
echo "  IP Address: $IP_ADDR"
echo ""

# Check current SSH status
CURRENT_STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null | grep -o "On\|Off")

echo "Current SSH status: $CURRENT_STATUS"
echo ""

if [ "$CURRENT_STATUS" = "On" ]; then
    echo "${GREEN}✓${NC} SSH is already enabled"
    echo ""
    echo "You can connect with:"
    echo "  ssh $CURRENT_USER@$IP_ADDR"
    echo "  ssh $CURRENT_USER@$HOSTNAME.local"
    exit 0
fi

# Confirm before enabling
read -p "Enable SSH (Remote Login)? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Enable SSH
echo ""
echo "Enabling SSH..."
sudo systemsetup -setremotelogin on

# Verify
sleep 2
NEW_STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null | grep -o "On\|Off")

if [ "$NEW_STATUS" = "On" ]; then
    echo "${GREEN}✓${NC} SSH enabled successfully"
else
    echo "${RED}✗${NC} Failed to enable SSH"
    exit 1
fi

echo ""
echo "=========================================="
echo "${GREEN}SSH Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "You can now connect remotely:"
echo "  From local network: ssh $CURRENT_USER@$IP_ADDR"
echo "  Via Bonjour:        ssh $CURRENT_USER@$HOSTNAME.local"
echo ""
echo "Security recommendations:"
echo "  1. Use SSH keys instead of passwords"
echo "  2. Configure firewall to allow SSH only from trusted IPs"
echo "  3. Consider changing the default SSH port (22)"
echo ""
echo "To disable SSH later:"
echo "  sudo systemsetup -setremotelogin off"
echo ""
