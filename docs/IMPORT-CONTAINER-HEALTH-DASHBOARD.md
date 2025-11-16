# Import Container Health Monitoring Dashboard

**Quick guide to import and use the new dashboard**

---

## What This Dashboard Shows

- ✅ **Active container count** (should be 28+)
- ✅ **Update failures** from Watchtower (should be 0)
- ✅ **DNS resolution errors** (should be 0)
- ✅ **Container error rates** across all services
- ✅ **Real-time logs** from Watchtower and failed operations
- ✅ **Container lifecycle events** (start/stop/remove)

**Auto-refreshes every 30 seconds**

---

## Import Steps (2 minutes)

### Method 1: Via Grafana UI (Easiest)

1. **Open Grafana**: http://192.168.0.19:3000

2. **Navigate to Dashboards**:
   - Click hamburger menu (☰) → Dashboards

3. **Import Dashboard**:
   - Click "New" → "Import"

4. **Upload JSON**:
   - Click "Upload JSON file"
   - Select: `/run/media/ssjlox/gamer/homelab-security-hardening/configs/grafana/dashboards/container-health-monitoring.json`
   - Or copy/paste the contents

5. **Configure**:
   - Name: "Container Health Monitoring" (default)
   - Folder: General (or create "Infrastructure" folder)
   - Data source: **Loki** (select from dropdown)

6. **Click "Import"**

7. **Done!** Dashboard should load immediately

### Method 2: Via Command Line

```bash
# Copy dashboard to Grafana provisioning directory
ssh automation@100.112.203.63

# Copy dashboard JSON
sudo cp /path/to/container-health-monitoring.json /home/automation/docker/loki-stack/grafana/dashboards/

# Restart Grafana to load new dashboard
docker restart grafana

# Dashboard will appear automatically in Grafana
```

---

## First Time Setup

### 1. Verify Data Source

- Settings (gear icon) → Data sources
- Ensure "Loki" exists and is working
- Test connection → "Data source is working"

### 2. Set Time Range

- Top-right time picker
- Select: **Last 6 hours** (default) or **Last 24 hours**
- Click "Apply"

### 3. Check All Panels Load

You should see:
- ✅ "Active Containers" showing a number (28-30)
- ✅ "Update Failures (24h)" showing 0 or a count
- ✅ "DNS Errors (1h)" showing 0 or a count
- ✅ Logs appearing in the panels

If panels show "No data":
- Check time range (may need to go back 7 days to see October issues)
- Verify Loki data source is selected
- Check that Unraid is still shipping logs

---

## How to Use the Dashboard

### Daily Health Check (30 seconds)

**Quick glance at the 4 top panels**:

1. **Active Containers** = Green (28+)?
   - ✅ Good: All containers running
   - 🟡 Yellow (25-27): Some containers stopped
   - 🔴 Red (<25): Multiple containers missing - investigate!

2. **Update Failures (24h)** = 0?
   - ✅ Good: No update problems
   - 🟡 Yellow (1-4): Some updates failed - check logs
   - 🔴 Red (5+): Widespread update issues - DNS problem likely

3. **DNS Errors (1h)** = 0?
   - ✅ Good: DNS working properly
   - 🟡 Yellow (1-9): Occasional DNS hiccups
   - 🔴 Red (10+): DNS is failing - fix immediately

4. **Container Errors (1h)** = Low?
   - ✅ Good: <10 errors (normal application logs)
   - 🟡 Yellow (10-50): Some container issues
   - 🔴 Red (50+): Multiple containers having problems

### Weekly Review (5 minutes)

1. **Set time range to Last 7 days**

2. **Review "Watchtower Activity Log"**:
   - Look for "Session done" entries
   - Check for "Unable to update" messages
   - Note any patterns (time of day, specific containers)

3. **Check "DNS Error Rate" graph**:
   - Should be flat at 0
   - Any spikes? Note the time and investigate

4. **Review "Container Error Rate" graph**:
   - Which containers are noisiest?
   - Are errors increasing over time?

5. **Scroll through "Container Lifecycle Events"**:
   - How often are containers restarting?
   - Any unexpected stops/starts?

### Incident Investigation

**When "Active Containers" drops or "Update Failures" spike:**

1. **Note the time** when issue started

2. **Check "Container Failures & Errors" log panel**:
   - Look for "cannot kill container"
   - Look for "server misbehaving"
   - Note which containers are affected

3. **Check "DNS Error Rate" at that time**:
   - Spike in DNS errors = DNS issue
   - No DNS errors = different problem

4. **Check "Watchtower Activity Log"**:
   - Find the "Session done" message near that time
   - Look at "Failed" count
   - Read error messages above it

5. **Cross-reference with "Container Lifecycle Events"**:
   - Which containers stopped?
   - Were they all at the same time?
   - Did any successfully restart?

---

## Example: Viewing the October 28 Incident

**To see what happened when Sonarr/Jellyfin were removed:**

1. Open dashboard

2. Set time range:
   - From: **October 28, 2025 01:00**
   - To: **October 28, 2025 03:00**
   - Click "Apply time range"

3. Look at panels:

   **Active Containers panel**:
   - Should show drop from 29 → 24 around 1:46 AM

   **Update Failures panel**:
   - Should show 5 failures

   **DNS Errors panel**:
   - Should show 20+ DNS errors

