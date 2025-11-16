# Grafana Alloy - Quick Start Guide

**Your monitoring scripts have been updated to use Grafana Alloy v1.11.3**

---

## What Changed?

✅ **Grafana Agent (deprecated) → Grafana Alloy (active)**

| What | Before | Now |
|------|--------|-----|
| Binary | grafana-agent | **alloy** |
| Config | config.yml (YAML) | **config.alloy** (River) |
| Version | v0.40.0 (EOL Nov 2025) | **v1.11.3** (latest) |
| UI | None | **http://localhost:12345** |

---

## Quick Deployment

### macOS (Device .21)

```bash
# 1. Navigate to repo
cd homelab-security-hardening

# 2. Run updated script
./scripts/setup-monitoring-macos-direct.sh

# 3. Verify
curl http://localhost:12345/metrics | grep node_
open http://localhost:12345  # View Alloy UI
```

**What it does**:
- ✅ Downloads Alloy v1.11.3 from GitHub
- ✅ Installs to `/usr/local/bin/alloy`
- ✅ Creates River config for macOS metrics + logs
- ✅ Sets up launchd service (auto-start)
- ✅ Ships logs to Loki, metrics to Prometheus

### Windows (Device .245)

```powershell
# 1. Open PowerShell as Administrator
# Right-click PowerShell → "Run as Administrator"

# 2. Navigate to repo
cd C:\path\to\homelab-security-hardening\scripts

# 3. Run new Alloy script
.\setup-monitoring-windows-alloy.ps1

# 4. Verify
Get-Service Alloy
Invoke-WebRequest http://localhost:12345/metrics
Start-Process http://localhost:12345  # View Alloy UI
```

**What it does**:
- ✅ Downloads Alloy installer
- ✅ Installs to `C:\Program Files\GrafanaLabs\Alloy`
- ✅ Creates River config for Windows Event Logs + metrics
- ✅ Sets up Windows Service (auto-start)
- ✅ Ships logs to Loki, metrics to Prometheus

### Linux (All other devices)

**No changes needed!** Your existing setup uses Promtail + node_exporter, which are still supported and work perfectly.

---

## Verify It's Working

### Check Service

**macOS**:
```bash
launchctl list | grep alloy
pgrep -lf "alloy run"
```

**Windows**:
```powershell
Get-Service Alloy
```

### Check Metrics

**Both platforms**:
```bash
# macOS
curl http://localhost:12345/metrics | head -20

# Windows
Invoke-WebRequest http://localhost:12345/metrics
```

Should see Prometheus metrics like:
```
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 123456.78
```

### Check Alloy UI

**Both platforms**:

Open browser to: **http://localhost:12345**

You'll see:
- 🟢 Component status (green = healthy)
- 📊 Data flow between components
- 📈 Metrics for each component
- 🔍 Configuration viewer

### Check Logs in Grafana

1. Open Grafana: **http://192.168.0.19:3000**
2. Go to: **Explore** → **Loki**
3. Query: `{hostname="YOUR-HOSTNAME"}`
4. Should see logs appearing

---

## Troubleshooting

### macOS: Service Won't Start

```bash
# Check error logs
tail -f /var/log/alloy-error.log

# Manually test config
/usr/local/bin/alloy run /usr/local/etc/alloy/config.alloy

# Check config syntax
cat /usr/local/etc/alloy/config.alloy
```

### Windows: Service Won't Start

```powershell
# Check service status
Get-Service Alloy | Select-Object *

# Check event logs
Get-EventLog -LogName Application -Source Alloy -Newest 20

# Manually test
& "C:\Program Files\GrafanaLabs\Alloy\alloy.exe" run "C:\Program Files\GrafanaLabs\Alloy\config\config.alloy"
```

### Metrics Not Appearing in Prometheus

**From Raspberry Pi**:
```bash
ssh automation@100.112.203.63

# Check if Prometheus can scrape the device
curl http://DEVICE-IP:12345/metrics

# Check Prometheus targets
curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.hostname=="YOUR-HOSTNAME")'
```

### Logs Not Appearing in Loki

**From Raspberry Pi**:
```bash
ssh automation@100.112.203.63

# Check which hostnames are reporting
curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq
```

---

## Alloy UI Features

### View Components

Navigate to **http://localhost:12345** to see:

**Metrics Collection**:
- `prometheus.exporter.unix` - System metrics exporter (macOS/Linux)
- `prometheus.exporter.windows` - System metrics exporter (Windows)
- `prometheus.scrape` - Scrapes the exporter
- `prometheus.remote_write` - Ships to Prometheus

