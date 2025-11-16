#!/bin/bash
#
# Add cAdvisor to Loki Stack for Container Metrics
# This enables full container monitoring in Grafana
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

COMPOSE_DIR="$HOME/docker/loki-stack"

log_section "Adding cAdvisor to Loki Stack"

# Check if compose directory exists
if [[ ! -d "$COMPOSE_DIR" ]]; then
    log_error "Loki stack directory not found: $COMPOSE_DIR"
    exit 1
fi

cd "$COMPOSE_DIR"

# Backup current config
log_info "Backing up current configuration..."
cp docker-compose.yml "docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
cp prometheus.yml "prometheus.yml.backup.$(date +%Y%m%d_%H%M%S)"
log_info "✅ Backups created"

# Check if cAdvisor already exists
if grep -q "cadvisor:" docker-compose.yml; then
    log_warn "cAdvisor already exists in docker-compose.yml"
    log_info "Skipping docker-compose.yml modification"
else
    log_info "Adding cAdvisor service to docker-compose.yml..."

    cat >> docker-compose.yml <<'EOF'

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
    networks:
      - loki
EOF

    log_info "✅ cAdvisor added to docker-compose.yml"
fi

# Check if Prometheus already has cAdvisor
if grep -q "job_name: 'cadvisor'" prometheus.yml; then
    log_warn "cAdvisor scrape config already exists in prometheus.yml"
    log_info "Skipping prometheus.yml modification"
else
    log_info "Adding cAdvisor to Prometheus scrape config..."

    cat >> prometheus.yml <<'EOF'

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

    log_info "✅ cAdvisor scrape config added to prometheus.yml"
fi

# Restart stack
log_section "Restarting Loki Stack"

log_info "Stopping containers..."
docker compose down

log_info "Starting containers with cAdvisor..."
docker compose up -d

log_info "Waiting for services to start (15 seconds)..."
sleep 15

# Verify
log_section "Verification"

log_info "Checking cAdvisor is running..."
if docker ps | grep -q cadvisor; then
    log_info "✅ cAdvisor container is running"
else
    log_warn "❌ cAdvisor container not found"
fi

log_info "Checking cAdvisor metrics endpoint..."
if curl -sf http://localhost:8080/metrics > /dev/null; then
    METRIC_COUNT=$(curl -s http://localhost:8080/metrics | grep -c ^container_ || echo "0")
    log_info "✅ cAdvisor metrics available ($METRIC_COUNT container metrics)"
else
    log_warn "❌ cAdvisor metrics endpoint not responding"
fi

log_info "Checking Prometheus is scraping cAdvisor..."
sleep 5
CADVISOR_TARGET=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="cadvisor") | .health' 2>/dev/null || echo "")
if [[ "$CADVISOR_TARGET" == "up" ]]; then
    log_info "✅ Prometheus is scraping cAdvisor"
else
    log_warn "⏳ Prometheus not yet scraping cAdvisor (may take 1-2 minutes)"
fi

log_section "Setup Complete!"

cat <<EOF
${GREEN}✅ cAdvisor has been added to your Loki stack!${NC}

${BLUE}What's New:${NC}
- cAdvisor container monitoring all Docker containers
- Prometheus scraping container metrics from cAdvisor
- Full container metrics now available in Grafana

${BLUE}Access:${NC}
- cAdvisor Web UI: http://192.168.0.19:8080
- cAdvisor Metrics: http://192.168.0.19:8080/metrics

${BLUE}Next Steps:${NC}
1. Wait 2-3 minutes for Prometheus to collect metrics
2. Refresh your Grafana dashboard
3. Panels should now show container data

${BLUE}Test Queries in Prometheus:${NC}
- Container CPU: rate(container_cpu_usage_seconds_total{name="grafana"}[5m])
- Container Memory: container_memory_usage_bytes{name="grafana"}
- Container Uptime: container_last_seen{name="grafana"}

${BLUE}Verify Metrics:${NC}
curl -s 'http://localhost:9090/api/v1/query?query=container_last_seen' | jq '.data.result[] | .metric.name'

EOF

log_info "🎉 Enjoy full container monitoring!"
