#!/bin/bash
# Setup Tailscale to use Pi-hole as DNS server
# This allows .homelab domains to work on all Tailscale devices

set -e

PIHOLE_HOST="automation@100.112.203.63"
PIHOLE_TAILSCALE_IP="100.112.203.63"

echo "=== Tailscale + Pi-hole DNS Setup ==="
echo ""

# Step 1: Deploy Tailscale DNS forwarding config
echo "[1/3] Deploying Tailscale DNS forwarding to Pi-hole..."
scp configs/pihole/05-tailscale-dns.conf ${PIHOLE_HOST}:/tmp/
ssh ${PIHOLE_HOST} "sudo cp /tmp/05-tailscale-dns.conf /data/pihole/data/dnsmasq/05-tailscale-dns.conf"
ssh ${PIHOLE_HOST} "docker exec pihole pihole reloaddns"
echo "✅ Pi-hole configured to forward .ts.net domains to Tailscale"
echo ""

# Step 2: Instructions for Tailscale admin console
echo "[2/3] Configure Tailscale global nameserver..."
echo ""
echo "Please complete these steps in the Tailscale admin console:"
echo "1. Go to: https://login.tailscale.com/admin/dns"
echo "2. Under 'Global nameservers', click 'Add nameserver'"
echo "3. Enter: ${PIHOLE_TAILSCALE_IP}"
echo "4. Click 'Save'"
echo "5. Under 'Override local DNS', toggle it ON"
echo ""
read -p "Press Enter once you've completed the Tailscale admin console steps..."
echo ""

# Step 3: Enable on local device
echo "[3/3] Configuring local device to accept Tailscale DNS..."
sudo tailscale set --accept-dns=true
echo "✅ Local device configured"
echo ""

# Verification
echo "=== Verification ==="
echo ""
echo "Testing DNS resolution..."
echo ""

echo "1. Checking .homelab domain:"
nslookup vault.homelab || echo "⚠️  vault.homelab not resolving yet (may take a moment)"
echo ""

echo "2. Checking .ts.net domain:"
nslookup sweetrpi-desktop.tailc12764.ts.net || echo "⚠️  .ts.net domain not resolving"
echo ""

echo "3. Current DNS server:"
cat /etc/resolv.conf | grep nameserver
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Your Tailscale devices should now be able to resolve:"
echo "  ✅ .homelab domains (via Pi-hole custom DNS)"
echo "  ✅ .ts.net domains (forwarded to Tailscale)"
echo "  ✅ Ad-blocking on all Tailscale devices!"
echo ""
echo "If DNS isn't working yet:"
echo "  - Wait 1-2 minutes for DNS propagation"
echo "  - Restart your Tailscale daemon: sudo systemctl restart tailscaled"
echo "  - Check Pi-hole logs: http://pihole.homelab/admin"
echo ""
echo "Test URLs:"
echo "  https://vault.homelab:8443"
echo "  https://sweetrpi-desktop.tailc12764.ts.net:8443"
echo "  http://jellyfin.homelab:8096"
echo ""
