# Home SOC Quick Start Guide

## Current Status: 3/9 Devices Monitored ✅

### What's Working
- ✅ **Raspberry Pi** (192.168.0.19) - Fully monitored
- ✅ **Unraid Server** (192.168.0.51) - Fully monitored (18+ containers)
- ✅ **capcorp9000** (192.168.0.52) - Logs working, metrics blocked by firewall

### Immediate Action Required

**Fix capcorp9000 Metrics (2 minutes):**
```bash
# Run on capcorp9000
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.0/24" port port="9100" protocol="tcp" accept'
sudo firewall-cmd --reload

# Verify it worked (wait 15 seconds, then check)
ssh automation@100.112.203.63 "curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.hostname==\"capcorp9000\") | .health'"
# Should show: "up"
```

---

## Quick Access URLs

- **Grafana Dashboard:** http://192.168.0.19:3000
- **Prometheus:** http://192.168.0.19:9090
- **Loki:** http://192.168.0.19:3100

---

## Verify Everything is Working

```bash
# Check which hostnames are reporting logs
ssh automation@100.112.203.63 "curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq"

# Check which hosts Prometheus is scraping
ssh automation@100.112.203.63 "curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {host: .labels.hostname, health: .health}'"

# Check containers on this PC
docker ps | grep -E '(promtail|node-exporter)'
```

---

## Add More Devices

**For Linux workstations (.13, .95, .119, .202):**
```bash
# Make sure they're powered on and SSH is configured
./scripts/deploy-monitoring-linux-workstations.sh
```

**For macOS (.21) or Windows (.245):**
See detailed instructions in `docs/DEVICE-ONBOARDING-RUNBOOK.md`

---

## Useful Queries

### In Grafana (Loki data source):
```
# All logs from Unraid
{hostname="unraid-server"}

# SSH failed logins across all hosts
{syslog_identifier="sshd"} |~ "(?i)failed|connection closed.*preauth"

# Container errors from all hosts
{job="docker"} |~ "(?i)error|fail"

# Logs from specific container
{container="vaultwarden"}
```

### In Grafana (Prometheus data source):
```
# CPU usage by host
100 - (avg by (hostname) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage by host
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
100 - ((node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes) * 100)
```

---

## Troubleshooting

**Logs not appearing?**
```bash
docker logs promtail-<hostname> --tail 20
```

**Metrics not appearing?**
```bash
# Check firewall
sudo firewall-cmd --list-all | grep 9100

# Test locally
curl http://localhost:9100/metrics | head
```

**Device offline?**
```bash
ping 192.168.0.<IP>
```

---

## Full Documentation

- **Complete Runbook:** `docs/DEVICE-ONBOARDING-RUNBOOK.md`
- **Session Details:** `sessions/SESSION-10-HOME-SOC-DEPLOYMENT.md`
- **Security Dashboard Guide:** `docs/GRAFANA-SECURITY-DASHBOARD-GUIDE.md`

---

## Interview Prep

**Key Talking Points:**
1. Centralized SIEM architecture (Loki + Prometheus + Grafana)
2. Multi-OS monitoring (Linux/macOS/Windows strategies)
3. Security event detection (SSH attacks, container errors)
4. Infrastructure automation (deployment scripts, config templates)
5. Scaling considerations (how this grows to enterprise)

**Demo Flow:**
1. Show Grafana dashboard with 3 hostnames
2. Query for SSH failed logins: `{syslog_identifier="sshd"} |~ "Failed"`
3. Show container logs: `{hostname="unraid-server", job="docker"}`
4. Show metrics: CPU/memory/disk usage across hosts
5. Explain architecture diagram and scaling

---

## What's Next

1. ⚠️ **Fix firewall on capcorp9000** (run commands above)
2. 🔄 **Deploy to other workstations** when powered on
3. 📊 **Create Infrastructure Health dashboard** in Grafana
4. 📸 **Take screenshots** for interview portfolio
5. 🎯 **Practice explaining** the architecture for interviews
