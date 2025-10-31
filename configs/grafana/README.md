# Grafana Security Monitoring Dashboard

This directory contains Grafana dashboard configurations for homelab security monitoring.

---

## Dashboard: Homelab Security Monitoring

**File**: `security-monitoring-dashboard.json`
**UID**: `homelab-security`
**Purpose**: Real-time security event monitoring and threat detection

### Dashboard Panels

#### 1. SSH Failed Login Attempts (24h) - Gauge
- **Metric**: Count of failed SSH password attempts in last 24 hours
- **Data Source**: Loki (systemd-journal logs from Raspberry Pi)
- **Alert Thresholds**:
  - Green: 0-80 attempts
  - Red: 80+ attempts (indicates brute-force attack)
- **LogQL Query**:
  ```logql
  count_over_time({job="systemd-journal", hostname="sweetrpi-desktop"} |~ "Failed password" [24h])
  ```

#### 2. Failed SSH Login Attempts Over Time - Time Series
- **Metric**: Failed SSH login rate (per 5 minutes)
- **Data Source**: Loki
- **Purpose**: Detect brute-force attack patterns
- **LogQL Query**:
  ```logql
  sum by (hostname) (count_over_time({job="systemd-journal"} |~ "Failed password" [5m]))
  ```

#### 3. fail2ban Ban Events - Table
- **Metric**: Recent IP bans by fail2ban
- **Data Source**: Loki (systemd-journal)
- **Purpose**: Track automated threat mitigation
- **LogQL Query**:
  ```logql
  {job="systemd-journal", hostname="sweetrpi-desktop"} |~ "Ban" | logfmt | line_format "{{.timestamp}} | {{.message}}"
  ```

#### 4. Container Error/Warning Rate - Time Series
- **Metric**: Error and warning log rate per container
- **Data Source**: Loki (Docker logs)
- **Purpose**: Detect container compromise or malfunction
- **LogQL Query**:
  ```logql
  sum by (container_name) (count_over_time({job="docker"} |~ "error|warning|critical" [5m]))
  ```

#### 5. Container Restart Events - Table
- **Metric**: Container start/stop/restart events
- **Data Source**: Loki (Docker logs)
- **Purpose**: Detect container crashes or deliberate restarts (attack indicator)
- **LogQL Query**:
  ```logql
  {job="docker"} |~ "(restart|started|stopped)" | logfmt | line_format "{{.timestamp}} | {{.container_name}} | {{.action}}"
  ```

#### 6. CPU Usage (Raspberry Pi) - Gauge
- **Metric**: Current CPU utilization percentage
- **Data Source**: Prometheus (node_exporter)
- **Alert Thresholds**:
  - Green: 0-50%
  - Yellow: 50-80%
  - Red: 80-100% (potential cryptominer or DoS)
- **PromQL Query**:
  ```promql
  100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
  ```

#### 7. Memory Usage (Raspberry Pi) - Gauge
- **Metric**: Current memory utilization percentage
- **Data Source**: Prometheus (node_exporter)
- **Alert Thresholds**:
  - Green: 0-70%
  - Yellow: 70-85%
  - Red: 85-100% (potential DoS or memory leak)
- **PromQL Query**:
  ```promql
  (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
  ```

#### 8. Recent Failed SSH Logins (Details) - Table
- **Metric**: Username and source IP of failed SSH attempts
- **Data Source**: Loki (systemd-journal)
- **Purpose**: Identify targeted accounts and attack sources
- **LogQL Query**:
  ```logql
  {job="systemd-journal", hostname="sweetrpi-desktop"} |~ "Failed password for" | regexp "Failed password for (?P<user>\\S+) from (?P<ip>\\S+)" | line_format "User: {{.user}} | IP: {{.ip}}"
  ```

#### 9. Pi-hole DNS Query Types - Time Series
- **Metric**: DNS query rate by type (A, AAAA, PTR, etc.)
- **Data Source**: Prometheus (pi-hole exporter - if installed)
- **Purpose**: Detect DNS tunneling or exfiltration attempts
- **PromQL Query**:
  ```promql
  sum by (query_type) (rate(pihole_queries_total[5m]))
  ```

#### 10. Pi-hole Block Percentage - Pie Chart
- **Metric**: Percentage of DNS queries blocked vs allowed
- **Data Source**: Prometheus (pi-hole exporter)
- **Purpose**: Monitor ad/malware blocking effectiveness
- **PromQL Query**:
  ```promql
  sum(pihole_domains_blocked) / sum(pihole_queries_total) * 100
  ```

---

## Prerequisites

### Data Sources Required

#### 1. Loki (Log Aggregation)
- **Already Configured**: ✅ Loki running on 192.168.0.52:3100
- **Configuration**: See [monitoring-logging.md](../../docs/06-monitoring-logging.md)

#### 2. Promtail (Log Shipping)
- **Already Configured**: ✅ Promtail on Raspberry Pi shipping Docker logs
- **Status**: Working (verified in Session 4)
- **Additional Configuration Needed**: Add systemd-journal scraping

