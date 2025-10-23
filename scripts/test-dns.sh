#!/bin/bash
#
# DNS Configuration Test Script
# Tests Pi-hole local DNS records for homelab services
#
# Usage: ./test-dns.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PIHOLE_IP="192.168.0.19"
UNRAID_IP="192.168.0.51"

echo "========================================="
echo "  Homelab DNS Configuration Test"
echo "========================================="
echo ""
echo "Testing Pi-hole at: $PIHOLE_IP"
echo "Expected IP: $UNRAID_IP"
echo ""

# Array of services to test
declare -a services=(
    "unraid.homelab"
    "jellyfin.homelab"
    "radarr.homelab"
    "sonarr.homelab"
    "lidarr.homelab"
    "readarr.homelab"
    "bazarr.homelab"
    "prowlarr.homelab"
    "overseerr.homelab"
    "homarr.homelab"
    "krusader.homelab"
    "adminer.homelab"
    "metube.homelab"
    "npm.homelab"
)

# Counters
passed=0
failed=0

# Test each service
for domain in "${services[@]}"; do
    # Query Pi-hole for the domain
    result=$(nslookup "$domain" "$PIHOLE_IP" 2>&1 | grep "Address:" | tail -1 | awk '{print $2}')

    if [ "$result" == "$UNRAID_IP" ]; then
        echo -e "${GREEN}✓${NC} $domain → $result"
        ((passed++))
    else
        echo -e "${RED}✗${NC} $domain → ${YELLOW}FAILED${NC} (got: $result)"
        ((failed++))
    fi
done

# Test Pi-hole itself
domain="pihole.homelab"
result=$(nslookup "$domain" "$PIHOLE_IP" 2>&1 | grep "Address:" | tail -1 | awk '{print $2}')
if [ "$result" == "$PIHOLE_IP" ]; then
    echo -e "${GREEN}✓${NC} $domain → $result"
    ((passed++))
else
    echo -e "${RED}✗${NC} $domain → ${YELLOW}FAILED${NC} (got: $result)"
    ((failed++))
fi

echo ""
echo "========================================="
echo "  Test Results"
echo "========================================="
echo -e "${GREEN}Passed:${NC} $passed"
echo -e "${RED}Failed:${NC} $failed"
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}All DNS records configured correctly!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test in browser: http://jellyfin.homelab:8096"
    echo "2. Update your bookmarks to use domain names"
    echo "3. Consider setting up reverse proxy for HTTPS"
    exit 0
else
    echo -e "${YELLOW}Some DNS records are missing or misconfigured.${NC}"
    echo ""
    echo "To fix:"
    echo "1. Login to Pi-hole admin: http://$PIHOLE_IP/admin"
    echo "2. Go to: Local DNS → DNS Records"
    echo "3. Add missing records from docs/03-pihole-dns-configuration.md"
    exit 1
fi
