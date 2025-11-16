# Windows Monitoring Setup Guide

## Overview

Deploy Grafana Agent on Windows to ship Windows Event Logs and system metrics to your home SOC.

**What will be monitored:**
- ✅ System metrics (CPU, memory, disk, network, processes, services)
- ✅ Security Event Log (logins, privilege escalation, account changes)
- ✅ System Event Log (service starts/stops, system errors)
- ✅ Application Event Log (application errors and warnings)

---

## Prerequisites

- Windows 10/11 device on network (192.168.0.245 or other)
- Administrator access
- PowerShell

---

## Installation Steps

### Step 1: Download Grafana Agent

1. Go to: https://github.com/grafana/agent/releases
2. Download the latest Windows installer:
   - Look for `grafana-agent-installer.exe` or
   - `grafana-agent-flow-installer.exe` (newer version)

**Or via PowerShell:**
```powershell
# Download latest release (change version as needed)
$version = "v0.40.0"  # Check GitHub for latest
$url = "https://github.com/grafana/agent/releases/download/$version/grafana-agent-installer.exe"
Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\grafana-agent-installer.exe"
```

### Step 2: Install Grafana Agent

**Run installer as Administrator:**
```powershell
Start-Process -FilePath "$env:TEMP\grafana-agent-installer.exe" -Wait
```

**Or double-click** `grafana-agent-installer.exe` and follow prompts.

**Default install location:** `C:\Program Files\Grafana Agent\`

### Step 3: Get Configuration File

**Option A: Copy from homelab**
```powershell
# If you have SSH/SCP access from Windows
scp ssjlox@192.168.0.52:/run/media/ssjlox/gamer/homelab-security-hardening/configs/grafana-agent/windows-config.yml "C:\Program Files\Grafana Agent\config.yml"
```

**Option B: Create manually**
1. Open Notepad as Administrator
2. Copy contents from `configs/grafana-agent/windows-config.yml`
3. Save as: `C:\Program Files\Grafana Agent\config.yml`

### Step 4: Customize Configuration

Edit the config to replace hostname:

**Find your hostname:**
```powershell
$env:COMPUTERNAME
```

**Edit config:**
```powershell
# Open in Notepad as Admin
notepad "C:\Program Files\Grafana Agent\config.yml"

# Replace all instances of 'windows-laptop' with your actual hostname
```

**Or use PowerShell to replace:**
```powershell
$hostname = $env:COMPUTERNAME
$config = "C:\Program Files\Grafana Agent\config.yml"
(Get-Content $config) -replace 'windows-laptop', $hostname | Set-Content $config
```

### Step 5: Create Required Directories

```powershell
# Create data directory
New-Item -ItemType Directory -Path "C:\ProgramData\Grafana Agent" -Force

# Grant permissions
icacls "C:\ProgramData\Grafana Agent" /grant "NT AUTHORITY\LOCAL SERVICE:(OI)(CI)F"
```

### Step 6: Install and Start Service

**Install as Windows Service:**
```powershell
# Navigate to install directory
cd "C:\Program Files\Grafana Agent"

# Install service
.\grafana-agent-service.exe install

# Start service
Start-Service "Grafana Agent"

# Verify it's running
Get-Service "Grafana Agent"
```

**Expected output:**
```
Status   Name               DisplayName
------   ----               -----------
Running  Grafana Agent      Grafana Agent
```

### Step 7: Configure Windows Firewall

Allow Prometheus to scrape agent metrics (optional, only if you add it as a scrape target):

```powershell
# Allow inbound on port 12345 from LAN
New-NetFirewallRule -DisplayName "Grafana Agent Metrics" `
  -Direction Inbound `
  -LocalPort 12345 `
  -Protocol TCP `
  -Action Allow `
  -RemoteAddress 192.168.0.0/24
```

**Or via GUI:**
1. Windows Defender Firewall → Advanced Settings
2. Inbound Rules → New Rule
3. Port → TCP → Specific local ports: 12345
4. Allow the connection
5. Apply to Domain, Private, Public
6. Name: "Grafana Agent Metrics"

---

## Verification

### Check Service is Running

```powershell
Get-Service "Grafana Agent"
Get-Process grafana-agent*
```

### Check Logs

```powershell
# View service log (if logging enabled)
Get-Content "C:\ProgramData\Grafana Agent\agent.log" -Tail 50

# Or check Windows Event Viewer
eventvwr.msc
# Navigate to: Windows Logs → Application
# Look for "Grafana Agent" source
```

### Check Metrics Endpoint

```powershell
# Test local metrics endpoint
Invoke-WebRequest -Uri http://localhost:12345/metrics
```

Should return Prometheus-format metrics.

### Verify Logs Reaching Loki

**From capcorp9000 or Raspberry Pi:**
```bash
curl -s 'http://192.168.0.19:3100/loki/api/v1/label/hostname/values' | jq
```

Should see your Windows hostname.

### Check in Grafana

1. Open http://192.168.0.19:3000
2. Go to Explore → Loki
3. Query: `{hostname="YOUR-WINDOWS-HOSTNAME"}`
4. Should see Windows Event Log entries

---

## Troubleshooting

### Service won't start

**Check service status:**
```powershell
Get-Service "Grafana Agent" | Select-Object *
```

**Check for config errors:**
```powershell
# Test config
cd "C:\Program Files\Grafana Agent"
.\grafana-agent.exe -config.file="config.yml" -dry-run
```

