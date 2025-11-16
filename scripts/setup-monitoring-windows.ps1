# Windows Monitoring Setup Script
# Run this as Administrator in PowerShell
# Sets up Grafana Agent for Windows Event Log collection and metrics

# Configuration
$LOKI_SERVER = "192.168.0.19:3100"
$PROMETHEUS_SERVER = "192.168.0.19:9090"
$GRAFANA_AGENT_VERSION = "v0.40.0"  # Check https://github.com/grafana/agent/releases for latest
$HOSTNAME = $env:COMPUTERNAME

# Check for Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Windows Monitoring Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor White
Write-Host "  Hostname: $HOSTNAME" -ForegroundColor Gray
Write-Host "  Loki Server: $LOKI_SERVER" -ForegroundColor Gray
Write-Host "  Prometheus Server: $PROMETHEUS_SERVER" -ForegroundColor Gray
Write-Host ""

$continue = Read-Host "Continue with installation? (y/n)"
if ($continue -ne 'y') {
    Write-Host "Installation cancelled." -ForegroundColor Yellow
    exit 0
}

# Step 1: Download Grafana Agent
Write-Host ""
Write-Host "[1/7] Downloading Grafana Agent..." -ForegroundColor Cyan

$downloadUrl = "https://github.com/grafana/agent/releases/download/$GRAFANA_AGENT_VERSION/grafana-agent-installer.exe"
$installerPath = "$env:TEMP\grafana-agent-installer.exe"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
    Write-Host "  Downloaded to: $installerPath" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to download Grafana Agent" -ForegroundColor Red
    Write-Host "  Please download manually from:" -ForegroundColor Yellow
    Write-Host "  https://github.com/grafana/agent/releases" -ForegroundColor Yellow
    exit 1
}

# Step 2: Install Grafana Agent
Write-Host ""
Write-Host "[2/7] Installing Grafana Agent..." -ForegroundColor Cyan

$installPath = "C:\Program Files\Grafana Agent"

if (Test-Path $installPath) {
    Write-Host "  Grafana Agent already installed" -ForegroundColor Yellow
} else {
    Start-Process -FilePath $installerPath -Wait -ArgumentList "/S"
    Write-Host "  Installed to: $installPath" -ForegroundColor Green
}

# Step 3: Create Configuration Directory
Write-Host ""
Write-Host "[3/7] Creating configuration..." -ForegroundColor Cyan

$dataDir = "C:\ProgramData\Grafana Agent"
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null

# Grant LOCAL SERVICE account access
icacls $dataDir /grant "NT AUTHORITY\LOCAL SERVICE:(OI)(CI)F" | Out-Null

Write-Host "  Data directory created: $dataDir" -ForegroundColor Green

# Step 4: Create Configuration File
Write-Host ""
Write-Host "[4/7] Writing configuration file..." -ForegroundColor Cyan

$configPath = "$installPath\config.yml"

$configContent = @"
server:
  log_level: info

metrics:
  wal_directory: C:\ProgramData\Grafana Agent
  global:
    scrape_interval: 15s
    remote_write:
      - url: http://${PROMETHEUS_SERVER}/api/v1/write

  configs:
    - name: integrations
      remote_write:
        - url: http://${PROMETHEUS_SERVER}/api/v1/write

integrations:
  windows_exporter:
    enabled: true
    # Windows-specific collectors
    enabled_collectors:
      - cpu
      - cs
      - logical_disk
      - net
      - os
      - system
      - memory
      - process
      - service
    relabel_configs:
      - target_label: hostname
        replacement: '${HOSTNAME}'
      - target_label: job
        replacement: 'windows-exporter'
      - target_label: instance
        replacement: '${HOSTNAME}'

logs:
  configs:
    - name: windows-logs
      clients:
        - url: http://${LOKI_SERVER}/loki/api/v1/push

      positions:
        filename: C:\ProgramData\Grafana Agent\positions.yaml

      scrape_configs:
        # Windows Security Event Log
        - job_name: windows-security
          windows_events:
            use_incoming_timestamp: true
            eventlog_name: "Security"
            labels:
              job: 'windows-security'
              hostname: '${HOSTNAME}'
          pipeline_stages:
            - match:
                selector: '{job="windows-security"}'
                stages:
                  - json:
                      expressions:
                        event_id: eventID
                        level: level
                  - labels:
                      event_id:

        # Windows System Event Log
        - job_name: windows-system
          windows_events:
            use_incoming_timestamp: true
            eventlog_name: "System"
            labels:
              job: 'windows-system'
              hostname: '${HOSTNAME}'
          pipeline_stages:
            - match:
                selector: '{job="windows-system"}'
                stages:
                  - json:
                      expressions:
                        event_id: eventID
                        level: level
                  - labels:
                      event_id:

        # Windows Application Event Log
        - job_name: windows-application
          windows_events:
            use_incoming_timestamp: true
            eventlog_name: "Application"
            labels:
              job: 'windows-application'
              hostname: '${HOSTNAME}'
          pipeline_stages:
            - match:
                selector: '{job="windows-application"}'
                stages:
                  - json:
                      expressions:
                        event_id: eventID
                        level: level
                  - labels:
                      event_id:
