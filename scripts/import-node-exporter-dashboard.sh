#!/bin/bash
# Import Node Exporter Full Dashboard to Grafana
# This dashboard works for ALL devices (Linux, macOS, Windows)

set -e

# Configuration
GRAFANA_URL="http://192.168.0.19:3000"
GRAFANA_USER="admin"
DASHBOARD_ID="1860"  # Node Exporter Full dashboard from grafana.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Grafana Dashboard Import"
echo "=========================================="
echo ""
echo "This will import the 'Node Exporter Full' dashboard"
echo "Dashboard ID: $DASHBOARD_ID"
echo "Works for: Linux, macOS, Windows (all node_exporter metrics)"
echo ""

# Prompt for Grafana password
read -sp "Enter Grafana admin password: " GRAFANA_PASS
echo ""

if [ -z "$GRAFANA_PASS" ]; then
    echo "${RED}✗${NC} Password cannot be empty"
    exit 1
fi

echo ""
echo "Fetching dashboard from grafana.com..."

# Fetch dashboard JSON from Grafana.com
DASHBOARD_JSON=$(curl -s "https://grafana.com/api/dashboards/$DASHBOARD_ID/revisions/latest/download")

if [ -z "$DASHBOARD_JSON" ] || [[ "$DASHBOARD_JSON" == *"error"* ]]; then
    echo "${RED}✗${NC} Failed to fetch dashboard"
    exit 1
fi

echo "${GREEN}✓${NC} Dashboard fetched"

# Prepare import payload
IMPORT_PAYLOAD=$(cat <<EOF
{
  "dashboard": $DASHBOARD_JSON,
  "overwrite": true,
  "inputs": [
    {
      "name": "DS_PROMETHEUS",
      "type": "datasource",
      "pluginId": "prometheus",
      "value": "Prometheus"
    }
  ],
  "folderId": 0
}
EOF
)

echo "Importing dashboard to Grafana..."

# Import dashboard
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d "$IMPORT_PAYLOAD" \
  "$GRAFANA_URL/api/dashboards/import")

if echo "$RESPONSE" | grep -q "success"; then
    DASHBOARD_URL=$(echo "$RESPONSE" | jq -r '.importedUrl' 2>/dev/null || echo "")

    echo ""
    echo "=========================================="
    echo "${GREEN}Dashboard Imported Successfully!${NC}"
    echo "=========================================="
    echo ""

    if [ -n "$DASHBOARD_URL" ]; then
        echo "Dashboard URL:"
        echo "  $GRAFANA_URL$DASHBOARD_URL"
        echo ""
    fi

    echo "You can now view metrics for:"
    echo "  • All Linux devices (existing)"
    echo "  • macOS devices (SSJMBPro-4)"
    echo "  • Windows devices (when deployed)"
    echo ""
    echo "The dashboard includes:"
    echo "  • CPU usage and temperature"
    echo "  • Memory utilization"
    echo "  • Disk space and I/O"
    echo "  • Network bandwidth"
    echo "  • System uptime"
    echo ""
    echo "To view specific device:"
    echo "  1. Open dashboard: $GRAFANA_URL/dashboards"
    echo "  2. Search for 'Node Exporter Full'"
    echo "  3. Select hostname from dropdown"
    echo ""

elif echo "$RESPONSE" | grep -q "already exists"; then
    echo ""
    echo "${YELLOW}⚠${NC} Dashboard already exists"
    echo ""
    echo "Dashboard is already imported. You can find it at:"
    echo "  $GRAFANA_URL/dashboards"
    echo ""
    echo "Search for: Node Exporter Full"
    echo ""

else
    echo ""
    echo "${RED}✗${NC} Import failed"
    echo ""
    echo "Response: $RESPONSE"
    echo ""

    # Common error checks
    if echo "$RESPONSE" | grep -q "401"; then
        echo "${YELLOW}Hint:${NC} Invalid credentials. Check Grafana password."
    elif echo "$RESPONSE" | grep -q "Prometheus"; then
        echo "${YELLOW}Hint:${NC} Prometheus datasource not configured correctly."
    fi

    exit 1
fi
