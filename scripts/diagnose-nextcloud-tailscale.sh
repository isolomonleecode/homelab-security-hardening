#!/bin/bash

# Nextcloud + Tailscale Connectivity Diagnostic Script
# Run this on the Unraid server (192.168.0.51 / capcorplee)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Nextcloud + Tailscale Diagnostics${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Function to test with result
test_check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

echo -e "${YELLOW}[1/10] System Information${NC}"
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo "Uptime: $(uptime -p)"
echo ""

echo -e "${YELLOW}[2/10] Network Interfaces${NC}"
ip addr show | grep -E "^[0-9]|inet " | grep -v "127.0.0.1"
echo ""

echo -e "${YELLOW}[3/10] Tailscale Status${NC}"
if command -v tailscale &> /dev/null; then
    echo "Tailscale IP: $(tailscale ip -4)"
    echo "Tailscale Hostname: $(tailscale status --json | jq -r '.Self.DNSName')"
    echo ""
    echo "Connected Tailscale Peers (first 5):"
    tailscale status | head -6
    echo ""
    echo "Tailscale Routes:"
    tailscale status --json | jq -r '.Self.AllowedIPs[]' 2>/dev/null || echo "No advertised routes"
    test_check "Tailscale is running"
else
    echo -e "${RED}Tailscale not found${NC}"
fi
echo ""

echo -e "${YELLOW}[4/10] Nextcloud Containers${NC}"
docker ps --filter "name=nextcloud" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
docker ps --filter "name=nextcloud" --format "{{.Names}}" | while read container; do
    echo "Container: $container"
    echo "  Network: $(docker inspect $container --format '{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}')"
    echo "  IP: $(docker inspect $container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}')"
done
echo ""

echo -e "${YELLOW}[5/10] Nextcloud Network Accessibility${NC}"
NEXTCLOUD_PORT=8082
echo "Testing Nextcloud on port $NEXTCLOUD_PORT..."

# Test from localhost
echo -n "From localhost (127.0.0.1): "
if curl -s -o /dev/null -w "%{http_code}" -m 5 http://127.0.0.1:$NEXTCLOUD_PORT | grep -q "200\|302\|301"; then
    echo -e "${GREEN}✓ Accessible${NC}"
else
    echo -e "${RED}✗ Not accessible${NC}"
fi

# Test from LAN IP
LAN_IP=$(ip addr show br0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
echo -n "From LAN IP ($LAN_IP): "
if curl -s -o /dev/null -w "%{http_code}" -m 5 http://$LAN_IP:$NEXTCLOUD_PORT | grep -q "200\|302\|301"; then
    echo -e "${GREEN}✓ Accessible${NC}"
else
    echo -e "${RED}✗ Not accessible${NC}"
fi

# Test from Tailscale IP
TS_IP=$(tailscale ip -4 2>/dev/null)
if [ -n "$TS_IP" ]; then
    echo -n "From Tailscale IP ($TS_IP): "
    if curl -s -o /dev/null -w "%{http_code}" -m 5 http://$TS_IP:$NEXTCLOUD_PORT | grep -q "200\|302\|301"; then
        echo -e "${GREEN}✓ Accessible${NC}"
    else
        echo -e "${RED}✗ Not accessible${NC}"
    fi
fi
echo ""

echo -e "${YELLOW}[6/10] Nextcloud Trusted Domains${NC}"
NEXTCLOUD_CONTAINER=$(docker ps --filter "name=nextcloud" --filter "name=apache\|nextcloud\|saml" --format "{{.Names}}" | head -1)
if [ -n "$NEXTCLOUD_CONTAINER" ]; then
    echo "Checking $NEXTCLOUD_CONTAINER config..."
    docker exec $NEXTCLOUD_CONTAINER cat /var/www/html/config/config.php 2>/dev/null | grep -A 10 "trusted_domains" || echo "Could not read config.php"
else
    echo "No Nextcloud container found"
fi
echo ""

echo -e "${YELLOW}[7/10] Firewall Rules (iptables)${NC}"
echo "NAT rules for port $NEXTCLOUD_PORT:"
iptables -t nat -L DOCKER -n -v | grep $NEXTCLOUD_PORT || echo "No NAT rules found"
echo ""
echo "FORWARD rules for Tailscale:"
iptables -L FORWARD -n -v | grep -E "tailscale|100\..*" | head -5 || echo "No Tailscale FORWARD rules"
echo ""

echo -e "${YELLOW}[8/10] DNS Resolution Test${NC}"
echo "Testing DNS from container..."
if [ -n "$NEXTCLOUD_CONTAINER" ]; then
    echo "Resolving google.com:"
    docker exec $NEXTCLOUD_CONTAINER nslookup google.com 2>/dev/null | tail -3 || echo "nslookup not available"
fi
echo ""

echo -e "${YELLOW}[9/10] Nextcloud Logs (last 10 lines)${NC}"
if [ -n "$NEXTCLOUD_CONTAINER" ]; then
    docker logs $NEXTCLOUD_CONTAINER --tail 10 2>&1
fi
echo ""

echo -e "${YELLOW}[10/10] Upload Test${NC}"
if [ -n "$NEXTCLOUD_CONTAINER" ]; then
    echo "Checking upload directory permissions..."
    docker exec $NEXTCLOUD_CONTAINER ls -la /var/www/html/data 2>/dev/null | head -5 || echo "Cannot access data directory"
    echo ""
    echo "Checking PHP upload settings..."
    docker exec $NEXTCLOUD_CONTAINER php -i 2>/dev/null | grep -E "upload_max_filesize|post_max_size|max_execution_time" || echo "Cannot check PHP settings"
fi
echo ""

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Diagnostic Summary${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "Next steps based on findings:"
echo "1. If Tailscale IP test fails: Check trusted_domains in config.php"
echo "2. If localhost works but LAN/Tailscale fails: Check firewall/iptables"
echo "3. If uploads fail: Check PHP settings and data directory permissions"
echo "4. Check full logs: docker logs $NEXTCLOUD_CONTAINER | tail -100"
echo ""
echo "To test from remote Tailscale client:"
echo "  curl -v http://capcorplee.tailc12764.ts.net:$NEXTCLOUD_PORT"
echo "  curl -v http://100.69.191.4:$NEXTCLOUD_PORT"
echo ""
