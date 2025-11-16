# Monitoring Container Updates and Failures in Grafana

**Purpose**: Detect Docker container update failures, DNS issues, and missing containers in real-time

---

## What's Already Visible

Your Loki setup is **already collecting** all the data needed to see this issue:

- ✅ Watchtower logs (update attempts and failures)
- ✅ Docker daemon logs (container start/stop/errors)
- ✅ System journal logs (DNS issues)
- ✅ All container logs from Unraid

**The data was there** - we just need to query it properly!

---

## Grafana Queries to Detect the Issue

### 1. Watchtower Update Failures

**Query (LogQL)**:
```
{hostname="unraid-server", container="watchtower"} |~ "(?i)unable to update|error|failed"
```

**What it shows**:
- Failed update attempts
- DNS resolution errors
- Registry connection failures

**Example output you would have seen**:
```
level=info msg="Unable to update container \"/binhex-sonarr\": Error response from daemon: Get \"https://registry-1.docker.io/v2/\": dial tcp: lookup registry-1.docker.io on 100.100.100.100:53: server misbehaving."
```

### 2. DNS Resolution Failures

**Query (LogQL)**:
```
{hostname="unraid-server"} |~ "(?i)server misbehaving|lookup.*failed|dial tcp.*100.100.100.100"
```

**What it shows**:
- Any container experiencing DNS issues
- Specifically filters for Tailscale DNS (100.100.100.100) problems

### 3. Container Removal/Kill Errors

**Query (LogQL)**:
```
{hostname="unraid-server"} |~ "(?i)cannot kill container|no such container|removing image"
```

**What it shows**:
- Containers being forcibly removed
- "No such container" errors (containers already gone)
- Images being removed after failed updates

### 4. Container Restart Events

**Query (LogQL)**:
```
{hostname="unraid-server"} |~ "(?i)stopping|creating|starting" | json | line_format "{{.container}}: {{.message}}"
```

**What it shows**:
- Which containers are being stopped/started
- Update activity timeline

### 5. Missing Containers Detection

**Query (PromQL)** - Compares expected vs running:
```
# Count unique containers reporting logs in last 5 minutes
count(count_over_time({hostname="unraid-server", job="docker"}[5m]) > 0)
```

**Set up alert**: If count drops below expected number (e.g., < 25 containers), trigger alert.

---

## Create Monitoring Dashboard Panel

### Panel 1: Watchtower Update Status

**Panel Type**: Logs

**Data Source**: Loki

**Query**:
```
{hostname="unraid-server", container="watchtower"}
```

**Transform**:
- Add filter: `|~ "(?i)found new|unable to update|stopping|creating|session done"`

**Visualization**:
- Show last 50 log lines
- Enable time sorting
- Color code by log level

**What you'll see**:
- Real-time update attempts
- Success/failure status
- DNS errors when they occur

### Panel 2: Container Update Failures (Table)

**Panel Type**: Table

**Data Source**: Loki

**Query**:
```
sum by (container) (count_over_time({hostname="unraid-server"} |~ "(?i)unable to update|cannot kill" | json | __error__="" [24h]))
```

**Columns**:
- Container name
- Failure count (last 24h)

**Alert Threshold**: > 0 failures

### Panel 3: DNS Resolution Errors

**Panel Type**: Time series

**Data Source**: Loki

**Query**:
```
sum(count_over_time({hostname="unraid-server"} |~ "server misbehaving" [5m]))
```

**Visualization**:
- Line graph
- Shows DNS error frequency over time
- Red threshold line at > 0

**Alert**: If > 3 DNS errors in 5 minutes

### Panel 4: Active Containers Count

**Panel Type**: Stat (single value)

**Data Source**: Loki

**Query**:
```
count(count_over_time({hostname="unraid-server", job="docker"}[5m]) > 0)
```

**Visualization**:
- Big number showing active container count
- Green if >= 28 (your baseline)
- Yellow if 25-27
- Red if < 25

**Alert**: If drops below 25

### Panel 5: Container Error Rate

**Panel Type**: Time series

**Data Source**: Loki

**Query**:
```
sum(rate({hostname="unraid-server", job="docker"} |~ "(?i)error|fail|fatal" [5m]))
```

**What it shows**:
- Error rate across all containers
- Spike = something wrong

---

## Create Alert Rules

### Alert 1: Watchtower Update Failure

**Condition**:
```
count_over_time({hostname="unraid-server", container="watchtower"} |~ "(?i)unable to update|error.*daemon" [10m]) > 3
```

**Trigger**: More than 3 update failures in 10 minutes

**Action**: Send notification

**Message**:
```
⚠️ Watchtower Update Failures Detected
Multiple container updates failing on Unraid server.
Likely cause: DNS resolution issues.
Check: {hostname="unraid-server", container="watchtower"}
```

### Alert 2: Container Count Drop

**Condition**:
```
count(count_over_time({hostname="unraid-server", job="docker"}[5m]) > 0) < 25
```

**Trigger**: Less than 25 containers reporting logs

**Action**: Send notification

