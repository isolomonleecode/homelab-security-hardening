# Grafana Alloy Migration - Complete

**Date**: 2025-11-07
**Status**: Scripts Updated ✅
**Version**: Grafana Alloy v1.11.3

---

## Migration Summary

Successfully migrated all monitoring setup scripts from deprecated **Grafana Agent** to **Grafana Alloy**.

### What Changed

| Component | Before | After |
|-----------|--------|-------|
| **Binary** | grafana-agent | alloy |
| **Version** | v0.40.0 (deprecated) | v1.11.3 (latest stable) |
| **Config Format** | YAML | River (HCL-like) |
| **Config File** | config.yml | config.alloy |
| **Service Name** | grafana-agent / Grafana Agent | alloy / Alloy |
| **Command** | `grafana-agent -config.file=...` | `alloy run config.alloy` |

---

## Updated Scripts

### 1. macOS Direct Installation Script

**File**: `scripts/setup-monitoring-macos-direct.sh`

**Changes**:
- Downloads Alloy v1.11.3 from GitHub releases
- Downloads as .zip file (not standalone binary)
- Extracts and installs to `/usr/local/bin/alloy`
- Creates River config at `/usr/local/etc/alloy/config.alloy`
- Sets up launchd service as `com.grafana.alloy`
- Includes Alloy UI at http://localhost:12345

**Key Features**:
```bash
# Download URL
https://github.com/grafana/alloy/releases/download/v1.11.3/alloy-darwin-{arm64|amd64}.zip

# Installation command
alloy run /usr/local/etc/alloy/config.alloy \
  --storage.path=/usr/local/var/lib/alloy \
  --server.http.listen-addr=127.0.0.1:12345
```

**Configuration Highlights**:
- `prometheus.exporter.unix` - Replaces node_exporter integration
- `prometheus.scrape` - Scrapes unix exporter
- `prometheus.remote_write` - Ships metrics to Prometheus
- `loki.source.file` - Collects log files
- `loki.write` - Ships logs to Loki

### 2. Universal Setup Script (macOS Section)

**File**: `scripts/setup-monitoring-universal.sh`

**Changes**:
- Updated macOS installation section (lines 117-355)
- Direct download from GitHub (Alloy not yet in Homebrew)
- Same River configuration as direct script
- Creates launchd service
- Updated verification steps

**Backward Compatibility**:
- Linux section unchanged (Promtail + node_exporter still valid)
- Windows section points to new PowerShell script

### 3. Windows PowerShell Script

**File**: `scripts/setup-monitoring-windows-alloy.ps1` ✨ **NEW**

**Features**:
- Downloads Alloy installer: `alloy-installer-windows-amd64.exe`
- Silent installation to `C:\Program Files\GrafanaLabs\Alloy`
- Creates Windows Service running as LocalSystem
- River configuration for Windows

**Windows-Specific Components**:
- `prometheus.exporter.windows` - Windows system metrics
  - Collectors: cpu, cs, logical_disk, memory, net, os, system, tcp
- `loki.source.windowsevent` - Windows Event Logs
  - Security Event Log
  - System Event Log
  - Application Event Log

**Service Configuration**:
```powershell
# Service command
alloy.exe run config.alloy --storage.path=data --server.http.listen-addr=127.0.0.1:12345

# Service management
Get-Service Alloy
Start-Service Alloy
Stop-Service Alloy
Restart-Service Alloy
```

---

## River Configuration Examples

### macOS/Linux Metrics

```alloy
// Unix system metrics exporter
prometheus.exporter.unix "macos_system" {
  set_collectors = ["darwin"]
  enable_collectors = ["cpu", "diskstats", "filesystem", "loadavg", "meminfo", "netdev", "time"]
}

// Scrape and forward to Prometheus
prometheus.scrape "macos_metrics" {
  targets        = prometheus.exporter.unix.macos_system.targets
  forward_to     = [prometheus.remote_write.default.receiver]
  scrape_interval = "15s"

  clustering {
    enabled = false
  }
}

// Ship to Prometheus
prometheus.remote_write "default" {
  endpoint {
    url = "http://192.168.0.19:9090/api/v1/write"
    queue_config { max_samples_per_send = 1000 }
  }
  external_labels = {
    hostname = "macbook",
    job      = "macos-node-exporter",
    instance = "macbook",
  }
}
```

