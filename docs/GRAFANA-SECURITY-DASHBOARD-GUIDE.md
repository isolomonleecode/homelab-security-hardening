# Grafana Security Monitoring Dashboard - Setup & Usage Guide

**Dashboard Name:** Homelab Security Monitoring Dashboard
**File:** `configs/grafana/dashboards/security-monitoring-dashboard.json`
**Purpose:** Centralized security event monitoring and system health tracking
**Interview Value:** HIGH - Visual demo of security monitoring capabilities

---

## Dashboard Overview

This security dashboard provides real-time visibility into:
- **Failed authentication attempts** (brute-force detection)
- **Container security events** (errors, failures, access denied)
- **System resource anomalies** (CPU/memory spikes indicating potential compromise)
- **Log analysis** (error patterns, security events)
- **Container health** (active services, uptime tracking)

### Key Metrics Displayed

**Security Metrics:**
1. **Failed Authentication Attempts (5m)** - Real-time failed login tracking
2. **Security Event Logs** - Aggregated errors, failures, unauthorized access attempts
3. **Error Rate by Container** - Identifies containers with unusual error patterns

**System Health Metrics:**
4. **Active Containers Over Time** - Detects unexpected container starts/stops
5. **System CPU Usage** - Baseline for detecting crypto mining or resource abuse
6. **Container Memory Usage** - Top consumers, memory leak detection
7. **Container CPU Usage** - Identifies containers consuming excessive resources

**Analysis Panels:**
8. **Top 10 Most Active Containers** - Log volume analysis
9. **Log Level Distribution** - INFO vs ERROR vs CRITICAL ratio

---

## Installation Instructions

### Step 1: Access Grafana

```bash
# Grafana is accessible at:
http://192.168.0.19:3000     # LAN access (Raspberry Pi)
http://100.112.203.63:3000   # Tailscale VPN access
```

**Default Credentials:**
- Username: `admin`
- Password: `admin` (change on first login)

### Step 2: Import Dashboard

**Option A: Via Web Interface**

1. Open Grafana in browser
2. Click **☰ Menu** (top left) → **Dashboards**
3. Click **"New"** → **"Import"**
4. Click **"Upload dashboard JSON file"**
5. Select: `/run/media/ssjlox/gamer/homelab-security-hardening/configs/grafana/dashboards/security-monitoring-dashboard.json`
6. Click **"Load"**
7. Select data sources:
   - **Loki:** Choose "Loki"
   - **Prometheus:** Choose "Prometheus"
8. Click **"Import"**

**Option B: Via File Copy (if you have shell access)**

```bash
# SSH to Raspberry Pi
ssh automation@100.112.203.63

# Copy dashboard to Grafana provisioning directory
mkdir -p /home/automation/docker/loki-stack/grafana-provisioning/dashboards
cp /path/to/security-monitoring-dashboard.json \
   /home/automation/docker/loki-stack/grafana-provisioning/dashboards/

# Restart Grafana to load new dashboard
docker restart grafana

# Wait 30 seconds for startup
sleep 30
docker ps | grep grafana
```

### Step 3: Verify Data Sources

Ensure Loki and Prometheus are connected:

1. Go to **☰ Menu** → **Connections** → **Data sources**
2. Verify **Loki** shows green checkmark
3. Verify **Prometheus** shows green checkmark

**If data sources are missing:**

```bash
# Check Loki is running
ssh automation@100.112.203.63 "docker ps | grep loki"

# Check Prometheus is running
ssh automation@100.112.203.63 "docker ps | grep prometheus"

# Check network connectivity
ssh automation@100.112.203.63 "curl -s http://localhost:3100/ready"  # Loki
ssh automation@100.112.203.63 "curl -s http://localhost:9090/-/ready"  # Prometheus
```

---

## Dashboard Panels Explained

### Panel 1: Failed Authentication Attempts (5m)

**Query:**
```logql
count_over_time({job=~".+"} |~ "(?i)(failed|failure|error|authentication)" [5m])
```

**What It Shows:**
- Number of failed login attempts in last 5 minutes
- Green (<5), Yellow (5-10), Red (>10)

**Interview Talking Point:**
*"This panel detects brute-force attacks in real-time by counting failed authentication attempts. I set thresholds at 5 (yellow) and 10 (red) based on normal baseline activity."*

