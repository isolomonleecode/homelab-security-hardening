# Adding Hostname Filter to Security Dashboard

## Quick Method: Add Variable in Grafana UI

### Step 1: Open Dashboard Settings

1. Go to http://192.168.0.19:3000
2. Open the "Homelab Security Monitoring (Fixed)" dashboard
3. Click the ⚙️ (gear icon) in the top right → "Settings"

### Step 2: Add Hostname Variable

1. Click "Variables" in the left sidebar
2. Click "Add variable" button
3. Fill in the following:

**General:**
- **Name:** `hostname`
- **Type:** `Query`
- **Label:** `Host`

**Query Options:**
- **Data source:** `Loki`
- **Query type:** `Label values`
- **Label:** `hostname`
- **Regex:** (leave empty)

**Selection Options:**
- ✅ **Multi-value:** Enabled (allows selecting multiple hosts)
- ✅ **Include All option:** Enabled (adds "All" option)
- **Custom all value:** `.*` (regex to match all)

4. Click "Run query" to test (should show all 7 hostnames)
5. Click "Apply" button at bottom
6. Click "Save dashboard" button (top right)

### Step 3: Update Panel Queries

Now edit each panel to use the variable:

1. Click on a panel title → Edit
2. In the query, change:
   ```
   {job="systemd-journal", syslog_identifier="sshd"}
   ```
   To:
   ```
   {job="systemd-journal", syslog_identifier="sshd", hostname=~"$hostname"}
   ```

3. Apply to these panels:
   - SSH Failed Logins (5m)
   - Container Errors (5m)
   - Access Denied Events (5m)
   - Total Container Logs (1h)
   - Security Event Logs
   - Container Error Rate Over Time
   - SSH Failed Attempts Over Time
   - Top 10 Most Active Containers (24h)
   - Top 10 Containers by Error Count (24h)
   - SSH Activity Logs

4. Save dashboard

---

## Result

You'll see a dropdown at the top of the dashboard:

```
┌─────────────────────────────────────┐
│ Host: [All ▼]                       │
└─────────────────────────────────────┘
```

Click it to filter by specific hosts:
- ☐ All
- ☐ BPC
- ☐ capcorp9000
- ☐ cfb-hpallinone
- ☐ jpcachyos
- ☐ n-cachyos
- ☐ sweetrpi-desktop
- ☐ unraid-server

---

## Example Updated Queries

### Before (no filter):
```
sum(count_over_time({job="systemd-journal", syslog_identifier="sshd"} |~ "(?i)connection closed.*preauth" [5m]))
```

### After (with hostname filter):
```
sum(count_over_time({job="systemd-journal", syslog_identifier="sshd", hostname=~"$hostname"} |~ "(?i)connection closed.*preauth" [5m]))
```

---

### Before (container errors):
```
sum by (container) (count_over_time({job="docker"} |~ "(?i)(error|fail)" [24h]))
```

### After (with hostname filter):
```
sum by (container, hostname) (count_over_time({job="docker", hostname=~"$hostname"} |~ "(?i)(error|fail)" [24h]))
```

Note: Also added `hostname` to `sum by` clause to preserve hostname in results.

---

## Advanced: Add Panels for Multi-Host Comparison

Once you have the hostname variable, you can add new panels:

### Failed SSH Logins by Host (last 24h)

**Panel Type:** Bar chart or Table

**Query:**
```
sum by (hostname) (count_over_time({job="systemd-journal", syslog_identifier="sshd", hostname=~"$hostname"} |~ "(?i)failed|connection closed.*preauth" [24h]))
```

**Visualization:** Shows which hosts are being attacked most frequently

---

### Container Errors by Host and Container

**Panel Type:** Table

**Query:**
```
topk(20, sum by (hostname, container) (count_over_time({job="docker", hostname=~"$hostname"} |~ "(?i)error" [24h])))
```

**Columns:**
- Hostname
- Container
- Error Count

---

## Interview Talking Point

*"I added dynamic filtering to the security dashboard using Grafana variables. This allows drilling down from fleet-wide security events to specific hosts or analyzing patterns across multiple devices. The variable queries Loki labels dynamically, so new hosts automatically appear in the dropdown when they start shipping logs. This demonstrates understanding of SIEM investigation workflows - start broad, then filter down to specifics during incident response."*

---

## Troubleshooting

**Variable shows "No options":**
- Check Loki data source is configured correctly
- Verify logs are reaching Loki: `curl -s 'http://192.168.0.19:3100/loki/api/v1/label/hostname/values'`
- Make sure query is `Label values` with label `hostname`

**Panels show no data after adding filter:**
- Make sure you used `hostname=~"$hostname"` (regex match with `=~`)
- Don't use `hostname="$hostname"` (exact match)
- The `.*` custom all value requires regex matching

**Can't select multiple hosts:**
- Enable "Multi-value" in variable settings
- Make sure queries use `=~` (regex) not `=` (exact match)

---

## Quick Test

After adding the variable:

1. Select "All" → should see data from all 7 hosts
2. Select only "capcorp9000" → should see only data from that host
3. Select "capcorp9000, unraid-server" → should see combined data from both

If filtering works correctly, you've successfully added the hostname filter! 🎉