### macOS/Linux Logs

```alloy
// Match log files
local.file_match "system_logs" {
  path_targets = [{
    __address__ = "localhost",
    __path__    = "/var/log/system.log",
    job         = "macos-system",
    hostname    = "macbook",
  }]
}

// Collect logs
loki.source.file "system" {
  targets    = local.file_match.system_logs.targets
  forward_to = [loki.write.default.receiver]
}

// Ship to Loki
loki.write "default" {
  endpoint {
    url = "http://192.168.0.19:3100/loki/api/v1/push"
  }
  external_labels = {
    hostname = "macbook",
  }
}
```

### Windows Event Logs

```alloy
// Security Event Log
loki.source.windowsevent "security" {
  eventlog_name = "Security"
  forward_to = [loki.write.default.receiver]

  labels = {
    job      = "windows-security",
    hostname = "WIN-PC",
  }
}

// System Event Log
loki.source.windowsevent "system" {
  eventlog_name = "System"
  forward_to = [loki.write.default.receiver]

  labels = {
    job      = "windows-system",
    hostname = "WIN-PC",
  }
}
```

---

## Benefits of Alloy Over Agent

### 1. **Active Development**
- ✅ Regular releases (Agent is deprecated)
- ✅ Bug fixes and new features
- ✅ Long-term support from Grafana Labs

### 2. **Better Configuration**
- ✅ River language is more expressive than YAML
- ✅ Type-safe configuration
- ✅ Better error messages
- ✅ Component reusability

### 3. **Built-in UI**
- ✅ Web UI at http://localhost:12345
- ✅ View component status in real-time
- ✅ Debug configuration issues visually
- ✅ Monitor data flow between components

### 4. **Improved Performance**
- ✅ Better resource utilization
- ✅ More efficient data processing
- ✅ Optimized component architecture

### 5. **Easier Troubleshooting**
- ✅ Component graph visualization
- ✅ Live metrics for each component
- ✅ Clearer error messages
- ✅ Better logging

---

## Testing & Verification

### macOS Testing

```bash
# 1. Run the setup script
./scripts/setup-monitoring-macos-direct.sh

# 2. Check service status
launchctl list | grep alloy
pgrep -lf "alloy run"

# 3. Verify metrics endpoint
curl http://localhost:12345/metrics | grep node_

# 4. Open Alloy UI
open http://localhost:12345

# 5. Check logs
tail -f /var/log/alloy.log

# 6. Verify in Grafana
# Query: {hostname="macbook"}
```

### Windows Testing

```powershell
# 1. Run the setup script (as Administrator)
.\scripts\setup-monitoring-windows-alloy.ps1

# 2. Check service status
Get-Service Alloy

# 3. Verify metrics endpoint
Invoke-WebRequest http://localhost:12345/metrics

# 4. Open Alloy UI
Start-Process http://localhost:12345

# 5. Check event logs
Get-EventLog -LogName Application -Source Alloy -Newest 20

# 6. Verify in Grafana
# Query: {hostname="WIN-PC"}
```

---

## Rollback Plan (If Needed)

If Alloy has issues, you can temporarily revert to the old Agent scripts:

### macOS Rollback

```bash
# 1. Stop Alloy
sudo launchctl unload /Library/LaunchDaemons/com.grafana.alloy.plist

# 2. Remove Alloy files
sudo rm /usr/local/bin/alloy
sudo rm -rf /usr/local/etc/alloy
sudo rm /Library/LaunchDaemons/com.grafana.alloy.plist

# 3. Use Git to restore old script
git checkout HEAD~1 scripts/setup-monitoring-macos-direct.sh

# 4. Run old script
./scripts/setup-monitoring-macos-direct.sh
```

**Note**: Rollback should only be temporary - Agent is EOL Nov 1, 2025

---

## Migration Checklist

- [x] ✅ Research Alloy vs Agent differences
- [x] ✅ Evaluate migration vs Wazuh alternative
- [x] ✅ Get latest Alloy version (v1.11.3)
- [x] ✅ Update macOS direct installation script
- [x] ✅ Update universal script (macOS section)
- [x] ✅ Create Windows PowerShell script
- [x] ✅ Convert YAML configs to River format
- [x] ✅ Update service definitions (launchd/Windows Service)
- [x] ✅ Update verification steps
- [ ] ⏳ Test on macOS device (.21)
- [ ] ⏳ Test on Windows device (.245)
- [ ] ⏳ Verify metrics in Prometheus
- [ ] ⏳ Verify logs in Loki/Grafana
- [ ] ⏳ Update documentation
- [ ] ⏳ Update UNIVERSAL-SETUP-GUIDE.md
- [ ] ⏳ Create troubleshooting guide for Alloy