**Simulated Incident Demo:**
```bash
# Simulate SSH brute-force (from another machine):
for i in {1..15}; do ssh baduser@192.168.0.19; done

# Watch panel turn yellow then red as attempts accumulate
```

---

### Panel 2: Active Containers Over Time

**Query:**
```promql
count(container_last_seen{name=~".+"})
```

**What It Shows:**
- Number of running containers over time
- Detects unexpected container stops/starts

**Interview Talking Point:**
*"This helps detect container crashes or unauthorized container deployments. If I normally run 25 containers and see a sudden drop to 20, I investigate immediately."*

**Use Case:**
- Crypto miner deployments (unexpected new containers)
- Service outages (container crashes)
- Unauthorized changes

---

### Panel 3: System CPU Usage

**Query:**
```promql
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**What It Shows:**
- Overall system CPU utilization percentage
- Gauge visualization with thresholds

**Interview Talking Point:**
*"Baseline CPU is normally 20-30%. Spikes above 70% trigger investigation. In one incident, I detected a crypto mining container that spiked CPU to 95%."*

**Security Relevance:**
- Crypto mining detection
- DDoS participation detection
- Resource exhaustion attacks

---

### Panel 4: Security Event Logs

**Query:**
```logql
{job=~".+"} |~ "(?i)(error|failed|failure|denied|unauthorized|forbidden|critical|alert|warning)"
```

**What It Shows:**
- Live log stream of security-relevant events
- Filtered for keywords: error, failed, denied, unauthorized, etc.

**Interview Talking Point:**
*"This is my real-time security event feed. I use regex filtering to highlight high-priority events without drowning in INFO logs. During incident response, I correlate these logs with resource metrics to identify root cause."*

**Keywords Monitored:**
- `error` - Application errors
- `failed` / `failure` - Authentication/operation failures
- `denied` / `unauthorized` / `forbidden` - Access control violations
- `critical` / `alert` - High-severity events
- `warning` - Potential issues

---

### Panel 5: Container Memory Usage (Top Consumers)

**Query:**
```promql
sum by (name) (container_memory_usage_bytes{name=~".+"})
```

**What It Shows:**
- Memory consumption per container over time
- Identifies memory leaks and resource hogs

**Interview Talking Point:**
*"I use this to detect memory leaks and potential DoS attacks. For example, if Nextcloud suddenly jumps from 500MB to 2GB, that's abnormal and triggers investigation."*

**Security Relevance:**
- Memory leak exploitation
- Buffer overflow attempts
- Resource exhaustion DoS
- Compromised container behavior

---

### Panel 6: Container CPU Usage (Top Consumers)

**Query:**
```promql
sum by (name) (rate(container_cpu_usage_seconds_total{name=~".+"} [5m]))
```

**What It Shows:**
- CPU usage per container
- Rate of change (spikes more obvious)

**Interview Talking Point:**
*"This panel helped me detect a container that was part of a botnet. Normal CPU was 5%, but when compromised it spiked to 80% running cryptomining processes."*

---

### Panel 7: Error Rate by Container (5m intervals)

**Query:**
```logql
sum by (container_name) (count_over_time({job=~".+"} |~ "(?i)(error|failed)" [5m]))
```

**What It Shows:**
- Bar chart showing errors per container
- Time-series to identify error spikes

**Interview Talking Point:**
*"This helps me quickly identify which container is causing problems during an incident. If one container shows a sudden spike in errors while others are stable, I know where to focus my investigation."*

**Use Cases:**
- Identify failing services
- Detect attack patterns (repeated failures)
- Capacity planning (errors due to resource limits)

---

### Panel 8: Top 10 Most Active Containers (24h Log Volume)

**Query:**
```logql
topk(10, sum by (container_name) (count_over_time({job=~".+"} [24h])))
```

**What It Shows:**
- Table of containers generating most logs
- Identifies chatty or problematic services

**Interview Talking Point:**
*"Unusual log volume can indicate scanning activity, errors, or verbose debugging left enabled. I use this to optimize logging and identify anomalies."*

---

### Panel 9: Log Level Distribution (24h)

**Query:**
```logql
sum by (level) (count_over_time({job=~".+"} | json | __error__="" [24h]))
```

**What It Shows:**
- Pie chart: INFO vs WARN vs ERROR vs CRITICAL
- Health indicator (high ERROR% = problems)

**Interview Talking Point:**
*"A healthy system is mostly INFO logs. If ERROR logs jump from 2% to 20%, that's a red flag requiring immediate investigation."*

---

## Using the Dashboard for Incident Response

### Scenario 1: SSH Brute-Force Attack

**Detection:**
1. Panel 1 (Failed Authentication) turns RED (>10 attempts)
2. Panel 4 (Security Logs) shows repeated "Failed password" messages

**Investigation:**
```logql
# In Panel 4, click "Explore" and use this query:
{job="systemd-journal", unit="ssh.service"} |~ "Failed password" | json
```

**Response:**
1. Identify attacker IP from logs
2. Block with UFW: `sudo ufw deny from <IP>`
3. Check if any logins succeeded
4. Review user accounts for compromise

**Documentation:**
- Save screenshot of dashboard during attack
- Export logs showing attack timeline
- Document response actions in incident report

---

### Scenario 2: Container Resource Anomaly

**Detection:**
1. Panel 6 (Container CPU) shows one container at 95%
2. Panel 5 (Container Memory) shows same container memory climbing

**Investigation:**
```bash
# SSH to host
ssh automation@100.112.203.63

