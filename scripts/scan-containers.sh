#!/bin/bash
#
# Container Vulnerability Scanning Script
# Scans all running Docker containers for security vulnerabilities
# Uses Trivy vulnerability scanner
#
# Usage: ./scan-containers.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

UNRAID_HOST="root@100.69.191.4"
SCAN_DIR="/tmp/trivy-scans-$(date +%Y%m%d-%H%M%S)"
REPORT_DIR="../findings/vulnerability-reports"

echo "========================================="
echo "  Container Vulnerability Scan"
echo "  $(date)"
echo "========================================="
echo ""

# Create local report directory
mkdir -p "$REPORT_DIR"

# Create remote scan directory
echo "Creating scan directory on Unraid..."
ssh $UNRAID_HOST "mkdir -p $SCAN_DIR"

# Get list of running containers
echo "Getting list of running containers..."
containers=$(ssh $UNRAID_HOST "docker ps --format '{{.Names}}'")

# Count containers
container_count=$(echo "$containers" | wc -l)
echo -e "${BLUE}Found $container_count running containers${NC}"
echo ""

# Scan each container
current=0
for container in $containers; do
    ((current++))
    echo "========================================="
    echo -e "${BLUE}[$current/$container_count] Scanning: $container${NC}"
    echo "========================================="

    # Get container image
    image=$(ssh $UNRAID_HOST "docker inspect $container --format '{{.Config.Image}}'")
    echo "Image: $image"

    # Scan container image
    echo "Running vulnerability scan..."
    ssh $UNRAID_HOST "trivy image --severity CRITICAL,HIGH,MEDIUM --format json --output $SCAN_DIR/$container.json $image" 2>&1 | grep -v "Downloading" || true

    # Generate summary
    ssh $UNRAID_HOST "trivy image --severity CRITICAL,HIGH,MEDIUM --format table $image" > "$REPORT_DIR/$container-summary.txt" 2>&1 || true

    # Show quick summary
    critical=$(ssh $UNRAID_HOST "trivy image --severity CRITICAL --format json $image 2>/dev/null | jq '[.Results[]?.Vulnerabilities[]?] | length'" 2>/dev/null || echo "0")
    high=$(ssh $UNRAID_HOST "trivy image --severity HIGH --format json $image 2>/dev/null | jq '[.Results[]?.Vulnerabilities[]?] | length'" 2>/dev/null || echo "0")
    medium=$(ssh $UNRAID_HOST "trivy image --severity MEDIUM --format json $image 2>/dev/null | jq '[.Results[]?.Vulnerabilities[]?] | length'" 2>/dev/null || echo "0")

    echo ""
    if [ "$critical" -gt 0 ]; then
        echo -e "${RED}  CRITICAL: $critical${NC}"
    fi
    if [ "$high" -gt 0 ]; then
        echo -e "${YELLOW}  HIGH: $high${NC}"
    fi
    if [ "$medium" -gt 0 ]; then
        echo -e "  MEDIUM: $medium"
    fi

    if [ "$critical" -eq 0 ] && [ "$high" -eq 0 ] && [ "$medium" -eq 0 ]; then
        echo -e "${GREEN}  ✓ No vulnerabilities found${NC}"
    fi

    echo ""
done

# Download all scan results
echo "========================================="
echo "Downloading scan results..."
echo "========================================="
scp -r $UNRAID_HOST:$SCAN_DIR/*.json "$REPORT_DIR/" 2>/dev/null || true

# Clean up remote directory
ssh $UNRAID_HOST "rm -rf $SCAN_DIR"

# Generate summary report
echo ""
echo "========================================="
echo "  Scan Complete!"
echo "========================================="
echo ""
echo "Reports saved to: $REPORT_DIR"
echo ""
echo "Next steps:"
echo "1. Review findings in $REPORT_DIR"
echo "2. Prioritize remediation by severity"
echo "3. Update containers with patched versions"
echo "4. Re-scan to verify fixes"
echo ""