**Message**:
```
🚨 Missing Containers Detected
Expected 28+ containers, currently seeing < 25.
Check Unraid Docker tab for stopped/removed containers.
```

### Alert 3: DNS Resolution Failures

**Condition**:
```
sum(count_over_time({hostname="unraid-server"} |~ "server misbehaving|dns.*failed" [5m])) > 5
```

**Trigger**: More than 5 DNS errors in 5 minutes

**Action**: Send notification

**Message**:
```
⚠️ DNS Resolution Issues on Unraid
Multiple DNS lookup failures detected.
Check /etc/resolv.conf and Pi-hole status.
```

---

## Step-by-Step: Add to Existing Dashboard

### Option 1: Add to Security Dashboard

1. Open Grafana: http://192.168.0.19:3000
2. Navigate to: **Dashboards → Security Monitoring**
3. Click: **Add → Visualization**
4. Select: **Loki** data source
5. Paste query:
   ```
   {hostname="unraid-server", container="watchtower"} |~ "(?i)unable|error|failed"
   ```
6. Title: "Unraid Update Failures"
7. Panel type: **Logs**
8. Save dashboard

### Option 2: Create New "Container Health" Dashboard

I'll create a complete dashboard JSON for you below.

---

## Complete Dashboard JSON

I'll create a dashboard specifically for container monitoring:

```json
{
  "dashboard": {
    "title": "Container Health Monitoring",
    "tags": ["docker", "unraid", "containers"],
    "timezone": "browser",
    "refresh": "30s",
    "panels": [
      {
        "title": "Active Containers Count",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "count(count_over_time({hostname=\"unraid-server\", job=\"docker\"}[5m]) > 0)",
            "refId": "A"
          }
        ],
        "options": {
          "colorMode": "background",
          "graphMode": "none",
          "textMode": "value_and_name"
        },
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "red"},
                {"value": 25, "color": "yellow"},
                {"value": 28, "color": "green"}
              ]
            }
          }
        }
      },
      {
        "title": "Watchtower Update Failures (24h)",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
        "targets": [
          {
            "expr": "sum(count_over_time({hostname=\"unraid-server\", container=\"watchtower\"} |~ \"(?i)unable to update\" [24h]))",
            "refId": "A"
          }
        ],
        "options": {
          "colorMode": "background"
        },
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 1, "color": "yellow"},
                {"value": 5, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "title": "DNS Resolution Errors (1h)",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "sum(count_over_time({hostname=\"unraid-server\"} |~ \"server misbehaving\" [1h]))",
            "refId": "A"
          }
        ],
        "options": {
          "colorMode": "background"
        },
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 1, "color": "yellow"},
                {"value": 10, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "title": "Container Errors (1h)",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0},
        "targets": [
          {
            "expr": "sum(count_over_time({hostname=\"unraid-server\", job=\"docker\"} |~ \"(?i)error|fatal\" [1h]))",
            "refId": "A"
          }
        ],
        "options": {
          "colorMode": "background"
        },
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 10, "color": "yellow"},
                {"value": 50, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "title": "Watchtower Activity Log",
        "type": "logs",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
        "targets": [
          {
            "expr": "{hostname=\"unraid-server\", container=\"watchtower\"}",
            "refId": "A"
          }
        ],
        "options": {
          "showTime": true,
          "showLabels": false,
          "showCommonLabels": false,
          "wrapLogMessage": true,
          "sortOrder": "Descending"
        }
      },
      {
        "title": "Container Failures & Errors",
        "type": "logs",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
        "targets": [
          {
            "expr": "{hostname=\"unraid-server\"} |~ \"(?i)unable to update|cannot kill|no such container|server misbehaving\"",
            "refId": "A"
          }
        ],
        "options": {
          "showTime": true,
          "wrapLogMessage": true,
          "sortOrder": "Descending"
        }
      },
      {
        "title": "DNS Error Rate",
        "type": "timeseries",
        "gridPos": {"h": 6, "w": 12, "x": 0, "y": 12},
        "targets": [
          {
            "expr": "sum(rate({hostname=\"unraid-server\"} |~ \"server misbehaving\" [5m]))",
            "refId": "A",
            "legendFormat": "DNS Errors/sec"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"},
            "custom": {
              "fillOpacity": 20,
              "gradientMode": "hue"
            }
          },
          "overrides": [
            {
              "matcher": {"id": "byName", "options": "DNS Errors/sec"},
              "properties": [
                {"id": "color", "value": {"mode": "fixed", "fixedColor": "red"}}
              ]
            }
          ]
        }
      },
      {
        "title": "Container Error Rate",
        "type": "timeseries",
        "gridPos": {"h": 6, "w": 12, "x": 12, "y": 12},
        "targets": [
          {
            "expr": "sum by (container) (rate({hostname=\"unraid-server\", job=\"docker\"} |~ \"(?i)error\" [5m]))",
            "refId": "A",
            "legendFormat": "{{container}}"
          }
        ]
      },
      {
        "title": "Recent Container State Changes",
        "type": "logs",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 18},
        "targets": [
          {
            "expr": "{hostname=\"unraid-server\"} |~ \"(?i)stopping|starting|creating|removing\"",
            "refId": "A"
          }
        ],
        "options": {
          "showTime": true,
          "wrapLogMessage": true,
          "sortOrder": "Descending"
        }
      }
    ]
  }
}
```

