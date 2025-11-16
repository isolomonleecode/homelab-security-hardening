#!/bin/bash
#
# Fix Vaultwarden Port 1776 Access
# This script helps restore access to Vaultwarden that was blocked by UFW firewall
#

set -e

echo "=== Vaultwarden Access Fix Script ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run with sudo: sudo $0"
    exit 1
fi

# Show current UFW status for port 1776
echo "📋 Current UFW rules for port 1776:"
ufw status | grep -E "(1776|Status)" || echo "   No rules found for port 1776"
echo ""

# Check if port 8443 (Caddy HTTPS) is accessible via Tailscale
echo "📋 Current UFW rules for port 8443 (Caddy HTTPS → Vaultwarden):"
ufw status | grep -E "(8443|Status)" || echo "   No rules found for port 8443"
echo ""

# Display options
echo "=== Access Options ==="
echo ""
echo "1. Allow LAN access to port 1776 (192.168.0.0/24) - EASIEST"
echo "2. Check Tailscale access via port 8443 (100.0.0.0/8) - RECOMMENDED"
echo "3. Show current UFW status (detailed)"
echo "4. Exit"
echo ""
read -p "Select option [1-4]: " choice

case $choice in
    1)
        echo ""
        echo "🔓 Adding UFW rule to allow LAN access to port 1776..."
        ufw allow from 192.168.0.0/24 to any port 1776 proto tcp comment 'Vaultwarden from LAN'
        echo "✅ Rule added successfully!"
        echo ""
        echo "⚠️  SECURITY NOTE: Port 1776 is now accessible from your LAN."
        echo "   This is less secure than Tailscale-only access."
        echo ""
        echo "🌐 You can now access Vaultwarden at: http://192.168.0.19:1776"
        ;;
    2)
        echo ""
        echo "🔍 Checking Tailscale access configuration..."
        echo ""
        echo "To access Vaultwarden via Tailscale (recommended):"
        echo "1. Ensure you're connected to Tailscale VPN"
        echo "2. Access via: https://<your-tailscale-domain>:8443"
        echo "   OR via Tailscale IP on port 8443"
        echo ""
        echo "Current UFW rule for 8443:"
        ufw status | grep 8443 || echo "   No rule found - checking if it needs to be added..."
        echo ""
        echo "If you want to add Tailscale access to port 1776 directly:"
        read -p "Add Tailscale access to port 1776? (y/N): " add_tailscale
        if [[ "$add_tailscale" =~ ^[Yy]$ ]]; then
            ufw allow from 100.0.0.0/8 to any port 1776 proto tcp comment 'Vaultwarden from Tailscale'
            echo "✅ Tailscale access rule added for port 1776"
        fi
        ;;
    3)
        echo ""
        echo "📋 Full UFW Status:"
        echo ""
        ufw status verbose
        echo ""
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "📋 Updated UFW status for relevant ports:"
ufw status | grep -E "(1776|8443|Status)" || ufw status | head -5
echo ""

echo "✅ Done! Try accessing Vaultwarden now."



