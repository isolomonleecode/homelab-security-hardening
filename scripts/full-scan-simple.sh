#!/bin/bash
#
# Full Container Vulnerability Scan - All Containers
#

set -e

UNRAID="root@100.69.191.4"
REPORT_DIR="../findings/vulnerability-reports"

mkdir -p "$REPORT_DIR"

echo "========================================="
echo " Full Vulnerability Scan - All Containers"
echo " $(date)"
echo "========================================="
echo ""

# Get all running containers
echo "Getting list of containers..."
containers=$(ssh $UNRAID "docker ps --format '{{.Names}}'")

count=$(echo "$containers" | wc -l)
echo "Found $count containers to scan"
echo ""

current=0
for container in $containers; do
    ((current++))

    echo "========================================="
    echo "[$current/$count] Scanning: $container"
    echo "========================================="

    # Get image name
    image=$(ssh $UNRAID "docker inspect $container --format '{{.Config.Image}}'")
    echo "Image: $image"

    # Scan for CRITICAL and HIGH vulnerabilities
    echo "Scanning for vulnerabilities..."
    ssh $UNRAID "trivy image --severity CRITICAL,HIGH --format table --quiet $image" > "$REPORT_DIR/$container-scan.txt" 2>&1 || true

    # Show quick summary from the file
    if grep -q "Total: 0" "$REPORT_DIR/$container-scan.txt" 2>/dev/null; then
        echo "✓ No critical/high vulnerabilities found"
    else
        critical_count=$(grep -c "CRITICAL" "$REPORT_DIR/$container-scan.txt" 2>/dev/null || echo "0")
        high_count=$(grep -c "HIGH" "$REPORT_DIR/$container-scan.txt" 2>/dev/null || echo "0")
        echo "⚠ Found vulnerabilities - CRITICAL: $critical_count, HIGH: $high_count"
    fi

    echo ""
done

echo "========================================="
echo " Scan Complete!"
echo "========================================="
echo "Reports saved to: $REPORT_DIR"
echo ""
echo "To review findings:"
echo "  ls -lh $REPORT_DIR"
echo "  cat $REPORT_DIR/[container-name]-scan.txt"
