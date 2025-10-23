#!/bin/bash
#
# Add Local DNS Records to Pi-hole
# Configures custom DNS entries for homelab services
#
# Usage: ./add-pihole-dns.sh
#

set -e

PIHOLE_HOST="sweetrpi@192.168.0.19"
UNRAID_IP="192.168.0.51"
PIHOLE_IP="192.168.0.19"

echo "========================================="
echo "  Adding DNS Records to Pi-hole"
echo "========================================="
echo ""

# Array of services (domain name only, no .homelab suffix yet)
declare -A services=(
    ["unraid"]="Unraid WebGUI"
    ["jellyfin"]="Media streaming server"
    ["radarr"]="Movie management"
    ["sonarr"]="TV show management"
    ["lidarr"]="Music management"
    ["readarr"]="Book management"
    ["bazarr"]="Subtitle management"
    ["prowlarr"]="Indexer manager"
    ["overseerr"]="Media requests"
    ["homarr"]="Dashboard"
    ["krusader"]="File manager"
    ["adminer"]="Database admin"
    ["metube"]="Video downloader"
    ["npm"]="Nginx Proxy Manager"
)

# Add records to Pi-hole using pihole command in container
for service in "${!services[@]}"; do
    domain="${service}.homelab"
    description="${services[$service]}"

    echo "Adding: $domain → $UNRAID_IP ($description)"

    # Execute pihole command inside Docker container
    ssh $PIHOLE_HOST "docker exec pihole pihole -a addcustomdns $UNRAID_IP $domain" 2>&1 | grep -v "already exists" || true
done

# Add Pi-hole itself
echo "Adding: pihole.homelab → $PIHOLE_IP (Pi-hole admin)"
ssh $PIHOLE_HOST "docker exec pihole pihole -a addcustomdns $PIHOLE_IP pihole.homelab" 2>&1 | grep -v "already exists" || true

echo ""
echo "========================================="
echo "  DNS Records Added Successfully"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Run test script: ./scripts/test-dns.sh"
echo "2. Verify in Pi-hole UI: http://192.168.0.19/admin"
echo "   (Local DNS → DNS Records)"
echo ""
echo "To test manually:"
echo "  nslookup jellyfin.homelab 192.168.0.19"
echo "  curl http://jellyfin.homelab:8096"
echo ""
