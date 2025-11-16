#!/bin/bash
# macOS Monitoring Setup - Direct Installation (No Homebrew Required)
# Downloads Grafana Alloy directly and sets up as launchd service

set -e

# Configuration
LOKI_SERVER="192.168.0.19:3100"
PROMETHEUS_SERVER="192.168.0.19:9090"
ALLOY_VERSION="v1.11.3"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "macOS Monitoring Setup (Direct Install)"
echo "=========================================="
echo ""

HOSTNAME=$(hostname -s)
CURRENT_USER=$(whoami)
ARCH=$(uname -m)

echo "Configuration:"
echo "  Hostname: $HOSTNAME"
echo "  User: $CURRENT_USER"
echo "  Architecture: $ARCH"
echo "  Loki Server: $LOKI_SERVER"
echo ""

read -p "Continue with installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Step 1: Download Grafana Alloy
echo ""
echo "[1/5] Downloading Grafana Alloy..."

if [ "$ARCH" = "arm64" ]; then
    DOWNLOAD_URL="https://github.com/grafana/alloy/releases/download/${ALLOY_VERSION}/alloy-darwin-arm64.zip"
    echo "  Detected Apple Silicon (M1/M2/M3)"
else
    DOWNLOAD_URL="https://github.com/grafana/alloy/releases/download/${ALLOY_VERSION}/alloy-darwin-amd64.zip"
    echo "  Detected Intel Mac"
fi

echo "  Downloading from: $DOWNLOAD_URL"

# Create temp directory for download
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download and extract
curl -fsSL -o alloy.zip "$DOWNLOAD_URL"
unzip -q alloy.zip

# Install binary
sudo mkdir -p /usr/local/bin
sudo mv alloy-darwin-* /usr/local/bin/alloy
sudo chmod +x /usr/local/bin/alloy

# Cleanup
cd -
rm -rf "$TEMP_DIR"

if [ -x /usr/local/bin/alloy ]; then
    echo "${GREEN}✓${NC} Grafana Alloy downloaded"
    /usr/local/bin/alloy --version
else
    echo "${RED}✗${NC} Download failed"
    exit 1
fi

# Step 2: Create Configuration Directory
echo ""
echo "[2/5] Creating configuration..."

sudo mkdir -p /usr/local/etc/alloy
sudo mkdir -p /usr/local/var/lib/alloy

# Create config file (Alloy uses River configuration language)
sudo tee /usr/local/etc/alloy/config.alloy > /dev/null <<'EOF'
// Grafana Alloy Configuration for macOS
// Collects system metrics and logs

// Logging configuration
logging {
  level  = "info"
  format = "logfmt"
}

// ====================
// Metrics Collection
// ====================

// Unix system metrics (replaces node_exporter)
prometheus.exporter.unix "macos_system" {
  set_collectors = ["darwin"]

  // Enable specific collectors
  enable_collectors = [
    "cpu",
    "diskstats",
    "filesystem",
    "loadavg",
    "meminfo",
    "netdev",
    "time",
  ]
}

// Scrape the unix exporter
prometheus.scrape "macos_metrics" {
  targets = prometheus.exporter.unix.macos_system.targets

  forward_to = [prometheus.remote_write.default.receiver]

  scrape_interval = "15s"

  // Add labels to identify this host
  clustering {
    enabled = false
  }
}

// Send metrics to Prometheus
prometheus.remote_write "default" {
  endpoint {
    url = "http://PROMETHEUS_SERVER/api/v1/write"

    queue_config {
      max_samples_per_send = 1000
    }
  }

  external_labels = {
    hostname = "HOSTNAME_PLACEHOLDER",
    job      = "macos-node-exporter",
    instance = "HOSTNAME_PLACEHOLDER",
  }
}

// ====================
// Log Collection
// ====================

// Match system log file
local.file_match "system_logs" {
  path_targets = [{
    __address__ = "localhost",
    __path__    = "/var/log/system.log",
    job         = "macos-system",
    hostname    = "HOSTNAME_PLACEHOLDER",
  }]
}

// Match install log file
local.file_match "install_logs" {
  path_targets = [{
    __address__ = "localhost",
    __path__    = "/var/log/install.log",
    job         = "macos-install",
    hostname    = "HOSTNAME_PLACEHOLDER",
  }]
}

// Collect system logs
loki.source.file "system" {
  targets    = local.file_match.system_logs.targets
  forward_to = [loki.write.default.receiver]
}

// Collect install logs
loki.source.file "install" {
  targets    = local.file_match.install_logs.targets
  forward_to = [loki.write.default.receiver]
}

// Ship logs to Loki
loki.write "default" {
  endpoint {
    url = "http://LOKI_SERVER/loki/api/v1/push"
  }

  external_labels = {
    hostname = "HOSTNAME_PLACEHOLDER",
  }
}
EOF

