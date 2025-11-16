# Universal Monitoring Setup - Quick Start Guide

**One script works on all platforms: Linux, macOS, and Windows!**

---

## Overview

The universal setup script automatically detects your operating system and runs the appropriate installation steps:

- **Linux** → Deploys Promtail + node_exporter via Docker
- **macOS** → Installs Grafana Agent via Homebrew
- **Windows** → Guides you to PowerShell script for Grafana Agent

---

## Quick Start

### For Linux & macOS

```bash
# Clone or navigate to the repo
cd homelab-security-hardening

# Run the universal setup script
./scripts/setup-monitoring-universal.sh
```

**That's it!** The script will:
1. Detect your OS automatically
2. Run the appropriate installation
3. Configure monitoring agents
4. Verify everything works

### For Windows

**Option 1: Via Git Bash (Recommended)**
```bash
# Run universal script (it will guide you to PowerShell)
./scripts/setup-monitoring-universal.sh
```

**Option 2: Direct PowerShell**
```powershell
# Open PowerShell as Administrator
# Navigate to repo
cd homelab-security-hardening\scripts

# Run Windows setup
powershell -ExecutionPolicy Bypass -File .\setup-monitoring-windows.ps1
```

---

## What Gets Installed

### Linux Devices
- ✅ **Docker** (if not already installed)
- ✅ **Promtail** → Ships logs to Loki
- ✅ **node_exporter** → Exposes system metrics
- ✅ **Firewall rules** → Opens ports 9100, 9080 for LAN
- ✅ **SSH hardening** → Root login disabled

**Collects**:
- systemd journal logs (SSH, sudo, system events)
- Docker container logs
- System metrics (CPU, memory, disk, network)

### macOS Devices
- ✅ **Homebrew** (if not already installed)
- ✅ **Grafana Agent** → All-in-one monitoring agent
- ✅ **node_exporter integration** → System metrics
- ✅ **Log collection** → system.log, install.log

**Collects**:
- macOS system logs
- System metrics (CPU, memory, disk, network)
- Installation logs

### Windows Devices
- ✅ **Grafana Agent** → Installed as Windows Service
- ✅ **windows_exporter integration** → System metrics
- ✅ **Event Log collection** → Security, System, Application logs
- ✅ **Firewall rule** → Opens port 12345 for metrics

**Collects**:
- Windows Event Logs (Event IDs: 4624, 4625, 4672, etc.)
- System metrics (CPU, memory, disk, network, services)
- Process and service information

---

## Prerequisites

### Linux
- **Supported**: Arch, CachyOS, Garuda, Ubuntu, Debian, Fedora, RHEL
- **Access**: sudo/root privileges
- **Network**: Can reach 192.168.0.19 (Raspberry Pi)

### macOS
- **Version**: macOS 10.15 (Catalina) or later
- **Access**: Admin user
- **Network**: Can reach 192.168.0.19

### Windows
- **Version**: Windows 10/11, Windows Server 2019+
- **Access**: Administrator privileges
- **PowerShell**: Version 5.1 or later
- **Network**: Can reach 192.168.0.19

---

## Step-by-Step Instructions

### Linux Setup

```bash
# 1. Navigate to repo
cd /path/to/homelab-security-hardening

# 2. Run universal script
./scripts/setup-monitoring-universal.sh

# The script will:
# - Detect your Linux distribution
# - Install Docker (if needed)
# - Deploy Promtail and node_exporter
# - Configure firewall
# - Harden SSH
# - Verify everything works

# 3. Verify installation
docker ps | grep -E '(promtail|node-exporter)'
curl http://localhost:9100/metrics | head
```

**Expected output**:
```
promtail-<hostname>        Up X minutes
node-exporter-<hostname>   Up X minutes
```

### macOS Setup

```bash
# 1. Navigate to repo
cd /path/to/homelab-security-hardening

# 2. Run universal script
./scripts/setup-monitoring-universal.sh

# The script will:
# - Install Homebrew (if needed)
# - Install Grafana Agent
# - Create configuration
# - Start agent service
# - Verify metrics endpoint

# 3. Verify installation
brew services list | grep grafana-agent
curl http://localhost:12345/metrics | head
```

**Expected output**:
```
grafana-agent started
# HELP go_gc_duration_seconds ...
```

### Windows Setup

**Step 1: Run via Git Bash (Optional)**
```bash
# Open Git Bash
cd /c/path/to/homelab-security-hardening
./scripts/setup-monitoring-universal.sh

# Will guide you to PowerShell script
```