**Log Collection**:
- `local.file_match` - Matches log files (macOS/Linux)
- `loki.source.file` - Reads log files (macOS/Linux)
- `loki.source.windowsevent` - Reads Event Logs (Windows)
- `loki.write` - Ships to Loki

### Component Status

Each component shows:
- 🟢 Green = Healthy
- 🟡 Yellow = Warning
- 🔴 Red = Error

Click on any component to see:
- Current state
- Metrics (samples processed, errors, etc.)
- Configuration

---

## Configuration Files

### macOS

**Location**: `/usr/local/etc/alloy/config.alloy`

**Format**: River (HCL-like syntax)

**Example**:
```alloy
prometheus.exporter.unix "macos_system" {
  set_collectors = ["darwin"]
  enable_collectors = ["cpu", "diskstats", "filesystem", "loadavg", "meminfo", "netdev", "time"]
}

prometheus.scrape "macos_metrics" {
  targets     = prometheus.exporter.unix.macos_system.targets
  forward_to  = [prometheus.remote_write.default.receiver]
}
```

### Windows

**Location**: `C:\Program Files\GrafanaLabs\Alloy\config\config.alloy`

**Format**: River (HCL-like syntax)

**Example**:
```alloy
prometheus.exporter.windows "windows_system" {
  enabled_collectors = ["cpu", "cs", "logical_disk", "memory", "net", "os", "system", "tcp"]
}

loki.source.windowsevent "security" {
  eventlog_name = "Security"
  forward_to    = [loki.write.default.receiver]
  labels = {
    job      = "windows-security",
    hostname = "WIN-PC",
  }
}
```

---

## Service Management

### macOS

```bash
# Stop
sudo launchctl unload /Library/LaunchDaemons/com.grafana.alloy.plist

# Start
sudo launchctl load /Library/LaunchDaemons/com.grafana.alloy.plist

# Restart
sudo launchctl kickstart -k system/com.grafana.alloy

# View logs
tail -f /var/log/alloy.log
```

### Windows

```powershell
# Stop
Stop-Service Alloy

# Start
Start-Service Alloy

# Restart
Restart-Service Alloy

# Status
Get-Service Alloy

# Logs
Get-EventLog -LogName Application -Source Alloy -Newest 20
```

---

## Why Alloy is Better

### 1. Not Deprecated
- ✅ Active development (Agent is EOL Nov 2025)
- ✅ Regular updates and bug fixes
- ✅ Long-term support from Grafana Labs

### 2. Built-in UI
- ✅ Visual component graph
- ✅ Real-time status monitoring
- ✅ Debug issues faster
- ✅ No need for command-line troubleshooting

### 3. Better Configuration
- ✅ River language is type-safe
- ✅ Better error messages
- ✅ Component reusability
- ✅ Clearer data flow

### 4. Same Functionality
- ✅ Collects same metrics (node_exporter, windows_exporter)
- ✅ Ships to same destinations (Loki, Prometheus)
- ✅ Same labels and job names
- ✅ Your Grafana dashboards still work

---

## Need Help?

### Documentation

- **Full migration details**: `docs/ALLOY-MIGRATION-COMPLETE.md`
- **Alloy vs Wazuh comparison**: `docs/MIGRATION-STRATEGY-ALLOY-VS-WAZUH.md`
- **Universal setup guide**: `docs/UNIVERSAL-SETUP-GUIDE.md`

### Official Alloy Docs

- **Configuration reference**: https://grafana.com/docs/alloy/latest/reference/
- **River syntax**: https://grafana.com/docs/alloy/latest/get-started/configuration-syntax/
- **Components**: https://grafana.com/docs/alloy/latest/reference/components/

### Scripts

- **macOS**: `scripts/setup-monitoring-macos-direct.sh`
- **Windows**: `scripts/setup-monitoring-windows-alloy.ps1`
- **Universal**: `scripts/setup-monitoring-universal.sh`

---

## Summary

**Ready to deploy**:
- ✅ macOS script updated for Alloy v1.11.3
- ✅ Windows script created for Alloy v1.11.3
- ✅ Linux devices unchanged (Promtail works as-is)

**Next steps**:
1. Deploy to macOS device (.21): `./scripts/setup-monitoring-macos-direct.sh`
2. Deploy to Windows device (.245): `.\scripts\setup-monitoring-windows-alloy.ps1`
3. Verify in Grafana: http://192.168.0.19:3000

**Alloy advantages**:
- 🚀 Active development (not deprecated)
- 🎯 Built-in UI for debugging
- 📊 Same monitoring capabilities
- 🔒 Better configuration safety

---

**Questions?** Check the migration docs or Alloy's official documentation!

🤖 Generated with [Claude Code](https://claude.com/claude-code)