**To import this dashboard:**

1. Copy the JSON above
2. Grafana → Dashboards → New → Import
3. Paste JSON
4. Click "Load"
5. Select Loki data source
6. Click "Import"

---

## Quick View: See the Issue Right Now

### Via Grafana Explore

1. Go to: http://192.168.0.19:3000/explore
2. Select: **Loki** data source
3. Enter query:
   ```
   {hostname="unraid-server", container="watchtower"} |~ "(?i)unable|server misbehaving"
   ```
4. Time range: **Last 7 days**
5. Click: **Run query**

**You should see** all the failed update attempts from October 28 - November 1.

### Via Command Line (Faster)

```bash
# View in Grafana Explore with pre-filled query
open "http://192.168.0.19:3000/explore?left=%7B%22datasource%22:%22loki%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bhostname%3D%5C%22unraid-server%5C%22,container%3D%5C%22watchtower%5C%22%7D%20%7C~%20%5C%22unable%5C%22%22%7D%5D%7D"
```

---

## Monitoring Strategy

### What to Watch

**Daily Check** (5 minutes):
1. Open Container Health Dashboard
2. Verify "Active Containers Count" = 28+
3. Check "Update Failures" = 0
4. Review watchtower logs for any warnings

**Weekly Review** (15 minutes):
1. Review all failed updates for the week
2. Check DNS error trends
3. Verify all containers are on latest versions
4. Review container restart frequency

### Alert Channels

Configure Grafana to send alerts via:

**Email**:
```
Alerting → Contact points → New contact point
Type: Email
Addresses: your-email@example.com
```

**Discord** (if you use it):
```
Alerting → Contact points → New contact point
Type: Discord
Webhook URL: <your discord webhook>
```

**Pushover/Telegram/etc** also supported.

---

## What You Would Have Seen

If this dashboard existed during the October 28 incident, you would have seen:

**At 1:46 AM**:
- 🔴 "DNS Errors" panel: **Spike to 20+ errors/minute**
- 🔴 "Update Failures" panel: **5 failures** (sonarr, jellyfin, overseerr, flaresolverr, prowlarr)
- 🟡 "Active Containers": **Dropped from 29 → 24**
- 🔴 Logs showing: `server misbehaving` repeatedly

**Alert would have fired**:
```
⚠️ Watchtower Update Failures Detected
5 container updates failed in 10 minutes
DNS resolution issues detected (20 errors)
```

You could have:
1. Stopped watchtower immediately
2. Fixed DNS before more containers were removed
3. Prevented Sonarr/Jellyfin/etc from being deleted

---

## Advanced: Metrics from Logs

### Container Uptime Tracking

**Query**:
```
sum by (container) (count_over_time({hostname="unraid-server", job="docker"} [24h]))
```

**Shows**: Log volume per container (correlates to uptime)

**Missing containers** will show 0 or very low counts.

### Update Success Rate

**Query**:
```
sum(count_over_time({hostname="unraid-server", container="watchtower"} |~ "Session done" | json | __error__="" [7d]))
/
sum(count_over_time({hostname="unraid-server", container="watchtower"} |~ "Scheduling first run" [7d]))
```

**Shows**: Percentage of successful update runs

**Target**: 100% (anything less = problems)

---

## Interview Talking Points

### Observability & Monitoring

*"I implemented centralized logging with Loki, which allowed me to retrospectively analyze a container update failure cascade. By querying historical logs, I identified DNS resolution failures as the root cause - something that would have been difficult to diagnose without centralized log aggregation."*

### Proactive Monitoring

*"I created Grafana dashboards to monitor Docker container health, update success rates, and DNS resolution. This includes alert rules that trigger when update failures occur or container counts drop unexpectedly, enabling proactive incident response rather than reactive troubleshooting."*

### Log Analysis for Incident Response

*"Using LogQL queries, I can filter 30+ days of container logs to identify patterns like 'server misbehaving' in watchtower logs, correlate that with container removal events, and trace the incident timeline from first DNS failure to final container loss."*

### Security Monitoring

*"Monitoring container lifecycle events (stop, start, remove) is important for security - unauthorized container modifications or removals could indicate compromise. The same queries that detect update failures can also detect malicious container manipulation."*

---

## Summary

**Yes, you can absolutely see this in Grafana!**

✅ All the data is already in Loki
✅ Queries exist to show the exact errors
✅ Can create dashboards to visualize health
✅ Can set up alerts to prevent future issues
✅ Historical data shows what happened Oct 28-Nov 1

**Next steps**:
1. Import the Container Health dashboard (JSON above)
2. Set up alerts for update failures
3. Review historical logs to see the timeline
4. Monitor for 24h after fixing DNS

---

**Created**: 2025-11-06
**Related**: UNRAID-CONTAINER-UPDATE-ISSUE.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