**Step 2: Run PowerShell Script**
```powershell
# Open PowerShell as Administrator
# Right-click PowerShell → "Run as Administrator"

cd C:\path\to\homelab-security-hardening\scripts

# Run setup
powershell -ExecutionPolicy Bypass -File .\setup-monitoring-windows.ps1

# The script will:
# - Download Grafana Agent installer
# - Install as Windows Service
# - Configure Event Log collection
# - Grant necessary permissions
# - Start the service
# - Configure firewall

# Verify installation
Get-Service "Grafana Agent"
Invoke-WebRequest http://localhost:12345/metrics
```

**Expected output**:
```
Status   Name               DisplayName
------   ----               -----------
Running  Grafana Agent      Grafana Agent
```

---

## Verification

### Check Logs Reaching Loki

**From any device**:
```bash
# SSH to Raspberry Pi
ssh automation@100.112.203.63

# Check which hostnames are reporting
curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq

# Should see your new device hostname
```

### Check Metrics in Prometheus

**From any device**:
```bash
# SSH to Raspberry Pi
ssh automation@100.112.203.63

# Check scrape targets
curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {host: .labels.hostname, health: .health}'

# Your device should show "health": "up"
```

### Check in Grafana

1. Open: http://192.168.0.19:3000
2. Go to: **Explore** → **Loki**
3. Query: `{hostname="YOUR-HOSTNAME"}`
4. Should see logs appearing

---

## Troubleshooting

### Linux

**Service not running**:
```bash
docker ps -a | grep -E '(promtail|node-exporter)'
docker logs promtail-<hostname>
```

**Firewall blocking**:
```bash
sudo firewall-cmd --list-all
sudo ufw status
```

**Logs not appearing**:
```bash
# Check Promtail can reach Loki
docker exec promtail-<hostname> wget -O- http://192.168.0.19:3100/ready
```

### macOS

**Service not started**:
```bash
brew services list
brew services restart grafana-agent
brew services log grafana-agent
```

**Metrics not responding**:
```bash
# Check if process is running
ps aux | grep grafana-agent

# Check configuration
cat /opt/homebrew/etc/grafana-agent/config.yml
```

**Permissions issues**:
```bash
# macOS may require Full Disk Access
# System Preferences → Security & Privacy → Full Disk Access
# Add: /opt/homebrew/bin/grafana-agent
```

### Windows

**Service won't start**:
```powershell
Get-Service "Grafana Agent" | Select-Object *
Get-EventLog -LogName Application -Source "Grafana Agent" -Newest 20
```

**Event Logs not appearing**:
```powershell
# Check Event Log permissions
wevtutil gl Security
# Should show LOCAL SERVICE has Read access

# Test Event Log access
Get-EventLog -LogName Security -Newest 1
```

**Metrics not responding**:
```powershell
# Check process
Get-Process grafana-agent*

# Check firewall
Get-NetFirewallRule -DisplayName "Grafana Agent Metrics"

# Test locally
Invoke-WebRequest http://localhost:12345/metrics
```

---

## Add Device to Prometheus

After installation, add your device to Prometheus scrape config:

```bash
# SSH to Raspberry Pi
ssh automation@100.112.203.63

# Edit Prometheus config
nano ~/docker/loki-stack/prometheus.yml
```

**Add under `scrape_configs`**:

**For Linux**:
```yaml
  - job_name: 'node'
    static_configs:
      - targets: ['YOUR-IP:9100']
        labels:
          hostname: 'YOUR-HOSTNAME'
          instance: 'YOUR-HOSTNAME'
          os: 'linux'
```

**For macOS**:
```yaml
  - job_name: 'macos-agent'
    static_configs:
      - targets: ['YOUR-IP:12345']
        labels:
          hostname: 'YOUR-HOSTNAME'
          instance: 'YOUR-HOSTNAME'
          os: 'macos'
```

**For Windows**:
```yaml
  - job_name: 'windows-agent'
    static_configs:
      - targets: ['YOUR-IP:12345']
        labels:
          hostname: 'YOUR-HOSTNAME'
          instance: 'YOUR-HOSTNAME'
          os: 'windows'
```

**Reload Prometheus**:
```bash
docker exec prometheus kill -HUP 1
```

---

## Script Locations

```
homelab-security-hardening/
├── scripts/
│   ├── setup-monitoring-universal.sh     ⭐ Universal script (Linux/macOS)
│   ├── setup-monitoring-windows.ps1      ⭐ Windows PowerShell script
│   ├── setup-monitoring-local.sh         → Linux detailed script
│   └── setup-monitoring-local-enhanced.sh
└── docs/
    ├── UNIVERSAL-SETUP-GUIDE.md          ⭐ This file
    ├── MACOS-MONITORING-SETUP.md         → macOS detailed guide
    ├── WINDOWS-MONITORING-SETUP.md       → Windows detailed guide
    └── DEVICE-ONBOARDING-RUNBOOK.md      → Complete runbook
```

