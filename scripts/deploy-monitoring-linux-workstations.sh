#!/bin/bash
# Deploy Monitoring to All Linux Workstations
# Deploys: Promtail (logs) + node_exporter (metrics)
# Target: CachyOS and Garuda workstations

set -e

# Define workstations
declare -A WORKSTATIONS
WORKSTATIONS["192.168.0.13"]="cachyos-1"
WORKSTATIONS["192.168.0.95"]="cachyos-2"
WORKSTATIONS["192.168.0.119"]="cachyos-3"
WORKSTATIONS["192.168.0.202"]="garuda-xfce"

TARGET_USER="ssjlox"  # Adjust if different
CONFIG_DIR="/home/${TARGET_USER}/monitoring"
LOKI_URL="http://192.168.0.19:3100"

echo "=========================================="
echo "Linux Workstation Monitoring Deployment"
echo "=========================================="
echo ""
echo "Targets: 4 workstations"
echo "User: ${TARGET_USER}"
echo "Loki: ${LOKI_URL}"
echo ""

# Function to deploy to a single host
deploy_to_host() {
    local IP=$1
    local HOSTNAME=$2

    echo ""
    echo "========================================"
    echo "Deploying to ${HOSTNAME} (${IP})"
    echo "========================================"

    # Test connection
    echo "[1/8] Testing connection..."
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${TARGET_USER}@${IP} "echo 'Connected'" 2>/dev/null; then
        echo "⚠️  Cannot connect to ${IP} - Skipping"
        echo "   Device may be powered off or SSH not configured"
        return 1
    fi
    echo "✅ Connected"

    # Create hostname-specific config
    echo "[2/8] Creating Promtail config..."
    sed "s/HOSTNAME_PLACEHOLDER/${HOSTNAME}/g" configs/promtail/linux-workstation-template.yml > /tmp/promtail-${HOSTNAME}.yml

    # Create directories
    echo "[3/8] Creating directories..."
    ssh ${TARGET_USER}@${IP} "mkdir -p ${CONFIG_DIR}/promtail"

    # Copy config
    echo "[4/8] Deploying config..."
    scp /tmp/promtail-${HOSTNAME}.yml ${TARGET_USER}@${IP}:${CONFIG_DIR}/promtail/config.yml
    ssh ${TARGET_USER}@${IP} "touch ${CONFIG_DIR}/promtail/positions.yaml"

    # Deploy Promtail
    echo "[5/8] Deploying Promtail..."
    ssh ${TARGET_USER}@${IP} "docker stop promtail-${HOSTNAME} 2>/dev/null || true"
    ssh ${TARGET_USER}@${IP} "docker rm promtail-${HOSTNAME} 2>/dev/null || true"
    ssh ${TARGET_USER}@${IP} "docker run -d \
      --name promtail-${HOSTNAME} \
      --restart unless-stopped \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -v /var/log/journal:/var/log/journal:ro \
      -v /run/log/journal:/run/log/journal:ro \
      -v /etc/machine-id:/etc/machine-id:ro \
      -v ${CONFIG_DIR}/promtail/config.yml:/etc/promtail/config.yml:ro \
      -v ${CONFIG_DIR}/promtail/positions.yaml:/tmp/positions.yaml \
      -p 9080:9080 \
      grafana/promtail:latest \
      -config.file=/etc/promtail/config.yml" > /dev/null 2>&1
    echo "✅ Promtail deployed"

    # Deploy node_exporter
    echo "[6/8] Deploying node_exporter..."
    ssh ${TARGET_USER}@${IP} "docker stop node-exporter-${HOSTNAME} 2>/dev/null || true"
    ssh ${TARGET_USER}@${IP} "docker rm node-exporter-${HOSTNAME} 2>/dev/null || true"
    ssh ${TARGET_USER}@${IP} "docker run -d \
      --name node-exporter-${HOSTNAME} \
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
      --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)(\$\$|/)'" > /dev/null 2>&1
    echo "✅ node_exporter deployed"

    # Wait for startup
    echo "[7/8] Waiting for containers..."
    sleep 5

    # Verify
    echo "[8/8] Verifying deployment..."
    PROMTAIL_UP=$(ssh ${TARGET_USER}@${IP} "docker ps --filter 'name=promtail-${HOSTNAME}' --format '{{.Status}}' | grep -c Up" || echo "0")
    NODE_UP=$(ssh ${TARGET_USER}@${IP} "docker ps --filter 'name=node-exporter-${HOSTNAME}' --format '{{.Status}}' | grep -c Up" || echo "0")

    if [ "$PROMTAIL_UP" = "1" ] && [ "$NODE_UP" = "1" ]; then
        echo "✅ Both containers running"
        echo ""
        return 0
    else
        echo "⚠️  Some containers may have issues"
        echo "   Promtail: $([ $PROMTAIL_UP -eq 1 ] && echo 'OK' || echo 'FAILED')"
        echo "   node_exporter: $([ $NODE_UP -eq 1 ] && echo 'OK' || echo 'FAILED')"
        echo ""
        return 1
    fi
}

# Deploy to all workstations
SUCCESSFUL=0
FAILED=0

for IP in "${!WORKSTATIONS[@]}"; do
    HOSTNAME="${WORKSTATIONS[$IP]}"
    if deploy_to_host "$IP" "$HOSTNAME"; then
        ((SUCCESSFUL++))
    else
        ((FAILED++))
    fi
done

echo ""
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
echo ""
echo "Successful: $SUCCESSFUL / 4"
echo "Failed: $FAILED / 4"
echo ""

if [ $SUCCESSFUL -gt 0 ]; then
    echo "Checking Loki for new hostnames..."
    sleep 10
    ssh automation@100.112.203.63 "curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq -r '.data[]'"
    echo ""
fi

echo "Next Steps:"
echo "1. Add successful hosts to Prometheus scrape config"
echo "2. Configure firewall rules on each host (port 9100 for Prometheus)"
echo "3. Verify metrics in Grafana"
echo ""
echo "Firewall commands for each host:"
echo "  sudo firewall-cmd --permanent --add-rich-rule='rule family=\"ipv4\" source address=\"192.168.0.0/24\" port port=\"9100\" protocol=\"tcp\" accept'"
echo "  sudo firewall-cmd --reload"
echo ""
