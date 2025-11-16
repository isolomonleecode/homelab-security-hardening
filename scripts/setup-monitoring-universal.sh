#!/bin/bash
# Universal Monitoring Setup Script
# Works on: Linux, macOS, Windows (via Git Bash/WSL)
# Detects OS and deploys appropriate monitoring stack

set -e

# Configuration
LOKI_SERVER="192.168.0.19:3100"
PROMETHEUS_SERVER="192.168.0.19:9090"
MONITORING_NETWORK="192.168.0.0/24"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Universal Home SOC Monitoring Setup"
echo "=========================================="
echo ""

# ============================================
# Detect Operating System
# ============================================
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
            echo "${GREEN}✓${NC} Detected: Linux ($DISTRO)"
        else
            DISTRO="unknown"
            echo "${YELLOW}⚠${NC} Detected: Linux (unknown distribution)"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        echo "${GREEN}✓${NC} Detected: macOS"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        DISTRO="windows"
        echo "${GREEN}✓${NC} Detected: Windows (Git Bash/Cygwin)"
    else
        echo "${RED}✗${NC} Unsupported OS: $OSTYPE"
        exit 1
    fi
}

# ============================================
# Linux Setup
# ============================================
setup_linux() {
    echo ""
    echo "${BLUE}[Linux Setup]${NC}"
    echo ""

    # Use existing Linux script
    LINUX_SCRIPT="$(dirname "$0")/setup-monitoring-local.sh"

    if [ -f "$LINUX_SCRIPT" ]; then
        echo "${GREEN}✓${NC} Found Linux setup script"
        bash "$LINUX_SCRIPT"
    else
        echo "${RED}✗${NC} Linux setup script not found: $LINUX_SCRIPT"
        echo "Please ensure setup-monitoring-local.sh is in the same directory."
        exit 1
    fi
}

# ============================================
# macOS Setup
# ============================================
setup_macos() {
    echo ""
    echo "${BLUE}[macOS Setup]${NC}"
    echo ""

    HOSTNAME=$(hostname -s)
    CURRENT_USER=$(whoami)

    echo "Configuration:"
    echo "  Hostname: $HOSTNAME"
    echo "  User: $CURRENT_USER"
    echo "  Loki Server: $LOKI_SERVER"
    echo ""

    read -p "Continue with macOS setup? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    # Step 1: Install Homebrew (if not installed)
    echo ""
    echo "[1/5] Checking Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "${YELLOW}⚠${NC} Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        echo "${GREEN}✓${NC} Homebrew installed"
    else
        echo "${GREEN}✓${NC} Homebrew already installed"
        brew --version
    fi

    # Step 2: Install Grafana Alloy
    echo ""
    echo "[2/5] Installing Grafana Alloy..."

    # Try Homebrew first
    echo "  Updating Homebrew..."
    brew update 2>/dev/null || true

    # Check if already installed
    if command -v alloy &> /dev/null; then
        echo "${GREEN}✓${NC} Grafana Alloy already installed"
        alloy --version
    else
        # Direct download (Alloy not yet in Homebrew core)
        echo "  Downloading Grafana Alloy directly from GitHub..."
        ALLOY_VERSION="v1.11.3"
        ARCH=$(uname -m)
        if [ "$ARCH" = "arm64" ]; then
            DOWNLOAD_URL="https://github.com/grafana/alloy/releases/download/${ALLOY_VERSION}/alloy-darwin-arm64.zip"
            echo "  Detected Apple Silicon (M1/M2/M3)"
        else
            DOWNLOAD_URL="https://github.com/grafana/alloy/releases/download/${ALLOY_VERSION}/alloy-darwin-amd64.zip"
            echo "  Detected Intel Mac"
        fi

        # Create temp directory
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

        echo "${GREEN}✓${NC} Grafana Alloy installed via direct download"
        /usr/local/bin/alloy --version
    fi

    # Step 3: Create Configuration Directory
    echo ""
    echo "[3/5] Creating configuration..."

    sudo mkdir -p /usr/local/etc/alloy
    sudo mkdir -p /usr/local/var/lib/alloy

    # Create config file (River configuration language)
    sudo tee /usr/local/etc/alloy/config.alloy > /dev/null <<'EOF'
// Grafana Alloy Configuration for macOS

logging {
  level  = "info"
  format = "logfmt"
}

// Unix system metrics
prometheus.exporter.unix "macos_system" {
  set_collectors = ["darwin"]
  enable_collectors = ["cpu", "diskstats", "filesystem", "loadavg", "meminfo", "netdev", "time"]
}

prometheus.scrape "macos_metrics" {
  targets        = prometheus.exporter.unix.macos_system.targets
  forward_to     = [prometheus.remote_write.default.receiver]
  scrape_interval = "15s"
  clustering {
    enabled = false
  }
}

prometheus.remote_write "default" {
  endpoint {
    url = "http://PROMETHEUS_SERVER/api/v1/write"
    queue_config { max_samples_per_send = 1000 }
  }
  external_labels = {
    hostname = "HOSTNAME_PLACEHOLDER",
    job      = "macos-node-exporter",
    instance = "HOSTNAME_PLACEHOLDER",
  }
}

// Log collection
local.file_match "system_logs" {
  path_targets = [{
    __address__ = "localhost",
    __path__    = "/var/log/system.log",
    job         = "macos-system",
    hostname    = "HOSTNAME_PLACEHOLDER",
  }]
}

local.file_match "install_logs" {
  path_targets = [{
    __address__ = "localhost",
    __path__    = "/var/log/install.log",
    job         = "macos-install",
    hostname    = "HOSTNAME_PLACEHOLDER",
  }]
}

loki.source.file "system" {
  targets    = local.file_match.system_logs.targets
  forward_to = [loki.write.default.receiver]
}

loki.source.file "install" {
  targets    = local.file_match.install_logs.targets
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://LOKI_SERVER/loki/api/v1/push"
  }
  external_labels = {
    hostname = "HOSTNAME_PLACEHOLDER",
  }
}
EOF

    # Replace placeholders
    sudo sed -i '' "s|PROMETHEUS_SERVER|${PROMETHEUS_SERVER}|g" /usr/local/etc/alloy/config.alloy
    sudo sed -i '' "s|LOKI_SERVER|${LOKI_SERVER}|g" /usr/local/etc/alloy/config.alloy
    sudo sed -i '' "s|HOSTNAME_PLACEHOLDER|${HOSTNAME}|g" /usr/local/etc/alloy/config.alloy

    echo "${GREEN}✓${NC} Configuration created"

    # Step 4: Start Grafana Alloy Service
    echo ""
    echo "[4/5] Starting Grafana Alloy service..."

    # Create launchd service
    echo "  Creating launchd service..."

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

    # Unload old service if exists
    sudo launchctl unload /Library/LaunchDaemons/com.grafana.alloy.plist 2>/dev/null || true

    # Load new service
    sudo launchctl load /Library/LaunchDaemons/com.grafana.alloy.plist
    sleep 3

    if pgrep -f "alloy run" > /dev/null; then
        echo "${GREEN}✓${NC} Grafana Alloy service started"
    else
        echo "${YELLOW}⚠${NC} Service may not have started. Check logs: tail -f /var/log/alloy-error.log"
    fi

    # Step 5: Verify
    echo ""
    echo "[5/5] Verifying installation..."
    echo ""

    echo "Process Status:"
    if pgrep -lf "alloy run"; then
        echo "${GREEN}✓${NC} Alloy process running"
    else
        echo "${RED}✗${NC} Process not running"
    fi
    echo ""

    echo "Testing metrics endpoint..."
    sleep 2
    if curl -s http://localhost:12345/metrics | head -1 | grep -q "HELP"; then
        echo "${GREEN}✓${NC} Metrics endpoint responding"
    else
        echo "${YELLOW}⚠${NC} Metrics endpoint may not be ready yet (wait 30 seconds)"
    fi
    echo ""

    echo "Testing Alloy UI..."
    if curl -s http://localhost:12345 | grep -q "Grafana Alloy"; then
        echo "${GREEN}✓${NC} Alloy UI available at http://localhost:12345"
    else
        echo "${YELLOW}⚠${NC} UI may not be ready yet"
    fi
    echo ""

    echo "=========================================="
    echo "${GREEN}macOS Setup Complete!${NC}"
    echo "=========================================="
    echo ""
    echo "Grafana Alloy is now:"
    echo "  • Collecting system metrics via prometheus.exporter.unix"
    echo "  • Shipping logs to Loki at ${LOKI_SERVER}"
    echo "  • Sending metrics to Prometheus at ${PROMETHEUS_SERVER}"
    echo ""
    echo "Files:"
    echo "  Binary: /usr/local/bin/alloy"
    echo "  Config: /usr/local/etc/alloy/config.alloy"
    echo "  Logs: /var/log/alloy.log"
    echo "  UI: http://localhost:12345"
    echo ""
    echo "Manage service:"
    echo "  Stop: sudo launchctl unload /Library/LaunchDaemons/com.grafana.alloy.plist"
    echo "  Start: sudo launchctl load /Library/LaunchDaemons/com.grafana.alloy.plist"
    echo "  Logs: tail -f /var/log/alloy.log"
    echo ""
    echo "Next Steps:"
    echo "1. Verify metrics: curl http://localhost:12345/metrics | grep node_"
    echo "2. Check Alloy UI for components: open http://localhost:12345"
    echo "3. Verify logs in Grafana: {hostname=\"${HOSTNAME}\"}"
    echo ""
    echo "Note: Grafana Alloy has REPLACED deprecated Grafana Agent"
    echo ""
}

