#!/bin/bash
#
# Quick Vulnerability Scan - High Priority Containers
# Scans critical infrastructure containers
#

set -e

UNRAID="root@100.69.191.4"
mkdir -p ../findings/vulnerability-reports

echo "========================================="
echo " Quick Vulnerability Scan"
echo " High-Priority Containers Only"
echo "========================================="
echo ""

# Priority containers to scan
containers=(
    "postgresql17:postgres:17"
    "mariadb:lscr.io/linuxserver/mariadb"
    "adminer:adminer"
    "binhex-jellyfin:ghcr.io/binhex/arch-jellyfin"
)

for entry in "${containers[@]}"; do
    IFS=":" read -r name image <<< "$entry"

    echo "========================================="
    echo "Scanning: $name"
    echo "Image: $image"
    echo "========================================="

    # Scan and save to file
    ssh $UNRAID "trivy image --severity CRITICAL,HIGH --format table $image" > "../findings/vulnerability-reports/$name-scan.txt" 2>&1

    echo "✓ Scan complete - saved to findings/vulnerability-reports/$name-scan.txt"
    echo ""
done

echo "========================================="
echo "All scans complete!"
echo "========================================="
echo "Review reports in: findings/vulnerability-reports/"