"@

$configContent | Out-File -FilePath $configPath -Encoding UTF8
Write-Host "  Configuration written to: $configPath" -ForegroundColor Green

# Create positions file
New-Item -ItemType File -Path "$dataDir\positions.yaml" -Force | Out-Null

# Step 5: Grant Event Log Permissions
Write-Host ""
Write-Host "[5/7] Granting Event Log read permissions..." -ForegroundColor Cyan

try {
    wevtutil sl Security /ca:"O:BAG:SYD:(A;;0xf0007;;;SY)(A;;0x7;;;BA)(A;;0x1;;;BO)(A;;0x1;;;SO)(A;;0x1;;;S-1-5-32-573)(A;;0x1;;;S-1-5-19)"
    Write-Host "  LOCAL SERVICE granted Security Event Log access" -ForegroundColor Green
} catch {
    Write-Host "  Warning: Could not modify Security log permissions" -ForegroundColor Yellow
    Write-Host "  You may need to grant manually via Event Viewer" -ForegroundColor Yellow
}

# Step 6: Install and Start Service
Write-Host ""
Write-Host "[6/7] Installing Grafana Agent service..." -ForegroundColor Cyan

Set-Location $installPath

# Stop existing service if running
try {
    Stop-Service "Grafana Agent" -ErrorAction SilentlyContinue
} catch {}

# Install service
& ".\grafana-agent-service.exe" install

# Start service
try {
    Start-Service "Grafana Agent"
    Write-Host "  Service installed and started" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to start service" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
}

# Step 7: Configure Windows Firewall
Write-Host ""
Write-Host "[7/7] Configuring Windows Firewall..." -ForegroundColor Cyan

try {
    New-NetFirewallRule -DisplayName "Grafana Agent Metrics" `
        -Direction Inbound `
        -LocalPort 12345 `
        -Protocol TCP `
        -Action Allow `
        -RemoteAddress 192.168.0.0/24 `
        -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  Firewall rule added for port 12345" -ForegroundColor Green
} catch {
    Write-Host "  Firewall rule may already exist" -ForegroundColor Yellow
}

# Verification
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Verifying Installation..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check service status
$service = Get-Service "Grafana Agent" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Service Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Red' })
} else {
    Write-Host "Service Status: NOT FOUND" -ForegroundColor Red
}

# Check process
$process = Get-Process grafana-agent* -ErrorAction SilentlyContinue
if ($process) {
    Write-Host "Process Running: YES" -ForegroundColor Green
} else {
    Write-Host "Process Running: NO" -ForegroundColor Red
}

# Test metrics endpoint
Write-Host ""
Write-Host "Testing metrics endpoint (http://localhost:12345/metrics)..." -ForegroundColor White
try {
    $response = Invoke-WebRequest -Uri "http://localhost:12345/metrics" -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-Host "  Metrics endpoint: RESPONDING" -ForegroundColor Green
    }
} catch {
    Write-Host "  Metrics endpoint: NOT READY (wait 30 seconds)" -ForegroundColor Yellow
}

# Final Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "What was configured:" -ForegroundColor White
Write-Host "  Hostname: $HOSTNAME" -ForegroundColor Gray
Write-Host "  Windows Event Logs: Security, System, Application" -ForegroundColor Gray
Write-Host "  System Metrics: CPU, Memory, Disk, Network, Services" -ForegroundColor Gray
Write-Host "  Shipping to Loki: $LOKI_SERVER" -ForegroundColor Gray
Write-Host "  Shipping to Prometheus: $PROMETHEUS_SERVER" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "1. Add $HOSTNAME to Prometheus scrape config on Raspberry Pi" -ForegroundColor Gray
Write-Host "2. Wait 30 seconds, then verify:" -ForegroundColor Gray
Write-Host "   - Metrics: http://localhost:12345/metrics" -ForegroundColor Gray
Write-Host "   - Logs in Grafana: {hostname=`"$HOSTNAME`"}" -ForegroundColor Gray
Write-Host ""
Write-Host "Configuration file: $configPath" -ForegroundColor Gray
Write-Host "Check logs: Get-EventLog -LogName Application -Source 'Grafana Agent'" -ForegroundColor Gray
Write-Host ""
Write-Host "Troubleshooting guide: docs\WINDOWS-MONITORING-SETUP.md" -ForegroundColor Gray
Write-Host ""

Read-Host "Press Enter to exit"
