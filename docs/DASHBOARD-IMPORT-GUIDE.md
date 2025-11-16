# Grafana Dashboard Import Guide

## Quick Import Instructions

### Method 1: Via Grafana UI (Recommended)

1. **Open Grafana:** http://192.168.0.19:3000
2. **Navigate to Dashboards:**
   - Click the "+" icon in the left sidebar
   - Select "Import dashboard"
3. **Upload JSON:**
   - Click "Upload JSON file"
   - Select the dashboard file from `configs/grafana/dashboards/`
   - Click "Import"

### Method 2: Copy-Paste JSON

1. Open Grafana → Dashboards → Import
2. Copy the entire contents of the dashboard JSON file
3. Paste into the "Import via panel json" text box
4. Click "Load"
5. Click "Import"

---

## Available Dashboards

### 1. Security Monitoring Dashboard
**File:** `configs/grafana/dashboards/security-monitoring-v2.json`

**Panels:**
- SSH Failed Logins (5m)
- Container Errors (5m)
- Access Denied Events (5m)
- Total Container Logs (1h)
- Security Event Logs (streaming)
- Container Error Rate Over Time
- SSH Failed Attempts Over Time
- Top 10 Most Active Containers (24h)
- Top 10 Containers by Error Count (24h)
- SSH Activity Logs (All Events)

**Use Cases:**
- Real-time security event monitoring
- SSH brute-force attack detection
- Container error tracking
- Security incident investigation

---

### 2. Infrastructure Health Dashboard ⭐ NEW
**File:** `configs/grafana/dashboards/infrastructure-health.json`

**Panels:**
1. **CPU Usage by Host** (time series)
   - Shows CPU percentage trends for all 7 devices
   - 5-minute average with thresholds (60% yellow, 80% red)

2. **Memory Usage by Host** (time series)
   - Memory utilization trends
   - Thresholds: 70% yellow, 85% red

3. **Current CPU Usage** (gauges)
   - Live CPU percentage for each host
   - Color-coded by threshold

4. **Current Memory Usage** (gauges)
   - Live memory percentage for each host
   - Visual health indicators

5. **System Uptime** (stat)
   - Shows how long each device has been running
   - Green for >24h, yellow for >1h, red for <1h

6. **Disk Usage by Host** (table)
   - All filesystems across all devices
   - Sorted by usage percentage
   - Thresholds: 75% yellow, 90% red

7. **Network Traffic (Received)** (time series)
   - Network bandwidth per device and interface
   - Real-time traffic monitoring

8. **Log Volume by Host** (stacked bars)
   - Shows logging activity per device
   - Helps identify chatty systems

**Auto-refresh:** 30 seconds

**Use Cases:**
- Capacity planning (identify resource bottlenecks)
- Performance monitoring
- Anomaly detection (unusual CPU/memory spikes)
- Disk space management
- Network bandwidth monitoring

---

## Customizing Dashboards

### Change Refresh Rate

1. Click the clock icon (🕐) in the top right
2. Select refresh interval: 5s, 10s, 30s, 1m, 5m
3. Or disable auto-refresh

### Adjust Time Range

1. Click the time range dropdown (top right)
2. Select: Last 5m, 15m, 1h, 6h, 12h, 24h, 7d, 30d
3. Or use "Custom time range" for specific dates

### Add Variables (for hostname filtering)

1. Click dashboard settings (⚙️) → Variables
2. Click "Add variable"
3. **Name:** `hostname`
4. **Type:** Query
5. **Data source:** Prometheus
6. **Query:** `label_values(node_uname_info, hostname)`
7. **Multi-value:** Enable
8. **Include All option:** Enable
9. Save

Then update panel queries to use `{hostname=~"$hostname"}` instead of hardcoded hostnames.

---

## Troubleshooting

### "No data" in panels

**Check:**
1. Data source is configured: Dashboards → Data Sources
   - Loki: http://loki:3100
   - Prometheus: http://prometheus:9090

2. Time range includes data:
   - Try "Last 24 hours" to ensure you capture data

3. Queries are correct:
   - Edit panel → Check query syntax
   - Run query in Explore to test

### Metrics not showing for specific host

**Check Prometheus targets:**
```bash
ssh automation@100.112.203.63 "curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {host: .labels.hostname, health: .health}'"
```

All should show `"health": "up"`

If down:
- Check firewall on that host (port 9100 must be open to LAN)
- Check node_exporter is running: `docker ps | grep node-exporter`

### Logs not showing for specific host

**Check Loki labels:**
```bash
ssh automation@100.112.203.63 "curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq"
```

Should see all 7 hostnames.

If missing:
- Check Promtail is running on that host: `docker ps | grep promtail`
- Check Promtail logs: `docker logs promtail-<hostname>`

---

## Interview Talking Points

### Infrastructure Health Dashboard

**Question:** *"Tell me about a monitoring solution you've implemented."*

**Answer:**
*"I built a centralized infrastructure monitoring dashboard using Grafana, Prometheus, and Loki. The dashboard provides real-time visibility into 7 Linux devices across my homelab.*

*Key panels include:*
- *CPU and memory utilization trends with color-coded thresholds*
- *Disk usage table showing all filesystems, sorted by utilization*
- *Network bandwidth monitoring per interface*
- *Log volume analysis to identify anomalous activity*

*The dashboard auto-refreshes every 30 seconds and uses Prometheus for metrics collection with node_exporter agents on each device. This gives me sub-minute visibility into resource usage and helps with capacity planning.*

*For example, I can quickly identify if a device is running low on disk space (>90% triggers red) or if CPU usage is abnormally high, which might indicate a runaway process or security incident."*

---

### Security Monitoring Dashboard

**Question:** *"How do you detect security incidents in your environment?"*

**Answer:**
*"I deployed a security monitoring dashboard that correlates events across my entire infrastructure. It monitors SSH failed login attempts using LogQL queries against systemd journal logs, tracks container error rates, and provides real-time security event streaming.*

*The dashboard caught several SSH brute-force attempts where an unauthorized user tried to login as 'root' and my actual username. Since I have SSH configured for key-only authentication and root login disabled, the attempts were blocked, but the dashboard alerted me to the reconnaissance activity.*

*I can drill down from the overview to specific logs, filter by hostname, and investigate the timeline. This follows a SIEM-style workflow: detect, triage, investigate, respond."*

---

## Next Steps

After importing dashboards:

1. ✅ Verify all panels show data
2. ✅ Adjust time ranges as needed
3. ✅ Take screenshots for portfolio
4. ✅ Star/favorite important dashboards
5. ✅ Set up alerting (optional, see Grafana docs)

---

## Additional Resources

- **Grafana Dashboards:** https://grafana.com/docs/grafana/latest/dashboards/
- **PromQL Basics:** https://prometheus.io/docs/prometheus/latest/querying/basics/
- **LogQL Basics:** https://grafana.com/docs/loki/latest/logql/
- **Grafana Variables:** https://grafana.com/docs/grafana/latest/variables/