---

## Features

### Universal Script Benefits

✅ **Single command** works on all platforms
✅ **Automatic OS detection** - no manual configuration
✅ **Consistent setup** across all devices
✅ **Error handling** and verification built-in
✅ **Idempotent** - safe to run multiple times
✅ **Interactive prompts** for confirmation
✅ **Color-coded output** for easy reading

### What Makes It Universal

- **OS Detection**: Uses `$OSTYPE` to identify platform
- **Conditional Logic**: Runs appropriate installer per OS
- **Fallback Handling**: Guides Windows users to PowerShell
- **Verification**: Tests installation on all platforms
- **Documentation**: Points to detailed guides when needed

---

## Examples

### Example: Setup Linux Workstation

```bash
$ cd homelab-security-hardening
$ ./scripts/setup-monitoring-universal.sh

==========================================
Universal Home SOC Monitoring Setup
==========================================

✓ Detected: Linux (arch)

[Linux Setup]

[1/7] Checking Docker installation...
✓ Docker is already installed
Docker version 24.0.7

[2/7] Creating Promtail configuration...
✓ Promtail configuration created

[3/7] Deploying Promtail container...
✓ Promtail deployed

[4/7] Deploying node_exporter container...
✓ node_exporter deployed

[5/7] Configuring firewall...
✓ firewalld configured

[6/7] Setting up SSH keys...
✓ SSH key already configured

[7/7] Verifying deployment...

Container Status:
promtail-myhost        Up 5 seconds
node-exporter-myhost   Up 5 seconds

==========================================
Setup Complete!
==========================================
```

### Example: Setup macOS Device

```bash
$ ./scripts/setup-monitoring-universal.sh

==========================================
Universal Home SOC Monitoring Setup
==========================================

✓ Detected: macOS

[macOS Setup]

Configuration:
  Hostname: macbook
  User: john
  Loki Server: 192.168.0.19:3100

Continue with macOS setup? (y/n): y

[1/5] Checking Homebrew...
✓ Homebrew already installed
Homebrew 4.2.0

[2/5] Installing Grafana Agent...
✓ Grafana Agent installed

[3/5] Creating configuration...
✓ Configuration created

[4/5] Starting Grafana Agent service...
✓ Grafana Agent service started

[5/5] Verifying installation...

Service Status:
grafana-agent started

✓ Metrics endpoint responding

==========================================
macOS Setup Complete!
==========================================
```

---

## Security Considerations

### Linux
- ✅ Firewall configured to allow LAN only
- ✅ SSH hardened (root login disabled)
- ✅ Docker socket access controlled
- ✅ Containers run with minimal privileges

### macOS
- ✅ Grafana Agent runs as user service
- ✅ No root privileges required
- ✅ Only reads system logs (no write access)
- ✅ Metrics port bound to localhost

### Windows
- ✅ Service runs as LOCAL SERVICE account
- ✅ Event Log read-only access
- ✅ Firewall rule restricts to LAN
- ✅ No elevated privileges for normal operation

---

## Interview Talking Points

### Multi-Platform Deployment

*"I created a universal monitoring setup script that automatically detects the operating system and deploys the appropriate monitoring stack. On Linux, it uses Promtail with node_exporter; on macOS and Windows, it uses Grafana Agent. This demonstrates understanding of cross-platform differences in system monitoring."*

### Automation & User Experience

*"The script provides a single-command installation experience across all platforms, with automatic OS detection, interactive prompts, and built-in verification. This reduces deployment complexity from platform-specific instructions to one universal command."*

### OS-Specific Adaptations

*"I implemented platform-specific configurations: Docker containers for Linux, Homebrew services for macOS, and Windows Services for Windows. Each approach respects the platform's native service management while maintaining consistent monitoring capabilities."*

### Security Best Practices

*"Each platform deployment follows security best practices: firewall rules restrict monitoring ports to the local network, services run with minimal privileges, and log collection is read-only. On Windows, I configured the agent to run as LOCAL SERVICE and granted only the necessary Event Log permissions."*

---

## Summary

**One Script, All Platforms**:
```bash
./scripts/setup-monitoring-universal.sh
```

**What it does**:
- ✅ Detects your OS automatically
- ✅ Installs appropriate monitoring agent
- ✅ Configures log shipping to Loki
- ✅ Configures metrics shipping to Prometheus
- ✅ Verifies everything works
- ✅ Provides next steps

**Time to deploy**: 5-15 minutes per device

**Platforms supported**: Linux, macOS, Windows

**Result**: Centralized monitoring for all your devices! 🎉

---

**Created**: 2025-11-06
**Author**: Claude Code
**Purpose**: Unified monitoring setup across all platforms

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