**Common issues:**
1. **Config syntax error:** Validate YAML syntax
2. **Permission denied:** Run as Administrator
3. **Port already in use:** Check if another service uses port 12345

### No Event Logs appearing

**Grant Event Log read permissions:**
```powershell
# Grant LOCAL SERVICE account read access to Event Logs
wevtutil sl Security /ca:O:BAG:SYD:(A;;0xf0007;;;SY)(A;;0x7;;;BA)(A;;0x1;;;BO)(A;;0x1;;;SO)(A;;0x1;;;S-1-5-32-573)(A;;0x1;;;S-1-5-19)
```

**Or via GUI:**
1. Event Viewer → Right-click "Security" → Properties
2. Security tab → Add "LOCAL SERVICE"
3. Grant "Read" permission

**Check agent has permission:**
```powershell
# Try reading Security log as LOCAL SERVICE
psexec -i -u "NT AUTHORITY\LOCAL SERVICE" powershell Get-EventLog -LogName Security -Newest 1
```

### Can't reach Loki/Prometheus

**Test network connectivity:**
```powershell
# Test Loki
Test-NetConnection -ComputerName 192.168.0.19 -Port 3100

# Test Prometheus
Test-NetConnection -ComputerName 192.168.0.19 -Port 9090
```

**Check Windows Firewall isn't blocking outbound:**
```powershell
# Outbound rules
Get-NetFirewallRule -Direction Outbound | Where-Object {$_.Enabled -eq $true}
```

### High CPU usage

**Event Log volume too high:**
```yaml
# In config.yml, add filtering to only capture important events
pipeline_stages:
  - match:
      selector: '{job="windows-security"}'
      stages:
        - json:
            expressions:
              event_id: eventID
        # Only keep specific security events
        - match:
            selector: '{event_id=~"4624|4625|4648|4672"}'
            action: keep
        - drop:
            expression: '.*'
```

---

## Add to Prometheus (on Raspberry Pi)

```bash
ssh automation@100.112.203.63
nano /home/automation/docker/loki-stack/prometheus.yml
```

Add under `scrape_configs`:
```yaml
  - job_name: 'windows-agent'
    static_configs:
      - targets: ['192.168.0.245:12345']  # Change IP
        labels:
          hostname: 'YOUR-WINDOWS-HOSTNAME'
          instance: 'windows-laptop'
          os: 'windows'
```

Reload:
```bash
docker exec prometheus kill -HUP 1
```

---

## Useful Event IDs to Monitor

### Security Log
- **4624** - Successful logon
- **4625** - Failed logon (brute force detection)
- **4634** - Logoff
- **4648** - Logon using explicit credentials (RunAs)
- **4672** - Special privileges assigned to new logon (admin rights)
- **4720** - User account created
- **4726** - User account deleted
- **4738** - User account changed
- **4740** - User account locked out
- **4767** - User account unlocked

### System Log
- **1074** - System shutdown/restart initiated
- **6005** - Event Log service started (boot)
- **6006** - Event Log service stopped
- **7036** - Service start/stop
- **7040** - Service start type changed

---

## Stopping/Uninstalling

### Stop Service
```powershell
Stop-Service "Grafana Agent"
```

### Uninstall
```powershell
# Stop service
Stop-Service "Grafana Agent"

# Uninstall service
cd "C:\Program Files\Grafana Agent"
.\grafana-agent-service.exe uninstall

# Remove files
Remove-Item -Recurse -Force "C:\Program Files\Grafana Agent"
Remove-Item -Recurse -Force "C:\ProgramData\Grafana Agent"
```

---

## Security Considerations

### Least Privilege

- Agent runs as LOCAL SERVICE (limited privileges)
- Only reads Event Logs (no write access)
- Metrics collection uses read-only Windows APIs

### Network Security

- Agent connects outbound to Raspberry Pi (192.168.0.19)
- Traffic stays within LAN (192.168.0.0/24)
- Firewall rule restricts scraping to LAN only
- No external exposure

### Event Log Access

Agent needs permission to read Security Event Log. This is normal for SIEM/monitoring tools.

---

## Interview Talking Points

*"I deployed Grafana Agent on Windows to ship Windows Event Logs to my centralized SIEM. The agent runs as a Windows service with LOCAL SERVICE account privileges, following least-privilege principles.*

*I configured it to scrape Security, System, and Application Event Logs, with pipeline stages to filter and label events by Event ID. For example, Event ID 4625 indicates failed logons, which I use for brute-force detection.*

*The agent uses windows_exporter for system metrics (CPU, memory, disk, services) and ships everything to Prometheus and Loki via remote_write. This demonstrates understanding of Windows-specific security monitoring - Event IDs, service principals, and Windows authentication mechanisms."*

---

## Next Steps

1. ✅ Verify service is running
2. ✅ Check logs appearing in Loki
3. ✅ Add to Grafana dashboards
4. ✅ Create alerts for security events (4625, 4672, etc.)
5. ✅ Document baseline Event Log volume

---

## Additional Resources

- Grafana Agent Windows: https://grafana.com/docs/agent/latest/static/set-up/install-agent-on-windows/
- Windows Event Log Collection: https://grafana.com/docs/agent/latest/static/configuration/logs-config/
- Windows Event IDs: https://www.ultimatewindowssecurity.com/securitylog/encyclopedia/
- windows_exporter: https://github.com/prometheus-community/windows_exporter
