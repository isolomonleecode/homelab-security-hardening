# Multi-Device Monitoring Deployment Guide

**Goal:** Centralize monitoring for all homelab infrastructure in Grafana
**Architecture:** Distributed log collection → Central Loki → Unified Grafana dashboards
**Timeline:** 30-60 minutes setup

---

## Current Infrastructure

### Monitored (✅)
- **Raspberry Pi (192.168.0.19)** - sweetrpi-desktop
  - Promtail installed ✅
  - Shipping to Loki on media server ✅
  - Containers: grafana, homeassistant, loki, prometheus, promtail

### Partially Monitored (⚠️)
- **Media Server (192.168.0.52)** - Has monitoring stack
  - Grafana running ✅
  - Loki running ✅
  - Prometheus running ✅
  - **MISSING:** Promtail to ship own logs to Loki ❌
  - Containers: Unknown (need inventory)

### Unmonitored (❌)
- **Unraid Server (192.168.0.51)** - capcorplee
  - 18+ running containers
  - All logs only accessible locally
  - **CRITICAL GAP:** Largest attack surface not monitored!
  - Containers: postgresql17, mariadb, jellyfin, sonarr, radarr, prowlarr, adminer, nginx-proxy-manager, etc.

---

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CENTRALIZED MONITORING                    │
│                  Media Server (192.168.0.52)                 │
│  ┌─────────────┐  ┌──────────┐  ┌────────────┐             │
│  │  Grafana    │←─│   Loki   │←─│ Prometheus │             │
│  │   :3000     │  │  :3100   │  │   :9090    │             │
│  └─────────────┘  └─────┬────┘  └────────────┘             │
└────────────────────────┼──────────────────────────────────┘
                         │ Receives logs from all devices
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌──────────────┐  ┌─────────────┐  ┌──────────────┐
│ Raspberry Pi │  │Media Server │  │Unraid Server │
│ 192.168.0.19 │  │192.168.0.52 │  │192.168.0.51  │
├──────────────┤  ├─────────────┤  ├──────────────┤
│  Promtail ✅ │  │  Promtail ⚠️│  │  Promtail ❌ │
│    ships:    │  │   ships:    │  │   ships:     │
│  - Docker    │  │  - Docker   │  │  - Docker    │
│  - systemd   │  │  - systemd  │  │  - systemd   │
└──────────────┘  └─────────────┘  └──────────────┘
```

---

## Deployment Steps

### Step 1: Deploy Promtail to Unraid Server (PRIORITY 1)

**Why This Matters:**
- Unraid has 18+ containers (largest attack surface)
- Critical services: databases, reverse proxy, public tunnel
- Currently zero visibility into security events

**Deployment Method: Docker Container** (Easiest for Unraid)

**Create Promtail Container on Unraid:**

```yaml
# /mnt/user/appdata/promtail/docker-compose.yml
version: "3"

services:
  promtail:
    image: grafana/promtail:latest
    container_name: promtail-unraid
    restart: unless-stopped
    volumes:
      # Docker socket to read container logs
      - /var/run/docker.sock:/var/run/docker.sock:ro
      # System logs
      - /var/log:/var/log:ro
      # Promtail config
      - /mnt/user/appdata/promtail/config.yml:/etc/promtail/config.yml:ro
      # Promtail positions file (tracks what's been read)
      - /mnt/user/appdata/promtail/positions.yaml:/tmp/positions.yaml
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitoring

networks:
  monitoring:
    external: false
```

**Promtail Config for Unraid:**

```yaml
# /mnt/user/appdata/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

clients:
  # Point to Loki on media server
  - url: http://192.168.0.52:3100/loki/api/v1/push

positions:
  filename: /tmp/positions.yaml

scrape_configs:
  # Scrape all Docker container logs
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 30s
    relabel_configs:
      - source_labels: ["__meta_docker_container_name"]
        regex: '/(.*)'
        target_label: "container"
      - source_labels: ["__meta_docker_container_image"]
        target_label: "image"
      - source_labels: ["__meta_docker_container_id"]
        target_label: "container_id"
      - replacement: "unraid-server"
        target_label: "hostname"
      - replacement: "docker"
        target_label: "job"
    pipeline_stages:
      - docker: {}

  # Scrape system logs (if available on Unraid)
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          hostname: unraid-server
          __path__: /var/log/syslog
```

**Deploy on Unraid:**

```bash
# SSH to Unraid server
ssh root@192.168.0.51

# Create directory structure
mkdir -p /mnt/user/appdata/promtail

# Create config file
cat > /mnt/user/appdata/promtail/config.yml << 'EOF'
[paste config above]
EOF

# Create docker-compose file
cat > /mnt/user/appdata/promtail/docker-compose.yml << 'EOF'
[paste docker-compose above]
EOF

# Deploy
cd /mnt/user/appdata/promtail
docker-compose up -d

