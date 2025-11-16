#!/bin/bash
# Deploy Complete Monitoring Stack to Unraid Server
# Deploys: Promtail (logs) + node_exporter (metrics)
# Target: 192.168.0.51 (unraid-server)
# Ships to: Loki on 192.168.0.19:3100, Prometheus on 192.168.0.19:9090

set -e

UNRAID_HOST="192.168.0.51"
UNRAID_USER="root"
APPDATA_PATH="/mnt/user/appdata"
LOKI_URL="http://192.168.0.19:3100"

echo "=========================================="
echo "Unraid Monitoring Deployment"
echo "=========================================="
echo ""
echo "Target: ${UNRAID_HOST}"
echo "Loki: ${LOKI_URL}"
echo "Components: Promtail + node_exporter"
echo ""

# Test connection
echo "[1/8] Testing connection to Unraid..."
if ! ssh -o ConnectTimeout=5 ${UNRAID_USER}@${UNRAID_HOST} "echo 'Connected'" 2>/dev/null; then
    echo "❌ Cannot connect to Unraid server"
    echo "Ensure SSH is enabled in Unraid Settings -> Management Access"
    exit 1
fi
echo "✅ Connected to Unraid"
echo ""

# Create directories
echo "[2/8] Creating directory structure..."
ssh ${UNRAID_USER}@${UNRAID_HOST} "mkdir -p ${APPDATA_PATH}/promtail ${APPDATA_PATH}/node-exporter"
echo "✅ Directories created"
echo ""

# Copy Promtail config
echo "[3/8] Deploying Promtail configuration..."
scp configs/promtail/unraid-promtail-config.yml ${UNRAID_USER}@${UNRAID_HOST}:${APPDATA_PATH}/promtail/config.yml
ssh ${UNRAID_USER}@${UNRAID_HOST} "touch ${APPDATA_PATH}/promtail/positions.yaml"
echo "✅ Promtail config deployed"
echo ""

# Deploy Promtail container
echo "[4/8] Deploying Promtail container..."
ssh ${UNRAID_USER}@${UNRAID_HOST} "docker stop promtail-unraid 2>/dev/null || true"
ssh ${UNRAID_USER}@${UNRAID_HOST} "docker rm promtail-unraid 2>/dev/null || true"
ssh ${UNRAID_USER}@${UNRAID_HOST} "docker run -d \
  --name promtail-unraid \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /var/log:/var/log:ro \
  -v ${APPDATA_PATH}/promtail/config.yml:/etc/promtail/config.yml:ro \
  -v ${APPDATA_PATH}/promtail/positions.yaml:/tmp/positions.yaml \
  -p 9080:9080 \
  grafana/promtail:latest \
  -config.file=/etc/promtail/config.yml"
echo "✅ Promtail container deployed"
echo ""

# Deploy node_exporter for system metrics
echo "[5/8] Deploying node_exporter container..."
ssh ${UNRAID_USER}@${UNRAID_HOST} "docker stop node-exporter-unraid 2>/dev/null || true"
ssh ${UNRAID_USER}@${UNRAID_HOST} "docker rm node-exporter-unraid 2>/dev/null || true"
ssh ${UNRAID_USER}@${UNRAID_HOST} "docker run -d \
  --name node-exporter-unraid \
  --restart unless-stopped \
  --net=host \
  --pid=host \
  -v /:/host:ro,rslave \
  quay.io/prometheus/node-exporter:latest \
  --path.rootfs=/host"
echo "✅ node_exporter deployed"
echo ""

# Wait for containers to start
echo "[6/8] Waiting for containers to initialize..."
sleep 10
echo ""

# Verify Promtail
echo "[7/8] Verifying Promtail deployment..."
PROMTAIL_STATUS=$(ssh ${UNRAID_USER}@${UNRAID_HOST} "docker ps --filter 'name=promtail-unraid' --format '{{.Status}}'")
if [[ $PROMTAIL_STATUS == *"Up"* ]]; then
    echo "✅ Promtail: Running"
else
    echo "⚠️  Promtail: $PROMTAIL_STATUS"
    echo "Checking logs:"
    ssh ${UNRAID_USER}@${UNRAID_HOST} "docker logs promtail-unraid --tail 20"
fi
echo ""

# Verify node_exporter
echo "[8/8] Verifying node_exporter deployment..."
NODE_EXPORTER_STATUS=$(ssh ${UNRAID_USER}@${UNRAID_HOST} "docker ps --filter 'name=node-exporter-unraid' --format '{{.Status}}'")
if [[ $NODE_EXPORTER_STATUS == *"Up"* ]]; then
    echo "✅ node_exporter: Running"
    echo ""
    echo "Testing metrics endpoint..."
    METRICS_TEST=$(ssh ${UNRAID_USER}@${UNRAID_HOST} "curl -s http://localhost:9100/metrics | head -5")
    if [[ ! -z "$METRICS_TEST" ]]; then
        echo "✅ Metrics endpoint responding"
    fi
else
    echo "⚠️  node_exporter: $NODE_EXPORTER_STATUS"
fi
echo ""

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Deployed Containers:"
ssh ${UNRAID_USER}@${UNRAID_HOST} "docker ps --filter 'name=promtail-unraid' --filter 'name=node-exporter-unraid' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo ""
echo "Next Steps:"
echo "1. Verify logs reaching Loki:"
echo "   curl -s 'http://192.168.0.19:3100/loki/api/v1/label/hostname/values' | jq"
echo ""
echo "2. Add Unraid to Prometheus scrape config:"
echo "   Add job for node-exporter at ${UNRAID_HOST}:9100"
echo ""
echo "3. Check Grafana for 'unraid-server' logs"
echo ""
