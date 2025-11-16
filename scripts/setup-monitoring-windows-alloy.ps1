# Windows Monitoring Setup - Grafana Alloy
# PowerShell script to install Grafana Alloy on Windows

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Configuration
$LOKI_SERVER = "192.168.0.19:3100"
$PROMETHEUS_SERVER = "192.168.0.19:9090"
$ALLOY_VERSION = "v1.11.3"
$INSTALL_DIR = "C:\Program Files\GrafanaLabs\Alloy"
$CONFIG_DIR = "$INSTALL_DIR\config"
$DATA_DIR = "$INSTALL_DIR\data"

Write-Host "=========================================="
Write-Host "Windows Monitoring Setup (Grafana Alloy)"
Write-Host "=========================================="
Write-Host ""

$HOSTNAME = $env:COMPUTERNAME
$CURRENT_USER = $env:USERNAME

Write-Host "Configuration:"
Write-Host "  Hostname: $HOSTNAME"
Write-Host "  User: $CURRENT_USER"
Write-Host "  Loki Server: $LOKI_SERVER"
Write-Host "  Prometheus Server: $PROMETHEUS_SERVER"
Write-Host ""

$confirmation = Read-Host "Continue with installation? (Y/N)"
if ($confirmation -ne 'Y') {
    Write-Host "Installation cancelled."
    exit 0
}

# Step 1: Download Grafana Alloy
Write-Host ""
Write-Host "[1/6] Downloading Grafana Alloy..."

$DOWNLOAD_URL = "https://github.com/grafana/alloy/releases/download/$ALLOY_VERSION/alloy-installer-windows-amd64.exe"
$INSTALLER_PATH = "$env:TEMP\alloy-installer.exe"

Write-Host "  Downloading from: $DOWNLOAD_URL"

try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $INSTALLER_PATH -UseBasicParsing
    Write-Host "  [OK] Download complete" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Run installer
Write-Host ""
Write-Host "[2/6] Installing Grafana Alloy..."
Write-Host "  Running installer (this may take a minute)..."

