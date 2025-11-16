#!/bin/bash
# Deploy Complete Monitoring Stack to capcorp9000 (User's Main PC)
# Deploys: Promtail (logs) + node_exporter (metrics)
# Target: 192.168.0.52 (capcorp9000)
# Ships to: Loki on 192.168.0.19:3100, Prometheus on 192.168.0.19:9090

set -e

TARGET_HOST="192.168.0.52"
TARGET_USER="ssjlox"  # Adjust if needed
HOSTNAME="capcorp9000"
CONFIG_DIR="/home/${TARGET_USER}/monitoring"
LOKI_URL="http://192.168.0.19:3100"

echo "=========================================="
echo "capcorp9000 Monitoring Deployment"
echo "=========================================="
echo ""
echo "Target: ${TARGET_HOST} (${HOSTNAME})"
echo "User: ${TARGET_USER}"
echo "Loki: ${LOKI_URL}"
echo ""

# Test connection
echo "[1/10] Testing connection..."
if ! ssh -o ConnectTimeout=5 ${TARGET_USER}@${TARGET_HOST} "echo 'Connected'" 2>/dev/null; then
    echo "❌ Cannot connect to ${TARGET_HOST}"
    echo "Please ensure:"
    echo "  - SSH server is running"
    echo "  - You have SSH access configured"
    exit 1
fi
echo "✅ Connected"
echo ""

# Check if Docker is installed
echo "[2/10] Checking Docker installation..."
if ssh ${TARGET_USER}@${TARGET_HOST} "command -v docker &>/dev/null"; then
    echo "✅ Docker is installed"
else
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi
echo ""

# Create directories
echo "[3/10] Creating directory structure..."
ssh ${TARGET_USER}@${TARGET_HOST} "mkdir -p ${CONFIG_DIR}/promtail"
echo "✅ Directories created"
echo ""

# Copy Promtail config
echo "[4/10] Deploying Promtail configuration..."
scp configs/promtail/capcorp9000-promtail-config.yml ${TARGET_USER}@${TARGET_HOST}:${CONFIG_DIR}/promtail/config.yml
ssh ${TARGET_USER}@${TARGET_HOST} "touch ${CONFIG_DIR}/promtail/positions.yaml"
echo "✅ Promtail config deployed"
echo ""

# Deploy Promtail container
echo "[5/10] Deploying Promtail container..."
ssh ${TARGET_USER}@${TARGET_HOST} "docker stop promtail-capcorp9000 2>/dev/null || true"
ssh ${TARGET_USER}@${TARGET_HOST} "docker rm promtail-capcorp9000 2>/dev/null || true"
ssh ${TARGET_USER}@${TARGET_HOST} "docker run -d \
  --name promtail-capcorp9000 \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /var/log/journal:/var/log/journal:ro \
  -v /run/log/journal:/run/log/journal:ro \
  -v /etc/machine-id:/etc/machine-id:ro \
  -v ${CONFIG_DIR}/promtail/config.yml:/etc/promtail/config.yml:ro \
  -v ${CONFIG_DIR}/promtail/positions.yaml:/tmp/positions.yaml \
  -p 9080:9080 \
  grafana/promtail:latest \
  -config.file=/etc/promtail/config.yml"
echo "✅ Promtail deployed"
echo ""

# Deploy node_exporter
echo "[6/10] Deploying node_exporter container..."
ssh ${TARGET_USER}@${TARGET_HOST} "docker stop node-exporter-capcorp9000 2>/dev/null || true"
ssh ${TARGET_USER}@${TARGET_HOST} "docker rm node-exporter-capcorp9000 2>/dev/null || true"
ssh ${TARGET_USER}@${TARGET_HOST} "docker run -d \
  --name node-exporter-capcorp9000 \
  --restart unless-stopped \
  --net=host \
  --pid=host \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  quay.io/prometheus/node-exporter:latest \
  --path.procfs=/host/proc \
  --path.sysfs=/host/sys \
  --path.rootfs=/rootfs \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)(\$\$|/)'"
echo "✅ node_exporter deployed"
echo ""

# Wait for startup
echo "[7/10] Waiting for containers to initialize..."
sleep 10
echo ""

# Verify Promtail
echo "[8/10] Verifying Promtail..."
PROMTAIL_STATUS=$(ssh ${TARGET_USER}@${TARGET_HOST} "docker ps --filter 'name=promtail-capcorp9000' --format '{{.Status}}'")
if [[ $PROMTAIL_STATUS == *"Up"* ]]; then
    echo "✅ Promtail: Running"
else
    echo "⚠️  Promtail: $PROMTAIL_STATUS"
    ssh ${TARGET_USER}@${TARGET_HOST} "docker logs promtail-capcorp9000 --tail 20"
fi
echo ""

# Verify node_exporter
echo "[9/10] Verifying node_exporter..."
NODE_STATUS=$(ssh ${TARGET_USER}@${TARGET_HOST} "docker ps --filter 'name=node-exporter-capcorp9000' --format '{{.Status}}'")
if [[ $NODE_STATUS == *"Up"* ]]; then
    echo "✅ node_exporter: Running"
    METRICS_TEST=$(ssh ${TARGET_USER}@${TARGET_HOST} "curl -s http://localhost:9100/metrics | head -3")
    if [[ ! -z "$METRICS_TEST" ]]; then
        echo "✅ Metrics endpoint responding"
    fi
else
    echo "⚠️  node_exporter: $NODE_STATUS"
fi
echo ""

# Verify logs reaching Loki
echo "[10/10] Verifying logs in Loki..."
sleep 5
HOSTNAMES=$(ssh automation@100.112.203.63 "curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq -r '.data[]'")
if echo "$HOSTNAMES" | grep -q "capcorp9000"; then
    echo "✅ capcorp9000 logs detected in Loki!"
else
    echo "⚠️  capcorp9000 not yet in Loki (may take a minute)"
    echo "Current hostnames: $HOSTNAMES"
fi
echo ""

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Deployed Containers:"
ssh ${TARGET_USER}@${TARGET_HOST} "docker ps --filter 'name=promtail-capcorp9000' --filter 'name=node-exporter-capcorp9000' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo ""
echo "Next: Add ${TARGET_HOST}:9100 to Prometheus scrape config"
echo ""
