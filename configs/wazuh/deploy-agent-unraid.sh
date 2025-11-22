#!/bin/bash

# Wazuh Agent Deployment Script for Unraid
# Author: Latrent Childs
# Purpose: Install Wazuh agent on Unraid OS (Slackware-based)

set -e

WAZUH_MANAGER="192.168.0.52"
AGENT_NAME=$(hostname)

echo "=========================================="
echo "  Wazuh Agent Installation - Unraid OS"
echo "  Manager: $WAZUH_MANAGER"
echo "  Agent: $AGENT_NAME"
echo "=========================================="
echo ""

# Install ar utility (needed for DEB extraction)
echo "[1/6] Installing binutils for DEB extraction..."
if ! command -v ar &> /dev/null; then
    # Install binutils package
    slackpkg -default_answer=y -batch=on install binutils || \
    wget http://slackware.osuosl.org/slackware64-15.0/slackware64/d/binutils-2.37-x86_64-1.txz && \
    installpkg binutils-2.37-x86_64-1.txz
fi

# Download Wazuh agent
echo "[2/6] Downloading Wazuh agent package..."
cd /tmp
wget -q --show-progress https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.0-1_amd64.deb

# Extract DEB package
echo "[3/6] Extracting package..."
ar x wazuh-agent_4.9.0-1_amd64.deb
tar -xzf data.tar.gz -C /

# Create wazuh user
echo "[4/6] Creating wazuh user..."
if ! id -u wazuh >/dev/null 2>&1; then
    groupadd -r wazuh
    useradd -r -g wazuh -d /var/ossec -s /sbin/nologin wazuh
fi

# Set permissions
chown -R wazuh:wazuh /var/ossec
chmod 750 /var/ossec

# Configure manager IP
echo "[5/6] Configuring Wazuh manager..."
sed -i "s/<address>MANAGER_IP<\/address>/<address>$WAZUH_MANAGER<\/address>/" /var/ossec/etc/ossec.conf

# Verify configuration
if grep -q "$WAZUH_MANAGER" /var/ossec/etc/ossec.conf; then
    echo "✓ Manager IP configured: $WAZUH_MANAGER"
else
    echo "✗ Failed to configure manager IP"
    exit 1
fi

# Start agent
echo "[6/6] Starting Wazuh agent..."
/var/ossec/bin/wazuh-control start

# Check status
sleep 3
if /var/ossec/bin/wazuh-control status | grep -q "wazuh-agentd is running"; then
    echo ""
    echo "=========================================="
    echo "  ✓ Wazuh Agent Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Agent Name: $AGENT_NAME"
    echo "Manager IP: $WAZUH_MANAGER"
    echo "Status: Running"
    echo ""
    echo "Check dashboard in 60 seconds:"
    echo "  https://$WAZUH_MANAGER → Agents"
    echo ""
else
    echo ""
    echo "✗ Agent failed to start. Check logs:"
    echo "  /var/ossec/logs/ossec.log"
fi

# Cleanup
rm -f /tmp/wazuh-agent_4.9.0-1_amd64.deb /tmp/control.tar.gz /tmp/data.tar.gz /tmp/debian-binary /tmp/_gpgbuilder