try {
    # Run installer silently
    Start-Process -FilePath $INSTALLER_PATH -ArgumentList "/S" -Wait -NoNewWindow

    # Verify installation
    if (Test-Path "$INSTALL_DIR\alloy.exe") {
        Write-Host "  [OK] Alloy installed successfully" -ForegroundColor Green
        & "$INSTALL_DIR\alloy.exe" --version
    } else {
        Write-Host "  [ERROR] Installation failed - binary not found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  [ERROR] Installation failed: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Create directories
Write-Host ""
Write-Host "[3/6] Creating configuration directories..."

try {
    New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $DATA_DIR -Force | Out-Null
    Write-Host "  [OK] Directories created" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Failed to create directories: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Create configuration file
Write-Host ""
Write-Host "[4/6] Creating Alloy configuration..."

$CONFIG_CONTENT = @"
// Grafana Alloy Configuration for Windows
// Collects Windows Event Logs and system metrics

logging {
  level  = "info"
  format = "logfmt"
}

// ====================
// Metrics Collection
// ====================

// Windows system metrics (replaces windows_exporter)
prometheus.exporter.windows "windows_system" {
  enabled_collectors = [
    "cpu",
    "cs",
    "logical_disk",
    "memory",
    "net",
    "os",
    "system",
    "tcp",
  ]
}

// Scrape windows exporter
prometheus.scrape "windows_metrics" {
  targets        = prometheus.exporter.windows.windows_system.targets
  forward_to     = [prometheus.remote_write.default.receiver]
  scrape_interval = "15s"

  clustering {
    enabled = false
  }
}

// Send metrics to Prometheus
prometheus.remote_write "default" {
  endpoint {
    url = "http://$PROMETHEUS_SERVER/api/v1/write"

    queue_config {
      max_samples_per_send = 1000
    }
  }

  external_labels = {
    hostname = "$HOSTNAME",
    job      = "windows-exporter",
    instance = "$HOSTNAME",
  }
}

// ====================
// Log Collection (Windows Event Logs)
// ====================

// Security Event Log
loki.source.windowsevent "security" {
  eventlog_name = "Security"

  forward_to = [loki.write.default.receiver]

  labels = {
    job      = "windows-security",
    hostname = "$HOSTNAME",
  }
}

// System Event Log
loki.source.windowsevent "system" {
  eventlog_name = "System"

  forward_to = [loki.write.default.receiver]

  labels = {
    job      = "windows-system",
    hostname = "$HOSTNAME",
  }
}

// Application Event Log
loki.source.windowsevent "application" {
  eventlog_name = "Application"

  forward_to = [loki.write.default.receiver]

  labels = {
    job      = "windows-application",
    hostname = "$HOSTNAME",
  }
}

// Ship logs to Loki
loki.write "default" {
  endpoint {
    url = "http://$LOKI_SERVER/loki/api/v1/push"
  }

  external_labels = {
    hostname = "$HOSTNAME",
  }
}
"@

$CONFIG_PATH = "$CONFIG_DIR\config.alloy"

try {
    $CONFIG_CONTENT | Out-File -FilePath $CONFIG_PATH -Encoding UTF8 -Force
    Write-Host "  [OK] Configuration created" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Failed to create config: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Create and start Windows Service
Write-Host ""
Write-Host "[5/6] Creating Windows Service..."

try {
    # Stop and remove old service if exists
    $service = Get-Service -Name "Alloy" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "  Stopping existing service..."
        Stop-Service -Name "Alloy" -Force -ErrorAction SilentlyContinue
        & sc.exe delete "Alloy" | Out-Null
        Start-Sleep -Seconds 2
    }

    # Create new service
    Write-Host "  Creating Alloy service..."

    $servicePath = "`"$INSTALL_DIR\alloy.exe`" run `"$CONFIG_PATH`" --storage.path=`"$DATA_DIR`" --server.http.listen-addr=127.0.0.1:12345"

    & sc.exe create "Alloy" binPath= $servicePath start= auto DisplayName= "Grafana Alloy" | Out-Null

    # Set service to run as Local System
    & sc.exe config "Alloy" obj= "LocalSystem" | Out-Null

    # Set service description
    & sc.exe description "Alloy" "Grafana Alloy - Telemetry collector for logs and metrics" | Out-Null

    Write-Host "  [OK] Service created" -ForegroundColor Green

    # Start service
    Write-Host "  Starting Alloy service..."
    Start-Service -Name "Alloy"
    Start-Sleep -Seconds 3

    $serviceStatus = Get-Service -Name "Alloy"
    if ($serviceStatus.Status -eq "Running") {
        Write-Host "  [OK] Service started successfully" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] Service not running. Status: $($serviceStatus.Status)" -ForegroundColor Yellow
    }

} catch {
    Write-Host "  [ERROR] Failed to create/start service: $_" -ForegroundColor Red
    Write-Host "  Check event logs for details" -ForegroundColor Yellow
}

# Step 6: Configure Firewall
Write-Host ""
Write-Host "[6/6] Configuring firewall..."

try {
    # Remove old rule if exists
    Remove-NetFirewallRule -DisplayName "Alloy Metrics" -ErrorAction SilentlyContinue

    # Add new rule for metrics endpoint
    New-NetFirewallRule -DisplayName "Alloy Metrics" `
                        -Direction Inbound `
                        -LocalPort 12345 `
                        -Protocol TCP `
                        -Action Allow `
                        -Profile Private `
                        -Description "Allow Prometheus to scrape Alloy metrics from LAN" | Out-Null

    Write-Host "  [OK] Firewall rule created" -ForegroundColor Green
} catch {
    Write-Host "  [WARNING] Failed to configure firewall: $_" -ForegroundColor Yellow
    Write-Host "  You may need to manually allow port 12345" -ForegroundColor Yellow
}

# Verification
Write-Host ""
Write-Host "=========================================="
Write-Host "Verifying Installation" -ForegroundColor Cyan
Write-Host "=========================================="
Write-Host ""

# Check service
Write-Host "Service Status:"
$service = Get-Service -Name "Alloy"
Write-Host "  Name: $($service.Name)"
Write-Host "  Status: $($service.Status)" -ForegroundColor $(if($service.Status -eq "Running"){"Green"}else{"Red"})
Write-Host "  Start Type: $($service.StartType)"
Write-Host ""

# Check metrics endpoint
Write-Host "Testing metrics endpoint (http://localhost:12345/metrics)..."
Start-Sleep -Seconds 3

try {
    $response = Invoke-WebRequest -Uri "http://localhost:12345/metrics" -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-Host "  [OK] Metrics endpoint responding" -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARNING] Metrics endpoint not ready yet" -ForegroundColor Yellow
    Write-Host "  Wait 30 seconds and try: Invoke-WebRequest http://localhost:12345/metrics" -ForegroundColor Yellow
}
Write-Host ""

# Check Alloy UI
Write-Host "Testing Alloy UI (http://localhost:12345)..."
try {
    $response = Invoke-WebRequest -Uri "http://localhost:12345" -UseBasicParsing -TimeoutSec 5
    if ($response.Content -match "Grafana Alloy") {
        Write-Host "  [OK] Alloy UI available" -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARNING] UI not ready yet" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "=========================================="
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "=========================================="
Write-Host ""
Write-Host "Grafana Alloy is now:"
Write-Host "  * Collecting Windows Event Logs (Security, System, Application)"
Write-Host "  * Collecting system metrics (CPU, memory, disk, network)"
Write-Host "  * Shipping logs to Loki at $LOKI_SERVER"
Write-Host "  * Sending metrics to Prometheus at $PROMETHEUS_SERVER"
Write-Host ""
Write-Host "Files created:"
Write-Host "  Binary: $INSTALL_DIR\alloy.exe"
Write-Host "  Config: $CONFIG_PATH"
Write-Host "  Data: $DATA_DIR"
Write-Host ""
Write-Host "Manage service:"
Write-Host "  Status:  Get-Service Alloy"
Write-Host "  Stop:    Stop-Service Alloy"
Write-Host "  Start:   Start-Service Alloy"
Write-Host "  Restart: Restart-Service Alloy"
Write-Host "  Logs:    Get-EventLog -LogName Application -Source Alloy -Newest 20"
Write-Host ""
Write-Host "Next Steps:"
Write-Host "1. Verify metrics: Invoke-WebRequest http://localhost:12345/metrics"
Write-Host "2. Check Alloy UI: Start-Process http://localhost:12345"
Write-Host "3. Verify logs in Grafana: {hostname=`"$HOSTNAME`"}"
Write-Host ""
Write-Host "Note: Grafana Alloy has REPLACED deprecated Grafana Agent"
Write-Host "  * Active development and long-term support"
Write-Host "  * River configuration language (not YAML)"
Write-Host "  * Built-in UI for debugging"
Write-Host ""

# Cleanup
Remove-Item -Path $INSTALLER_PATH -Force -ErrorAction SilentlyContinue

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