# ============================================
# Windows Setup (via PowerShell)
# ============================================
setup_windows() {
    echo ""
    echo "${BLUE}[Windows Setup]${NC}"
    echo ""

    echo "${YELLOW}Windows setup requires PowerShell with Administrator privileges.${NC}"
    echo ""
    echo "Please run the following PowerShell script:"
    echo ""
    echo "${BLUE}  scripts/setup-monitoring-windows.ps1${NC}"
    echo ""
    echo "Or copy the commands from:"
    echo "  docs/WINDOWS-MONITORING-SETUP.md"
    echo ""
    echo "This bash script cannot directly install Windows services."
    echo "The PowerShell script will handle:"
    echo "  • Downloading Grafana Agent"
    echo "  • Installing as Windows Service"
    echo "  • Configuring Event Log collection"
    echo "  • Starting the agent"
    echo ""

    read -p "Press Enter to view the PowerShell script path..."

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PS_SCRIPT="$SCRIPT_DIR/setup-monitoring-windows.ps1"

    if [ -f "$PS_SCRIPT" ]; then
        echo ""
        echo "PowerShell script location:"
        echo "  $PS_SCRIPT"
        echo ""
        echo "Run with:"
        echo "  powershell -ExecutionPolicy Bypass -File \"$PS_SCRIPT\""
    else
        echo ""
        echo "${YELLOW}PowerShell script not found.${NC}"
        echo "Please see: docs/WINDOWS-MONITORING-SETUP.md"
    fi
    echo ""
}

# ============================================
# Main Execution
# ============================================

detect_os

case "$OS" in
    linux)
        setup_linux
        ;;
    macos)
        setup_macos
        ;;
    windows)
        setup_windows
        ;;
    *)
        echo "${RED}✗${NC} Unsupported OS"
        exit 1
        ;;
esac

exit 0