# Verify
docker logs promtail-unraid --tail 20
```

**Verification:**

```bash
# On Unraid - check Promtail is running
docker ps | grep promtail

# On Unraid - check Promtail logs
docker logs promtail-unraid --tail 50

# From any machine - check Loki is receiving logs
curl -s "http://192.168.0.52:3100/loki/api/v1/label/hostname/values" | jq -r '.data[]'
# Should show: sweetrpi-desktop, unraid-server
```

---

### Step 2: Deploy Promtail to Media Server (PRIORITY 2)

**Why:** Media server has the monitoring stack but isn't monitoring itself!

**Method 1: Add to Existing Docker Compose** (Recommended)

```bash
# SSH to media server
ssh [user]@192.168.0.52

# Find existing docker-compose for Loki stack
find /home -name "*loki*compose*" -o -name "*grafana*compose*" 2>/dev/null

# Add Promtail service to that compose file
```

**Method 2: Standalone Container** (If no compose file found)

```bash
# On media server
docker run -d \
  --name promtail-mediaserver \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /var/log:/var/log:ro \
  -v /path/to/promtail-config.yml:/etc/promtail/config.yml:ro \
  grafana/promtail:latest \
  -config.file=/etc/promtail/config.yml
```

**Config for Media Server:**

Same as Unraid config but change:
```yaml
- replacement: "media-server"
  target_label: "hostname"
```

---

### Step 3: Verify All Devices Are Logging

**Check Loki for all hostnames:**

```bash
# From any machine
curl -s "http://192.168.0.52:3100/loki/api/v1/label/hostname/values" | jq -r '.data[]'

# Expected output:
# sweetrpi-desktop
# unraid-server
# media-server
```

**Check log volume per host:**

```bash
curl -s -G "http://192.168.0.52:3100/loki/api/v1/query" \
  --data-urlencode 'query=sum by (hostname) (count_over_time({job="docker"} [1h]))' \
  --data-urlencode "time=$(date +%s)" | jq -r '.data.result[] | "\(.metric.hostname): \(.value[1])"'
```

---

### Step 4: Update Grafana Dashboard to Show All Hosts

**Add New Panel: "Log Volume by Host"**

1. Go to Grafana dashboard
2. Click **Edit** → **Add panel**
3. **Title:** "Log Volume by Host (1h)"
4. **Visualization:** Bar chart or Pie chart
5. **Query:**
   ```
   sum by (hostname) (count_over_time({job="docker"} [1h]))
   ```
6. **Save**

**Add Panel: "Security Events by Host"**

1. **Title:** "Security Events by Host (24h)"
2. **Visualization:** Table
3. **Query:**
   ```
   sum by (hostname) (count_over_time({job=~"docker|systemd-journal"} |~ "(?i)(error|fail|denied|unauthorized)" [24h]))
   ```
4. **Save**

**Update Existing Panels to Filter by Host:**

Add a **dashboard variable** for hostname:
1. Dashboard Settings (gear icon) → **Variables** → **Add variable**
2. **Name:** `hostname`
3. **Type:** Query
4. **Label:** Host
5. **Data source:** Loki
6. **Query:** `label_values(hostname)`
7. **Multi-value:** Yes
8. **Include All:** Yes
9. **Save**

Now at the top of dashboard you'll have a dropdown to filter by host!

---

## Expected Results

### Before Deployment:
```
Monitored containers: ~5-10 (only Raspberry Pi)
Monitored hosts: 1
Log visibility: 20% of infrastructure
```

### After Deployment:
```
Monitored containers: 25-30+ (all hosts)
Monitored hosts: 3
Log visibility: 100% of infrastructure
```

**Dashboard will show:**
- Errors from Unraid containers (postgresql, mariadb, nginx, etc.)
- SSH attempts on all 3 hosts
- Container restarts across infrastructure
- Security events from all devices

---

## Troubleshooting

### Issue: Promtail not starting on Unraid

**Check logs:**
```bash
docker logs promtail-unraid
```

**Common fixes:**
- Ensure `/var/run/docker.sock` exists
- Check Loki is reachable: `curl http://192.168.0.52:3100/ready`
- Verify config syntax: `docker exec promtail-unraid promtail -config.file=/etc/promtail/config.yml -dry-run`

### Issue: No logs from Unraid in Loki

**Test Promtail → Loki connection:**
```bash
# On Unraid
docker exec promtail-unraid wget -O- http://192.168.0.52:3100/ready

# Check Promtail metrics
curl http://192.168.0.51:9080/metrics | grep promtail_sent_entries_total
```

### Issue: Firewall blocking Loki port 3100

**Open port on media server:**
```bash
# On media server
sudo ufw allow from 192.168.0.0/24 to any port 3100
sudo ufw status
```

---

## Security Considerations

### Network Security:
- ✅ Loki only accessible from LAN (192.168.0.0/24)
- ✅ No authentication required (LAN-only is acceptable)
- ⚠️ **Future:** Add Tailscale access only for remote monitoring

