# Add cAdvisor for Container Metrics

**Issue**: The Grafana dashboard shows "No data" because Prometheus isn't collecting container-specific metrics.

**Solution**: Add cAdvisor (Container Advisor) to your Loki stack to export Docker container metrics.

---

## What is cAdvisor?

cAdvisor (Container Advisor) is a Google-developed tool that:
- Monitors all running Docker containers
- Exports metrics like CPU, memory, network, disk I/O
- Provides container image information
- Tracks container restarts and lifecycle events

**Official**: https://github.com/google/cadvisor

---

## Quick Installation

### Option 1: Add to Loki Stack (Recommended)

Edit your Loki stack docker-compose file:

```bash
ssh automation@100.112.203.63
cd ~/docker/loki-stack
nano docker-compose.yml
```

Add this service:

```yaml
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
```

Update Prometheus to scrape cAdvisor. Edit `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'pihole'
    static_configs:
      - targets: ['172.26.0.1:9666']

  # Add this:
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
```

Restart the stack:

```bash
docker compose down
docker compose up -d
```

Verify cAdvisor is running:

```bash
curl http://localhost:8080/metrics | grep container_
```

### Option 2: Standalone Container

```bash
docker run -d \
  --name=cadvisor \
  --restart=unless-stopped \
  --privileged \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --publish=8080:8080 \
  --detach=true \
  gcr.io/cadvisor/cadvisor:latest
```

---

## What Metrics You'll Get

Once cAdvisor is running, you'll have access to:

### Container Lifecycle
```promql
# Container uptime
container_last_seen{name=~"pihole|vaultwarden|caddy"}

# Container restarts
rate(container_start_time_seconds[5m])
```

### Resource Usage
```promql
# CPU usage
rate(container_cpu_usage_seconds_total{name="vaultwarden"}[5m])

# Memory usage
container_memory_usage_bytes{name="pihole"}

# Network traffic
rate(container_network_receive_bytes_total[5m])
```

### Image Information
```promql
# Container image
container_spec_image{name="grafana"}
```

---

## Updated Dashboard Queries

Once cAdvisor is running, these queries will work:

### Container Image Age
```promql
(time() - container_last_seen{name=~"pihole|vaultwarden|caddy|grafana|prometheus|loki"}) / 86400
```

### Container CPU Usage
```promql
rate(container_cpu_usage_seconds_total{name=~"pihole|vaultwarden|caddy|grafana|prometheus|loki|homeassistant"}[5m]) * 100
```

### Container Memory Usage
```promql
container_memory_usage_bytes{name=~".*"} / 1024 / 1024
```

### Container Restarts
```promql
changes(container_last_seen{name=~".*"}[24h])
```

---

## Temporary Workaround (Without cAdvisor)

If you don't want to install cAdvisor right now, you can still monitor:

### System-Level Metrics (Available Now)

**CPU Usage**:
```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Memory Usage**:
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

**Disk Usage**:
```promql
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)
```

### Docker Commands for Container Info

**Check container uptime**:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
```

**Check container restarts**:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}" --filter "status=restarting"
```

**Check image age**:
```bash
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedSince}}"
```

---

## Verification

After adding cAdvisor:

```bash
# Check cAdvisor is running
docker ps | grep cadvisor

# Check metrics endpoint
curl http://localhost:8080/metrics | head -20

# Check Prometheus is scraping
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="cadvisor")'

# Test a query
curl -s 'http://localhost:9090/api/v1/query?query=container_last_seen' | jq '.data.result[] | .metric.name'
```

---

## Full Setup Script

```bash
#!/bin/bash
# Add cAdvisor to Loki stack

cd ~/docker/loki-stack

# Backup current config
cp docker-compose.yml docker-compose.yml.backup
cp prometheus.yml prometheus.yml.backup

# Add cAdvisor to docker-compose.yml
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

# Add cAdvisor to Prometheus scrape config
cat >> prometheus.yml <<'EOF'

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

# Restart stack
docker compose down
docker compose up -d

# Wait for startup
sleep 10

# Verify
echo "Checking cAdvisor metrics..."
curl -s http://localhost:8080/metrics | grep -c container_

echo "Checking Prometheus targets..."
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="cadvisor") | {job: .labels.job, state: .health}'

echo "Done! cAdvisor is now exporting container metrics."
```

---

## Benefits

With cAdvisor running, you'll get:

✅ Real container metrics in Grafana
✅ Container-specific CPU/memory usage
✅ Image age tracking
✅ Restart detection
✅ Network and disk I/O stats
✅ Per-container resource limits

---

## Resource Usage

cAdvisor is lightweight:
- **CPU**: ~1-2% on average
- **Memory**: ~50-100 MB
- **Storage**: Minimal (no persistent data)

---

**Next Steps**:
1. Add cAdvisor to your Loki stack
2. Wait 1-2 minutes for metrics collection
3. Refresh your Grafana dashboard
4. Panels will populate with container data

---

**Created**: 2025-11-09
**Status**: Optional enhancement for full container monitoring

🤖 Generated with [Claude Code](https://claude.com/claude-code)