4. **Scroll to "Watchtower Activity Log"**:
   - You'll see the sequence:
   ```
   01:46:44 - Found new image for binhex-jellyfin
   01:46:44 - Warning: lookup failed on 100.100.100.100:53
   01:46:44 - Unable to update container "/binhex-jellyfin"
   01:46:57 - Unable to update container "/HandBrake"
   ... (more failures)
   01:47:20 - Unable to update container "/binhex-sonarr"
   01:47:30 - Error: cannot kill container (not running)
   01:47:30 - Session done: Failed=2 Updated=0
   ```

5. **Check "DNS Error Rate" graph**:
   - Big red spike at 01:46-01:47

6. **"Container Failures & Errors" panel**:
   - Shows "server misbehaving" messages
   - Shows "No such container" errors

**This is the smoking gun** showing DNS caused the cascade failure.

---

## Set Up Alerts (Optional but Recommended)

### Alert 1: Container Count Drop

1. Dashboard → Settings (gear icon) → Variables
2. Click "New alert rule"
3. Name: "Container Count Drop"
4. Query:
   ```
   count(count_over_time({hostname="unraid-server", job="docker"}[5m]) > 0)
   ```
5. Condition: `IS BELOW 25`
6. Evaluate: Every 1m for 5m
7. Folder: Alerts / Infrastructure
8. Summary: "Less than 25 containers active on Unraid"
9. Save

### Alert 2: Update Failures

1. New alert rule
2. Name: "Watchtower Update Failures"
3. Query:
   ```
   sum(count_over_time({hostname="unraid-server", container="watchtower"} |~ "(?i)unable to update" [10m]))
   ```
4. Condition: `IS ABOVE 3`
5. Evaluate: Every 5m for 5m
6. Summary: "Multiple container updates failing on Unraid"
7. Save

### Alert 3: DNS Issues

1. New alert rule
2. Name: "DNS Resolution Failures"
3. Query:
   ```
   sum(count_over_time({hostname="unraid-server"} |~ "server misbehaving" [5m]))
   ```
4. Condition: `IS ABOVE 5`
5. Evaluate: Every 1m for 5m
6. Summary: "DNS resolution failures detected on Unraid"
7. Save

**Configure notification channel**:
- Alerting → Contact points
- Add email/Discord/Pushover/etc.
- Test notification

---

## Useful Queries for Explore

### See All Failed Updates (Last 7 Days)
```
{hostname="unraid-server", container="watchtower"} |~ "(?i)unable to update"
```

### See DNS Errors Only
```
{hostname="unraid-server"} |~ "server misbehaving"
```

### See Specific Container's Errors
```
{hostname="unraid-server", container="binhex-sonarr"} |~ "(?i)error|fail"
```

### Count Containers Reporting Logs
```
count(count_over_time({hostname="unraid-server", job="docker"}[5m]) > 0)
```

### See All Container Stops
```
{hostname="unraid-server"} |~ "(?i)stopping.*container"
```

---

## Troubleshooting

### "No data" in all panels

**Check**:
1. Loki data source is selected in dashboard settings
2. Time range includes recent data
3. Unraid is still shipping logs:
   ```bash
   ssh root@192.168.0.51 "docker ps | grep promtail"
   ```
4. Loki is receiving logs:
   ```bash
   ssh automation@100.112.203.63 "curl -s http://localhost:3100/loki/api/v1/label/hostname/values | jq"
   ```

### "Active Containers" shows 0

**Check**:
- Query syntax is correct
- Time range is appropriate (last 5 minutes needs data)
- Containers are actually running on Unraid

### Panels loading slowly

**Optimize**:
- Reduce time range (6h instead of 24h)
- Increase refresh interval (1m instead of 30s)
- Limit log panels to 100 lines instead of 500

### Can't import dashboard

**Try**:
- Copy/paste JSON content instead of file upload
- Check JSON syntax (no trailing commas, valid format)
- Verify Grafana version supports panel types used
- Create dashboard manually using queries from guide

---

## Quick Reference

**Dashboard URL**: http://192.168.0.19:3000/d/container-health

**Key Metrics**:
- Active Containers: Should be 28+
- Update Failures: Should be 0
- DNS Errors: Should be 0
- Container Errors: Should be <10/hour

**Alert Thresholds**:
- Containers < 25 = 🚨 Critical
- Update Failures > 3 = ⚠️ Warning
- DNS Errors > 5 in 5min = ⚠️ Warning

**Related Docs**:
- Issue diagnosis: `docs/UNRAID-CONTAINER-UPDATE-ISSUE.md`
- Monitoring guide: `docs/GRAFANA-CONTAINER-MONITORING.md`

---

## Next Steps

1. ✅ Import dashboard (you are here)
2. ⏭️ Set time range to October 28 to see the incident
3. ⏭️ Set up alert rules
4. ⏭️ Fix DNS on Unraid (see UNRAID-CONTAINER-UPDATE-ISSUE.md)
5. ⏭️ Monitor for 24 hours to verify fix works
6. ⏭️ Add to daily health check routine

---

**Created**: 2025-11-06
**Dashboard File**: `configs/grafana/dashboards/container-health-monitoring.json`

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