### Data Retention:
- **Current:** Loki default retention (unlimited, disk-based)
- **Recommendation:** Set retention to 30 days
  ```yaml
  # In Loki config
  limits_config:
    retention_period: 720h  # 30 days
  ```

### Sensitive Data in Logs:
- ⚠️ **Risk:** Database credentials, API keys in container logs
- **Mitigation:** Configure apps to not log secrets
- **Future:** Implement log redaction rules in Promtail

---

## Interview Talking Points

**When demonstrating this setup:**

*"I deployed a centralized logging architecture using Grafana Loki across my entire homelab infrastructure. I have Promtail agents on three hosts - a Raspberry Pi running Home Assistant and security tools, my Unraid server with 18+ containerized applications including databases and reverse proxies, and a dedicated media server running the monitoring stack itself.*

*All logs aggregate to a central Loki instance, giving me a single pane of glass for security monitoring. This architecture mirrors enterprise SIEM deployments - distributed collection with centralized analysis. The dashboard shows security events correlated across all infrastructure, so I can detect lateral movement or multi-stage attacks.*

*For example, if someone tried to brute-force SSH on the Raspberry Pi, then attempted to access the database on Unraid, I'd see both events in the same timeline. That's the power of centralized monitoring."*

**Key metrics to mention:**
- 3 monitored hosts
- 25-30+ monitored containers
- 100% infrastructure visibility
- Single dashboard for all security events
- Real-time alerting across entire environment

---

## Next Steps After Deployment

1. ✅ **Deploy Promtail to Unraid** (30 min)
2. ✅ **Deploy Promtail to Media Server** (15 min)
3. ✅ **Update Grafana dashboard** (15 min)
4. ✅ **Test with simulated attacks** (30 min)
5. ⏭️ **Deploy Wazuh for advanced SIEM** (2-3 hours)
6. ⏭️ **Create alert rules** (1 hour)
7. ⏭️ **Document in portfolio** (30 min)

---

## Cost & Resource Impact

**Additional Resources Required:**
- Promtail on Unraid: ~50MB RAM, negligible CPU
- Promtail on Media Server: ~50MB RAM, negligible CPU
- Loki storage: ~1-2GB/day for 25+ containers (30-60GB/month)

**Disk Space Planning:**
```
Current usage: Unknown
Expected with 3 hosts: ~50GB/month
Retention: 30 days
Total storage needed: ~60GB (with buffer)
```

**Network Bandwidth:**
- Promtail → Loki: ~1-5 Mbps per host (LAN traffic)
- Negligible impact on 1Gbps network

---

## Alternative: Lightweight Monitoring (If Resource Constrained)

If disk space or resources are limited:

**Option 1: Sample logs instead of all logs**
```yaml
# In Promtail config, add pipeline stage:
pipeline_stages:
  - match:
      selector: '{job="docker"}'
      stages:
        - sampling:
            rate: 0.5  # Keep only 50% of logs
```

**Option 2: Only monitor critical containers**
```yaml
# Filter by container name
relabel_configs:
  - source_labels: ["__meta_docker_container_name"]
    regex: '.*(postgres|mariadb|nginx|adminer).*'
    action: keep
```

**Option 3: Shorter retention**
```yaml
# 7 days instead of 30
retention_period: 168h
```

---

## Success Criteria

**You'll know deployment succeeded when:**

1. ✅ Dashboard shows logs from all 3 hostnames
2. ✅ "Top 10 Containers by Error Count" includes Unraid containers
3. ✅ Can filter dashboard by hostname variable
4. ✅ SSH failed login detection works on all hosts
5. ✅ Security event logs show entries from all infrastructure

**Test with:**
```bash
# Generate SSH failures on all hosts
ssh baduser@192.168.0.19
ssh baduser@192.168.0.51
ssh baduser@192.168.0.52

# Check dashboard shows all 3 hosts reporting failed SSH
```

---

## Documentation & Portfolio Value

**GitHub Updates After Deployment:**

Create new session document:
```
sessions/SESSION-11-MULTI-DEVICE-MONITORING.md
- Deployment architecture diagram
- Before/after metrics
- Screenshots showing all 3 hosts
- Troubleshooting steps used
- Lessons learned
```

**Update README.md:**
```markdown
### Infrastructure Monitoring
- ✅ Centralized logging (Loki) across 3 hosts
- ✅ 25+ containers monitored in real-time
- ✅ Unified security dashboard (Grafana)
- ✅ Multi-host correlation for incident response
```

**Interview Screenshots to Take:**
1. Dashboard showing all 3 hostnames
2. "Log Volume by Host" panel with data from all hosts
3. Security events table with entries from multiple hosts
4. Filter dropdown showing hostname selection

---

**Deployment Ready!** Let me know when you want to start with Unraid Promtail deployment.