#### 3. Prometheus (Metrics)
- **Status**: ⚠️ **NOT YET INSTALLED**
- **Required For**: CPU/Memory gauges, Pi-hole metrics
- **Installation**: See below

#### 4. Node Exporter (System Metrics)
- **Status**: ⚠️ **NOT YET INSTALLED**
- **Required For**: Raspberry Pi CPU/Memory monitoring
- **Installation**: See below

---

## Installation Instructions

### Step 1: Import Dashboard to Grafana

#### Option A: Via Grafana UI (Recommended)
1. Access Grafana: http://grafana.homelab.local:8083
2. Navigate to: **Dashboards → Import**
3. Click **Upload JSON file**
4. Select: `security-monitoring-dashboard.json`
5. Configure data sources:
   - Loki: Select your Loki instance (192.168.0.52:3100)
   - Prometheus: Configure after installation (Step 2)
6. Click **Import**

#### Option B: Via API
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <GRAFANA_API_KEY>" \
  -d @security-monitoring-dashboard.json \
  http://grafana.homelab.local:8083/api/dashboards/db
```

---

### Step 2: Install Prometheus (Optional - for CPU/Memory metrics)

Prometheus is required for panels 6, 7, 9, and 10.

#### On Grafana Host (192.168.0.52)

```bash
# SSH to Grafana host
ssh user@192.168.0.52

# Create Prometheus directory
mkdir -p ~/docker/prometheus
cd ~/docker/prometheus

# Create Prometheus configuration
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'raspberry-pi'
    static_configs:
      - targets: ['192.168.0.19:9100']  # node_exporter on Pi

  - job_name: 'pihole'
    static_configs:
      - targets: ['192.168.0.19:9617']  # pihole-exporter (if installed)
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'

volumes:
  prometheus-data:
EOF

# Start Prometheus
docker-compose up -d

# Verify
curl http://localhost:9090/-/healthy
# Should return "Prometheus is Healthy."
```

---

### Step 3: Install Node Exporter (Raspberry Pi)

Node Exporter provides CPU, memory, disk, and network metrics.

```bash
# SSH to Raspberry Pi
ssh automation@192.168.0.19

# Create node_exporter directory
mkdir -p ~/docker/node-exporter
cd ~/docker/node-exporter

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    volumes:
      - /:/host:ro,rslave
    command:
      - '--path.rootfs=/host'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

EOF

# Start node-exporter
docker-compose up -d

# Verify
curl http://localhost:9100/metrics | head -20
# Should show metrics like: node_cpu_seconds_total
```

---

### Step 4: Configure Promtail for systemd-journal Logs

Promtail needs additional configuration to scrape SSH logs from systemd-journal.

```bash
# SSH to Raspberry Pi
ssh automation@192.168.0.19

# Edit Promtail configuration
cd ~/docker/promtail
nano promtail-config.yml

# Add this scrape_config section (in addition to existing Docker scrape):
```

```yaml
scrape_configs:
  # Existing Docker scrape config...
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*-json.log

  # NEW: systemd-journal scrape config for SSH logs
  - job_name: systemd-journal
    journal:
      path: /var/log/journal
      max_age: 12h
      labels:
        job: systemd-journal
        hostname: sweetrpi-desktop
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__hostname']
        target_label: 'hostname'
```

**Update docker-compose.yml** to mount journal directory:

```yaml
services:
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./promtail-config.yml:/etc/promtail/promtail-config.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/log/journal:/var/log/journal:ro  # ADD THIS LINE
    command:
      - '-config.file=/etc/promtail/promtail-config.yml'
```

**Restart Promtail**:
```bash
docker-compose restart promtail

# Verify systemd-journal logs are being shipped
curl 'http://grafana.homelab.local:3100/loki/api/v1/query?query={job="systemd-journal"}' | jq
```

---

### Step 5: Add Prometheus Data Source to Grafana

1. Access Grafana: http://grafana.homelab.local:8083
2. Navigate to: **Configuration → Data Sources**
3. Click **Add data source**
4. Select **Prometheus**
5. Configure:
   - **Name**: prometheus
   - **URL**: http://192.168.0.52:9090
   - **Access**: Server (default)
6. Click **Save & Test**
7. Should show: ✅ "Data source is working"

---

### Step 6: Optional - Install Pi-hole Exporter

For panels 9 and 10 (Pi-hole DNS metrics):

```bash
# SSH to Raspberry Pi
ssh automation@192.168.0.19

mkdir -p ~/docker/pihole-exporter
cd ~/docker/pihole-exporter

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  pihole-exporter:
    image: ekofr/pihole-exporter:latest
    container_name: pihole-exporter
    restart: unless-stopped
    ports:
      - "9617:9617"
    environment:
      PIHOLE_HOSTNAME: 192.168.0.19
      PIHOLE_PORT: 8080
      PIHOLE_PASSWORD: <PIHOLE_ADMIN_PASSWORD>
      INTERVAL: 30s
EOF

# Start exporter
docker-compose up -d

