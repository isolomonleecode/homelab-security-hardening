#!/bin/bash
# Deploy Promtail to Unraid Server for centralized log monitoring
# Target: 192.168.0.51 (capcorplee)
# Sends logs to: Loki on Raspberry Pi (192.168.0.19:3100)

set -e

UNRAID_HOST="192.168.0.51"
UNRAID_USER="root"  # Unraid default user
APPDATA_PATH="/mnt/user/appdata/promtail"

echo "=========================================="
echo "Promtail Deployment to Unraid Server"
echo "=========================================="
echo ""
echo "Target: ${UNRAID_HOST}"
echo "Loki Endpoint: http://192.168.0.19:3100"
echo ""

# Check if we can reach Unraid
echo "[1/6] Testing connection to Unraid server..."
if ! ssh -o ConnectTimeout=5 ${UNRAID_USER}@${UNRAID_HOST} "echo 'Connection successful'" 2>/dev/null; then
    echo "❌ ERROR: Cannot connect to Unraid server at ${UNRAID_HOST}"
    echo "Please ensure:"
    echo "  - Unraid server is powered on"
    echo "  - SSH is enabled in Unraid settings"
    echo "  - You have SSH access configured"
    exit 1
fi
echo "✅ Connection successful"
echo ""

# Create directory structure
echo "[2/6] Creating Promtail directory structure..."
ssh ${UNRAID_USER}@${UNRAID_HOST} "mkdir -p ${APPDATA_PATH}"
echo "✅ Created ${APPDATA_PATH}"
echo ""

# Copy Promtail config
echo "[3/6] Copying Promtail configuration..."
scp configs/promtail/unraid-promtail-config.yml ${UNRAID_USER}@${UNRAID_HOST}:${APPDATA_PATH}/config.yml
echo "✅ Configuration copied"
echo ""

# Copy Docker Compose file
echo "[4/6] Copying Docker Compose file..."
scp configs/promtail/unraid-docker-compose.yml ${UNRAID_USER}@${UNRAID_HOST}:${APPDATA_PATH}/docker-compose.yml
echo "✅ Docker Compose file copied"
echo ""

# Create empty positions file
echo "[5/6] Creating positions tracking file..."
ssh ${UNRAID_USER}@${UNRAID_HOST} "touch ${APPDATA_PATH}/positions.yaml"
echo "✅ Positions file created"
echo ""

# Deploy Promtail container
echo "[6/6] Deploying Promtail container..."
ssh ${UNRAID_USER}@${UNRAID_HOST} "cd ${APPDATA_PATH} && docker-compose up -d"
echo "✅ Promtail container deployed"
echo ""

# Wait for container to start
echo "Waiting 10 seconds for container to start..."
sleep 10

# Verify deployment
echo ""
echo "=========================================="
echo "Verifying Deployment"
echo "=========================================="
echo ""

echo "Promtail container status:"
ssh ${UNRAID_USER}@${UNRAID_HOST} "docker ps --filter 'name=promtail' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo ""

echo "Promtail logs (last 20 lines):"
ssh ${UNRAID_USER}@${UNRAID_HOST} "docker logs promtail-unraid --tail 20"
echo ""

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Verify logs are reaching Loki:"
echo "   ssh automation@100.112.203.63 \"curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq\""
echo ""
echo "2. You should see both 'sweetrpi-desktop' and 'unraid-server' in the output"
echo ""
echo "3. Check Grafana dashboard at http://192.168.0.19:3000"
echo "   You should now see logs from Unraid containers!"
echo ""