# Replace placeholders with actual values
sudo sed -i '' "s|PROMETHEUS_SERVER|${PROMETHEUS_SERVER}|g" /usr/local/etc/alloy/config.alloy
sudo sed -i '' "s|LOKI_SERVER|${LOKI_SERVER}|g" /usr/local/etc/alloy/config.alloy
sudo sed -i '' "s|HOSTNAME_PLACEHOLDER|${HOSTNAME}|g" /usr/local/etc/alloy/config.alloy

echo "${GREEN}✓${NC} Configuration created"

# Step 3: Create launchd service
echo ""
echo "[3/5] Creating launchd service..."

sudo tee /Library/LaunchDaemons/com.grafana.alloy.plist > /dev/null <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.grafana.alloy</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/alloy</string>
        <string>run</string>
        <string>/usr/local/etc/alloy/config.alloy</string>
        <string>--storage.path=/usr/local/var/lib/alloy</string>
        <string>--server.http.listen-addr=127.0.0.1:12345</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/alloy.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/alloy-error.log</string>
</dict>
</plist>
PLIST

echo "${GREEN}✓${NC} Service file created"

# Step 4: Load and start service
echo ""
echo "[4/5] Starting Grafana Alloy service..."

# Unload if already loaded
sudo launchctl unload /Library/LaunchDaemons/com.grafana.alloy.plist 2>/dev/null || true

# Load service
sudo launchctl load /Library/LaunchDaemons/com.grafana.alloy.plist

sleep 3

# Check if running
if pgrep -f "alloy run" > /dev/null; then
    echo "${GREEN}✓${NC} Grafana Alloy service started"
else
    echo "${YELLOW}⚠${NC} Service may not have started. Checking logs..."
    tail -20 /var/log/alloy-error.log 2>/dev/null || echo "No error log yet"
fi

# Step 5: Verify
echo ""
echo "[5/5] Verifying installation..."
echo ""

echo "Process Status:"
if pgrep -lf "alloy run"; then
    echo "${GREEN}✓${NC} Process running"
else
    echo "${RED}✗${NC} Process not running"
fi
echo ""

echo "Testing metrics endpoint (http://localhost:12345/metrics)..."
sleep 2
if curl -s http://localhost:12345/metrics | head -1 | grep -q "HELP"; then
    echo "${GREEN}✓${NC} Metrics endpoint responding"
else
    echo "${YELLOW}⚠${NC} Metrics endpoint not ready yet (wait 30 seconds and try: curl http://localhost:12345/metrics)"
fi
echo ""

echo "Testing Alloy UI (http://localhost:12345)..."
if curl -s http://localhost:12345 | grep -q "Grafana Alloy"; then
    echo "${GREEN}✓${NC} Alloy UI available at http://localhost:12345"
else
    echo "${YELLOW}⚠${NC} UI may not be ready yet"
fi
echo ""

# Final Summary
echo "=========================================="
echo "${GREEN}Installation Complete!${NC}"
echo "=========================================="
echo ""
echo "Grafana Alloy is now:"
echo "  • Collecting system metrics via prometheus.exporter.unix"
echo "  • Shipping logs to Loki at ${LOKI_SERVER}"
echo "  • Sending metrics to Prometheus at ${PROMETHEUS_SERVER}"
echo ""
echo "Files created:"
echo "  Binary: /usr/local/bin/alloy"
echo "  Config: /usr/local/etc/alloy/config.alloy"
echo "  Service: /Library/LaunchDaemons/com.grafana.alloy.plist"
echo "  Logs: /var/log/alloy.log"
echo "  Storage: /usr/local/var/lib/alloy"
echo ""
echo "Manage service:"
echo "  Stop:    sudo launchctl unload /Library/LaunchDaemons/com.grafana.alloy.plist"
echo "  Start:   sudo launchctl load /Library/LaunchDaemons/com.grafana.alloy.plist"
echo "  Restart: sudo launchctl kickstart -k system/com.grafana.alloy"
echo "  Logs:    tail -f /var/log/alloy.log"
echo "  UI:      open http://localhost:12345"
echo ""
echo "Next Steps:"
echo "1. Verify metrics are being collected:"
echo "   curl http://localhost:12345/metrics | grep node_"
echo ""
echo "2. Check Alloy UI for component status:"
echo "   open http://localhost:12345"
echo ""
echo "3. Verify logs in Grafana: {hostname=\"${HOSTNAME}\"}"
echo ""
echo "4. Note: Alloy has REPLACED deprecated Grafana Agent"
echo "   • Alloy is the official successor (actively developed)"
echo "   • Uses River configuration language instead of YAML"
echo "   • Includes built-in UI for debugging"
echo ""