# Verify
curl http://localhost:9617/metrics | grep pihole
```

**Update Prometheus** to scrape Pi-hole exporter (already configured in Step 2).

---

## Dashboard Usage

### Detecting Brute-Force SSH Attacks

**Indicators**:
- **Panel 1** (gauge): Failed attempts > 80 in 24h
- **Panel 2** (graph): Sudden spike in failed login rate
- **Panel 8** (table): Repeated attempts from same IP

**Response**:
1. Check fail2ban bans (Panel 3) - automated mitigation
2. Review source IP geolocation
3. Add permanent UFW block if persistent:
   ```bash
   sudo ufw deny from <ATTACKER_IP> comment 'Blocked - brute force'
   ```

---

### Detecting Container Compromise

**Indicators**:
- **Panel 4**: Sudden increase in error/warning rate for a container
- **Panel 5**: Unexpected container restarts
- **Panel 6/7**: CPU or memory spike to 100%

**Response**:
1. Check container logs in Loki:
   ```logql
   {job="docker", container_name="<CONTAINER>"} | grep -i "error|warning"
   ```
2. Inspect container for malicious processes:
   ```bash
   docker exec <container> ps aux
   ```
3. Check for cryptominer indicators:
   ```bash
   docker exec <container> netstat -tunap | grep -E '(3333|4444|5555)'
   ```

---

### Detecting DNS Exfiltration (Panel 9)

**Indicators**:
- Unusual DNS query types (TXT, NULL records)
- High volume of DNS queries from single container
- Queries to suspicious domains

**Response**:
1. Review Pi-hole query log
2. Identify source container
3. Inspect container for malicious activity

---

## Alert Configuration (Future)

Grafana alerting can be configured to send notifications for:

### Alert 1: SSH Brute-Force Attack
- **Condition**: Failed SSH attempts > 50 in 1 hour
- **Action**: Email + Slack notification
- **Query**:
  ```logql
  count_over_time({job="systemd-journal"} |~ "Failed password" [1h]) > 50
  ```

### Alert 2: Container High CPU Usage
- **Condition**: CPU > 80% for 5 minutes
- **Action**: Email notification
- **Query**:
  ```promql
  100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  ```

### Alert 3: Container Restart Loop
- **Condition**: Container restarted > 3 times in 10 minutes
- **Action**: Email + PagerDuty
- **Query**:
  ```logql
  count_over_time({job="docker"} |~ "restart" [10m]) > 3
  ```

---

## Troubleshooting

### Dashboard Shows "No Data"

**Possible Causes**:
1. **Loki not receiving logs**
   - Check Promtail status: `docker logs promtail`
   - Verify Loki is running: `curl http://192.168.0.52:3100/ready`
   - Test log query: `curl 'http://192.168.0.52:3100/loki/api/v1/query?query={job="docker"}'`

2. **Prometheus not scraping**
   - Check Prometheus targets: http://192.168.0.52:9090/targets
   - Verify node_exporter is running: `docker ps | grep node-exporter`
   - Test metrics: `curl http://192.168.0.19:9100/metrics`

3. **Data source not configured**
   - Grafana → Configuration → Data Sources
   - Ensure Loki and Prometheus are configured correctly

### Panel Shows "Query error"

Check **Query Inspector** in Grafana:
1. Click panel title → Inspect → Query
2. Review error message
3. Common issues:
   - Incorrect label names in LogQL/PromQL
   - Data source not selected
   - Time range too narrow (expand to 24h)

---

## Maintenance

### Weekly Tasks
- Review dashboard for anomalies
- Check fail2ban ban count (Panel 3)
- Verify all panels showing data

### Monthly Tasks
- Review alert thresholds (adjust if too noisy)
- Clean up old Loki logs (retention: 30 days)
- Update Prometheus/Grafana/Loki images

### Quarterly Tasks
- Test disaster recovery (restore from backup)
- Review security event trends
- Update dashboard with new panels as needed

---

## Related Documentation

- [Monitoring & Logging Setup](../../docs/06-monitoring-logging.md)
- [Session 4: Raspberry Pi Hardening](../../sessions/SESSION-4-RASPBERRY-PI-HARDENING.md)
- [Vulnerability Assessment](../../findings/CONSOLIDATED-VULNERABILITY-REPORT.md)

---

## Future Enhancements

### Phase 2: Additional Panels
1. **Vaultwarden Login Attempts** - Track password vault access
2. **UFW Blocked Connections** - Monitor firewall blocks
3. **Docker Image Vulnerability Count** - Track CVEs from Trivy scans
4. **Nginx Proxy Manager Access Logs** - HTTP request patterns

### Phase 3: Advanced Analytics
1. **Machine Learning Anomaly Detection** - Detect unusual patterns
2. **GeoIP Mapping** - Visualize attack sources on world map
3. **Correlation Analysis** - Link events across multiple services
4. **Automated Incident Response** - Trigger scripts on alerts

---

## Credits

Dashboard created for homelab security hardening project by isolomonleecode.

**Status**: ✅ **READY FOR INSTALLATION** (Prometheus/node_exporter required for full functionality)