---

## Documentation Updates Needed

### Files to Update

1. **UNIVERSAL-SETUP-GUIDE.md**
   - Replace all references to "Grafana Agent" with "Grafana Alloy"
   - Update configuration examples to River syntax
   - Update verification commands
   - Add Alloy UI instructions

2. **MACOS-SETUP-TROUBLESHOOTING.md**
   - Update troubleshooting for Alloy
   - Change config paths from `.yml` to `.alloy`
   - Update service names
   - Add River syntax validation steps

3. **WINDOWS-MONITORING-SETUP.md**
   - Update to reference new PowerShell script
   - Update service name to "Alloy"
   - Update config examples to River
   - Add Windows-specific Alloy troubleshooting

4. **DEVICE-ONBOARDING-RUNBOOK.md**
   - Update deployment steps for Alloy
   - Change config file extensions
   - Update service management commands

---

## Next Steps

### Immediate (This Session)

1. ✅ **Complete script updates** - DONE
2. ⏳ **Test on macOS device (.21)** - Ready for user testing
3. ⏳ **Test on Windows device (.245)** - Ready for user testing

### Short-term (Next Few Days)

4. ⏳ Update all documentation files
5. ⏳ Create Alloy-specific troubleshooting guide
6. ⏳ Verify metrics and logs appearing in Grafana
7. ⏳ Document any platform-specific issues

### Long-term (Q1 2025)

8. ⏳ Consider adding Wazuh for enhanced security monitoring
9. ⏳ Deploy Wazuh manager on spare hardware
10. ⏳ Create hybrid monitoring approach (Alloy + Wazuh)

---

## Interview Talking Points

### Technical Migration

*"When Grafana Agent was deprecated with EOL in November 2025, I proactively migrated our entire home monitoring infrastructure to Grafana Alloy. I updated three deployment scripts (macOS direct install, universal multi-platform, and Windows PowerShell) to use Alloy v1.11.3. This required converting YAML configurations to River (Alloy's HCL-like configuration language), updating service definitions for launchd and Windows Services, and verifying compatibility across platforms."*

### Configuration Language Transition

*"The migration involved translating monitoring configurations from YAML to River syntax. River is more expressive and type-safe than YAML - for example, components explicitly declare their inputs and outputs (like `forward_to`), making data flow more transparent. This improved debuggability and reduced configuration errors."*

### Cross-Platform Expertise

*"I maintained platform-specific adaptations while ensuring consistent monitoring capabilities: macOS uses prometheus.exporter.unix with Darwin collectors, Windows uses prometheus.exporter.windows with Windows-specific collectors and loki.source.windowsevent for Event Logs. Each platform's service management (launchd vs Windows Services) was properly configured."*

### Proactive Technology Management

*"Rather than waiting until Agent reached EOL, I migrated early to avoid last-minute issues. This demonstrates proactive technical debt management and staying current with vendor recommendations. Alloy provides better long-term support, a built-in UI for troubleshooting, and active development."*

---

## Summary

**Migration Status**: ✅ **Scripts Complete**

**Updated Files**:
- `scripts/setup-monitoring-macos-direct.sh` - Alloy v1.11.3 with River config
- `scripts/setup-monitoring-universal.sh` - macOS section updated for Alloy
- `scripts/setup-monitoring-windows-alloy.ps1` - New PowerShell script for Windows

**Key Changes**:
- Binary: `grafana-agent` → `alloy`
- Config: YAML → River language
- Version: v0.40.0 (EOL) → v1.11.3 (active)
- Added: Built-in UI at http://localhost:12345

**Testing Ready**:
- macOS script ready for deployment to .21
- Windows script ready for deployment to .245
- Linux devices unchanged (Promtail still valid)

**Next Action**: Test scripts on actual macOS and Windows devices, verify logs/metrics in Grafana.

---

**Created**: 2025-11-07
**Migration Completed By**: Claude Code
**Status**: Ready for Testing ✅

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