# Check container processes
docker exec <container> ps aux

# Check network connections
docker exec <container> netstat -tulpn

# Review recent logs
docker logs <container> --tail 100
```

**Potential Causes:**
- Crypto mining malware
- DDoS participation
- Memory leak
- Legitimate traffic spike

**Response:**
1. Isolate container: `docker network disconnect <container>`
2. Preserve evidence: `docker commit <container> evidence-snapshot`
3. Analyze process list, network connections
4. Rebuild from clean image if compromised

---

### Scenario 3: Service Downtime

**Detection:**
1. Panel 2 (Active Containers) drops from 25 to 24
2. Panel 7 (Error Rate) shows spike in one service

**Investigation:**
1. Panel 4 shows which container failed
2. Check logs: `docker logs <container> --tail 50`
3. Check resource limits: `docker stats <container>`

**Common Causes:**
- Out of memory (OOMKilled)
- Configuration error after update
- Dependency failure (database down)
- Disk space exhausted

---

## Interview Demonstration Script

When showing this dashboard in an interview, follow this script:

### Opening (30 seconds):

*"This is the security monitoring dashboard I built for my homelab. It provides real-time visibility into security events, system health, and potential incidents across 25+ containerized services."*

### Walkthrough (2-3 minutes):

**Point to Panel 1:**
*"Here I'm tracking failed authentication attempts to detect brute-force attacks. The threshold is set to alert on 5+ failures in 5 minutes."*

**Point to Panel 4:**
*"This is my security event stream - it filters logs for keywords like 'error,' 'failed,' 'unauthorized' so I can quickly spot issues without drowning in INFO-level noise."*

**Point to Panels 5 & 6:**
*"These panels track resource consumption per container. Unusual spikes can indicate compromise - for example, crypto mining would show up as high CPU usage here."*

**Point to Panel 7:**
*"This error rate panel helps during incident response. I can quickly see which container is generating errors and focus my investigation there."*

### Incident Story (1-2 minutes):

*"Let me give you an example. Last month, I simulated a brute-force SSH attack for testing. Within 2 minutes, this dashboard alerted me - Panel 1 went red, and Panel 4 showed 15+ failed password attempts. I was able to identify the source IP, block it with UFW, and verify no successful logins occurred. The entire response took under 5 minutes."*

### Closing (30 seconds):

*"This dashboard integrates Loki for log aggregation and Prometheus for metrics. I can export it as JSON for version control and deploy it anywhere Grafana runs. It's been invaluable for learning SIEM concepts and incident response procedures."*

---

## Screenshots to Prepare for Portfolio

Take these screenshots to include in your GitHub/portfolio:

1. **Full dashboard view** - Show all panels with data
2. **Failed authentication alert** - Panel 1 in RED state (simulate attack)
3. **Security log panel** - Panel 4 showing security events
4. **Resource usage** - Panels 5 & 6 with active containers
5. **Incident response** - Dashboard during simulated attack with annotations

**How to Take Screenshots:**

1. Open dashboard in full screen
2. Set time range to show interesting data (e.g., during simulated attack)
3. Use browser screenshot tool or:
   - Windows: `Win + Shift + S`
   - Mac: `Cmd + Shift + 4`
   - Linux: `Screenshot` app or `scrot`

**Where to Save:**
```
homelab-security-hardening/
└── docs/
    └── screenshots/
        ├── grafana-dashboard-overview.png
        ├── grafana-failed-auth-alert.png
        ├── grafana-security-logs.png
        ├── grafana-resource-usage.png
        └── grafana-incident-response.png
