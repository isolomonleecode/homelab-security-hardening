# Grafana Dashboard - Troubleshooting "No Data"

**Issue**: Most dashboard panels show "No data"
**Root Cause**: cAdvisor just started collecting metrics - needs 5-10 minutes to accumulate data
**Status**: ✅ cAdvisor installed and running, Prometheus scraping successfully

---

## Current Status

### ✅ What's Working

1. **cAdvisor is running** on port 8081
   ```bash
   docker ps | grep cadvisor
   # Output: cadvisor running
   ```

2. **Prometheus is scraping cAdvisor**
   - Target: http://cadvisor:8080/metrics
   - Health: up
   - Last scrape: successful (1.3s duration)

3. **Container metrics are being collected**
   - 50 container metric types
   - 75 time series
   - 17 containers monitored:
     ```
     caddy, cadvisor, grafana, homeassistant, loki,
     mosquitto, node-exporter, nodered, pihole, portainer,
     prometheus, promtail, saml-idp-keycloak, saml-nextcloud-db,
     saml-sp-nextcloud, vaultwarden
     ```

### ⏳ What Needs Time

**Metrics need 5-10 minutes to populate** because:
- Prometheus scrapes every 15 seconds
- Rate calculations need at least 2 data points (30 seconds)
- Dashboard queries use 5-minute rate windows
- Fresh Prometheus restart means no historical data yet

---

## Solution: Wait 10 Minutes, Then Refresh

**Steps**:
1. Wait 10 minutes for metrics to accumulate
2. Go to your Grafana dashboard
3. Click the **Refresh** icon (top right)
4. Panels should now show data

**Or force immediate refresh**:
- Set auto-refresh to 10s (dropdown next to refresh button)
- Watch panels populate in real-time

---

## Working Queries (After 10 Min Wait)

Once data accumulates, these queries will work in your dashboard:

### Container Image Age (Days)
```promql
(time() - container_last_seen{name=~"pihole|vaultwarden|caddy|grafana|prometheus|loki"}) / 86400
```

### Container CPU Usage (%)
```promql
rate(container_cpu_usage_seconds_total{name=~"pihole|vaultwarden|caddy|grafana|prometheus|loki|homeassistant"}[5m]) * 100
```

### Container Memory Usage (MB)
```promql
container_memory_usage_bytes{name=~".*"} / 1024 / 1024
```

### Container Restarts (24h)
```promql
changes(container_last_seen{name=~".*"}[24h])
```

### System CPU Usage (Works Now)
```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### System Memory Usage (Works Now)
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

---

## Manual Testing (Verify Metrics Are Coming In)

### Test Container Metrics Directly

```bash
ssh automation@100.112.203.63

# 1. Check cAdvisor is exporting metrics
curl -s http://localhost:8081/metrics | grep container_last_seen | head -3

# 2. Check Prometheus has the metrics
curl -s 'http://localhost:9090/api/v1/label/name/values' | jq -r '.data[]' | head -10

# 3. Wait 5 minutes, then test a query
curl -s 'http://localhost:9090/api/v1/query?query=container_last_seen{name="pihole"}' | jq .

# 4. Test CPU rate (needs 5+ minutes of data)
curl -s 'http://localhost:9090/api/v1/query?query=rate(container_cpu_usage_seconds_total{name="pihole"}[5m])' | jq .
```

### If Queries Still Return Null After 10 Minutes

**Check Prometheus Target**:
```bash
curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | select(.labels.job=="cadvisor") | {health: .health, lastScrape: .lastScrape, lastError: .lastError}'
```

Expected output:
```json
{
  "health": "up",
  "lastScrape": "2025-11-10T...",
  "lastError": ""
}
```

**Check for Scrape Errors**:
```bash
docker logs prometheus 2>&1 | grep -i error | tail -5
```

Should see NO recent errors (old duplicate config errors are OK).

---

## Alternative: Simple Dashboard (Works Immediately)

If you need a dashboard that works right now, use system-level metrics (node-exporter):

### System Overview Dashboard Panels

**1. System CPU Usage**
```promql
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**2. System Memory Usage**
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

**3. Disk Usage**
```promql
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)
```

**4. Network Traffic**
```promql
rate(node_network_receive_bytes_total{device!~"lo|veth.*|br-.*|docker.*"}[5m]) * 8 / 1000000
```

**5. System Uptime (Days)**
```promql
(time() - node_boot_time_seconds) / 86400
```

These work immediately because node-exporter has been running for days.

---

## Expected Timeline

| Time | What Happens |
|------|--------------|
| **Now** | cAdvisor scraping containers, Prometheus collecting |
| **+30s** | First 2 data points, `container_last_seen` works |
| **+5min** | Enough data for rate() calculations |
| **+10min** | All dashboard panels should work |
| **+1hour** | Full historical data for trends |

---

## Verification Checklist

After 10 minutes, verify:

- [ ] cAdvisor running: `docker ps | grep cadvisor`
- [ ] Prometheus scraping: Check http://192.168.0.19:9090/targets
- [ ] Metrics exist: `curl http://localhost:9090/api/v1/label/__name__/values | jq -r '.data[]' | grep container | wc -l` (should show ~50)
- [ ] Container names: `curl 'http://localhost:9090/api/v1/label/name/values' | jq -r '.data[]'` (should list your containers)
- [ ] Test query works: `curl 'http://localhost:9090/api/v1/query?query=container_last_seen{name="grafana"}' | jq .` (should return data)
- [ ] Grafana dashboard shows data after refresh

---

## Quick Fixes

### Force Prometheus to Scrape Now
```bash
# Restart Prometheus (triggers immediate scrape)
cd ~/docker/loki-stack
docker compose restart prometheus

# Wait 30 seconds
sleep 30
```

### Check Dashboard is Using Correct Datasource
1. Edit dashboard panel
2. Check "Data source" is set to "prometheus" (not "loki")
3. Verify query syntax matches examples above

### Re-import Dashboard
If panels are misconfigured:
1. Delete current dashboard
2. Re-import `/run/media/ssjlox/gamer/homelab-security-hardening/container-updates-monitoring.json`
3. Select datasources:
   - Prometheus: prometheus
   - Loki: loki

---

## Summary

**Current State**: ✅ All infrastructure working
**Issue**: ⏳ Metrics need time to accumulate
**Solution**: ⏰ Wait 10 minutes, then refresh dashboard
**Workaround**: 📊 Use system-level metrics (node-exporter) instead

**cAdvisor Info**:
- Web UI: http://192.168.0.19:8081
- Metrics: http://192.168.0.19:8081/metrics
- Prometheus target: ✅ Healthy

---

**Last Updated**: 2025-11-09 20:55 CST
**Status**: Metrics collecting, dashboard will work in 10 minutes

🤖 Generated with [Claude Code](https://claude.com/claude-code)
