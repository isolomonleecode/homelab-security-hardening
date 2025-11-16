# macOS Monitoring Setup Guide

## Overview

Deploy Grafana Agent on macOS to ship logs and metrics to your home SOC monitoring stack.

**What will be monitored:**
- ✅ System metrics (CPU, memory, disk, network)
- ✅ System logs (/var/log/system.log)
- ✅ Application logs
- ✅ Homebrew logs

---

## Prerequisites

- macOS device on network (192.168.0.21 or other)
- Administrator access
- Homebrew installed (or willingness to install it)

---

## Installation Steps

### Step 1: Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 2: Install Grafana Agent

```bash
brew install grafana-agent
```

### Step 3: Get Configuration File

**Option A: Copy from homelab repo**
```bash
# From capcorp9000, copy to macOS device
scp /run/media/ssjlox/gamer/homelab-security-hardening/configs/grafana-agent/macos-config.yml user@192.168.0.21:~/grafana-agent-config.yml
```

**Option B: Create manually**
```bash
nano ~/grafana-agent-config.yml
# Paste contents from configs/grafana-agent/macos-config.yml
```

### Step 4: Customize Configuration

Edit the config file to replace placeholders:

```bash
nano ~/grafana-agent-config.yml
```

**Replace all instances of `'macbook'` with your actual hostname:**
```bash
# Find your hostname
hostname

# Use sed to replace (example if hostname is 'johns-macbook')
sed -i '' 's/macbook/johns-macbook/g' ~/grafana-agent-config.yml
```

### Step 5: Move Config to Proper Location

```bash
# Create config directory
sudo mkdir -p /opt/homebrew/etc/grafana-agent

# Move config file
sudo mv ~/grafana-agent-config.yml /opt/homebrew/etc/grafana-agent/config.yml

# Set permissions
sudo chown root:wheel /opt/homebrew/etc/grafana-agent/config.yml
sudo chmod 644 /opt/homebrew/etc/grafana-agent/config.yml
```

### Step 6: Create Required Directories

```bash
# Create data directory
sudo mkdir -p /opt/homebrew/var/lib/grafana-agent

# Create log directory
sudo mkdir -p /opt/homebrew/var/log

# Set permissions
sudo chown -R $(whoami):staff /opt/homebrew/var/lib/grafana-agent
sudo chown -R $(whoami):staff /opt/homebrew/var/log
```

### Step 7: Start Grafana Agent

```bash
# Start the service
brew services start grafana-agent

# Check if it's running
brew services list | grep grafana-agent
```

**Expected output:**
```
grafana-agent started <user> ~/Library/LaunchAgents/homebrew.mxcl.grafana-agent.plist
```

### Step 8: Verify Logs

```bash
# Check agent logs
tail -f /opt/homebrew/var/log/grafana-agent.log

# Or use system log
log show --predicate 'process == "grafana-agent"' --last 1m
```

**Look for:**
- `level=info msg="starting Grafana Agent"`
- `level=info msg="agent ready"`
- No error messages about connection failures

---

## Verification

### Check Logs Reaching Loki

```bash
# From any machine that can reach the Raspberry Pi
ssh automation@100.112.203.63 "curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq"
```

Should see your macOS hostname in the list.

### Check Metrics in Prometheus

```bash
# Check if macOS metrics are being scraped
ssh automation@100.112.203.63 "curl -s 'http://localhost:9090/api/v1/query?query=node_uname_info' | jq '.data.result[] | select(.metric.hostname==\"<YOUR_HOSTNAME>\")'"
```

### View in Grafana

1. Open http://192.168.0.19:3000
2. Go to Explore
3. **For Logs (Loki):**
   ```
   {hostname="<YOUR_HOSTNAME>"}
   ```
4. **For Metrics (Prometheus):**
   ```
   node_cpu_seconds_total{hostname="<YOUR_HOSTNAME>"}
   ```

---

## Troubleshooting

### Agent won't start

**Check logs:**
```bash
brew services list
cat /opt/homebrew/var/log/grafana-agent.log
```