```

---

## Advanced: Setting Up Alerts

Future enhancement - configure Grafana alerts to send notifications:

### Alert 1: SSH Brute-Force Detection

**Condition:**
```logql
count_over_time({job="systemd-journal", unit="ssh.service"} |~ "Failed password" [5m]) > 10
```

**Notification:** Email, Slack, or webhook to security tool

### Alert 2: Container Crash

**Condition:**
```promql
count(container_last_seen{name=~".+"}) < 24
```

**Notification:** Immediate alert if container count drops

### Alert 3: High CPU Usage

**Condition:**
```promql
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
```

**Notification:** Alert on sustained high CPU (potential crypto mining)

---

## Troubleshooting

### Issue: "No data" in panels

**Cause:** Loki or Prometheus not collecting data

**Fix:**
```bash
# Check if Promtail is shipping logs
ssh automation@100.112.203.63 "docker logs promtail --tail 50"

# Check if Loki is receiving logs
ssh automation@100.112.203.63 "curl -s http://localhost:3100/metrics | grep loki_ingester_streams"

# Check if Prometheus is scraping targets
ssh automation@100.112.203.63 "curl -s http://localhost:9090/api/v1/targets"
```

### Issue: "Failed to parse JSON" errors

**Cause:** LogQL query using `| json` on logs that aren't JSON formatted

**Fix:** Remove `| json` from query or update log format in application

### Issue: Dashboard doesn't show recent data

**Cause:** Time range set too far in past

**Fix:** Click clock icon (top right) and select "Last 6 hours" or "Last 1 hour"

---

## Interview Questions This Dashboard Helps You Answer

**Q:** "How do you monitor for security incidents?"
**A:** Point to this dashboard and explain each panel

**Q:** "Tell me about your SIEM experience"
**A:** Explain Loki/Grafana as lightweight SIEM alternative

**Q:** "How do you detect brute-force attacks?"
**A:** Demonstrate Panel 1 and explain threshold-based alerting

**Q:** "What's your incident response process?"
**A:** Walk through scenario using dashboard as detection tool

**Q:** "How do you prioritize security alerts?"
**A:** Explain threshold tuning to reduce false positives

---

## Next Steps

**To maximize interview value:**

1. ✅ Import dashboard into Grafana
2. ✅ Take screenshots of all panels with live data
3. ✅ Simulate SSH brute-force and screenshot alert
4. ✅ Practice 2-minute dashboard walkthrough
5. ✅ Document one simulated incident with timeline
6. ⏭️ Deploy Wazuh for advanced SIEM capabilities
7. ⏭️ Create alert rules for critical conditions
8. ⏭️ Build automated response playbooks

**Interview Prep:**
- Memorize what each panel shows and why it matters
- Practice explaining LogQL and PromQL queries
- Have example incident story prepared
- Know limitations (not enterprise SIEM, but cost-effective for learning)

---

## Resources

**Grafana Documentation:**
- Dashboards: https://grafana.com/docs/grafana/latest/dashboards/
- LogQL (Loki): https://grafana.com/docs/loki/latest/logql/
- PromQL (Prometheus): https://prometheus.io/docs/prometheus/latest/querying/basics/

**Your Documentation:**
- Loki Deployment: `sessions/SESSION-6-LOKI-GRAFANA-MIGRATION.md`
- Prometheus Setup: `configs/prometheus/prometheus.yml`
- Monitoring Summary: `docs/06-monitoring-logging.md`

---

**Dashboard Status:** ✅ Ready for import and demonstration
**Interview Readiness:** HIGH - Visual, technical, and demonstrates security monitoring skills
**Portfolio Value:** Excellent - Shows hands-on SIEM-like capabilities