**Common issues:**
1. **Config syntax error:**
   ```bash
   # Test config
   grafana-agent -config.file=/opt/homebrew/etc/grafana-agent/config.yml -config.expand-env -dry-run
   ```

2. **Permission denied on log files:**
   ```bash
   # macOS restricts access to /var/log/system.log
   # Grant Full Disk Access to grafana-agent:
   # System Preferences → Security & Privacy → Privacy → Full Disk Access
   # Add: /opt/homebrew/bin/grafana-agent
   ```

3. **Can't reach Loki/Prometheus:**
   ```bash
   # Test connectivity
   curl -v http://192.168.0.19:3100/ready
   curl -v http://192.168.0.19:9090/-/ready
   ```

### No logs appearing in Loki

**Check agent is reading logs:**
```bash
# Check positions file
cat /opt/homebrew/var/lib/grafana-agent/positions.yaml
```

Should show file paths being tracked.

**Grant Full Disk Access (required for system logs):**
1. System Preferences → Security & Privacy
2. Privacy tab → Full Disk Access
3. Click lock to make changes
4. Click "+" and add `/opt/homebrew/bin/grafana-agent`
5. Restart agent: `brew services restart grafana-agent`

### No metrics appearing

**Check if node_exporter integration is working:**
```bash
# Agent exposes metrics on :12345
curl -s http://localhost:12345/metrics | grep node_
```

Should see node_exporter metrics.

---

## Add to Prometheus (on Raspberry Pi)

Since Grafana Agent uses remote_write, metrics are pushed to Prometheus automatically. But if you want to see the agent in targets:

```bash
ssh automation@100.112.203.63
nano /home/automation/docker/loki-stack/prometheus.yml
```

Add under `scrape_configs`:
```yaml
  - job_name: 'macos-agent'
    static_configs:
      - targets: ['192.168.0.21:12345']  # Change IP to your macOS IP
        labels:
          hostname: 'your-macbook-hostname'
          instance: 'macos-laptop'
```

Reload Prometheus:
```bash
docker exec prometheus kill -HUP 1
```

---

## Stopping/Uninstalling

### Stop Agent
```bash
brew services stop grafana-agent
```

### Uninstall
```bash
brew services stop grafana-agent
brew uninstall grafana-agent
sudo rm -rf /opt/homebrew/etc/grafana-agent
sudo rm -rf /opt/homebrew/var/lib/grafana-agent
```

---

## Security Considerations

### Firewall

Grafana Agent connects **outbound** to Loki/Prometheus, so no firewall rules needed on macOS unless you have a custom firewall blocking outbound connections.

### Full Disk Access

Grafana Agent needs Full Disk Access to read:
- /var/log/system.log
- User Library logs
- Other system logs

This is normal for monitoring agents on macOS.

### Network Security

- Agent pushes data to 192.168.0.19 (Raspberry Pi)
- Traffic stays within LAN
- No external exposure

---

## Interview Talking Points

*"I deployed unified monitoring across heterogeneous infrastructure including macOS. On macOS, I used Grafana Agent which is purpose-built for shipping telemetry to Grafana Cloud or self-hosted stacks.*

*The agent integrates node_exporter for system metrics and ships macOS system logs to Loki. I configured the agent via YAML, granted it Full Disk Access for log collection, and deployed it as a Homebrew service for automatic startup.*

*This demonstrates understanding of OS-specific monitoring requirements - macOS doesn't use systemd like Linux, so I adapted the deployment method while maintaining the same centralized architecture."*

---

## Next Steps

After successful deployment:

1. ✅ Verify hostname appears in Loki
2. ✅ Check metrics in Prometheus
3. ✅ Add macOS to Grafana dashboards
4. ✅ Configure firewall if needed
5. ✅ Set up alerting (optional)

---

## Additional Resources

- Grafana Agent Docs: https://grafana.com/docs/agent/latest/
- macOS Log Collection: https://grafana.com/docs/loki/latest/clients/promtail/scraping/#darwin-logs
- Troubleshooting: https://grafana.com/docs/agent/latest/troubleshooting/
