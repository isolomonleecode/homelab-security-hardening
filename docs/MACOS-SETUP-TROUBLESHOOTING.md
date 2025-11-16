# macOS Setup Troubleshooting

**Common issues and solutions for macOS monitoring setup**

---

## Error: "No available formula with the name 'formula.jws.json'"

### What This Means

This error occurs when Homebrew can't find the Grafana Agent formula. This can happen if:
1. Homebrew's formula database is out of date
2. The Grafana tap isn't properly configured
3. There's a network issue downloading formulas

### Solution 1: Use the Updated Universal Script

The universal script has been updated with better error handling and a fallback to direct download.

```bash
# Pull the latest script
cd homelab-security-hardening
git pull  # or re-download

# Run the updated script
./scripts/setup-monitoring-universal.sh
```

**The updated script now**:
- ✅ Updates Homebrew first (`brew update`)
- ✅ Tries Homebrew installation
- ✅ Falls back to direct download if Homebrew fails
- ✅ Creates launchd service for manual installs

### Solution 2: Use the Direct Installation Script (Recommended)

**This completely bypasses Homebrew** and installs Grafana Agent directly:

```bash
cd homelab-security-hardening

# Run the direct installation script
./scripts/setup-monitoring-macos-direct.sh
```

**What it does**:
1. Downloads Grafana Agent binary directly from GitHub
2. Installs to `/usr/local/bin/grafana-agent`
3. Creates configuration in `/usr/local/etc/grafana-agent/`
4. Sets up launchd service (no Homebrew needed)
5. Starts the service automatically

**Advantages**:
- ✅ No Homebrew required
- ✅ Works on all macOS versions
- ✅ Simpler installation process
- ✅ Easier to troubleshoot

### Solution 3: Manual Homebrew Fix

If you want to use Homebrew, try these steps:

```bash
# Update Homebrew
brew update

# Try installing grafana-agent
brew install grafana-agent

# If that fails, check available formulas
brew search grafana

# You should see:
# grafana ✓
# grafana-agent ✓
# grafana-alloy
```

**If grafana-agent is missing**:
```bash
# Tap the Grafana repository explicitly
brew tap grafana/grafana

# Then install
brew install grafana/grafana/grafana-agent
```

---

## Other Common Issues

### Issue: Permission Denied

**Error**: `Permission denied` when creating directories or files

**Solution**:
```bash
# The script needs sudo for system-level installation
# Make sure you enter your password when prompted

# If still failing, manually create directories with sudo:
sudo mkdir -p /usr/local/bin
sudo mkdir -p /usr/local/etc/grafana-agent
sudo mkdir -p /usr/local/var/lib/grafana-agent
```

### Issue: Service Won't Start

**Symptoms**: Installation completes but service doesn't start

**Check logs**:
```bash
# If using Homebrew
brew services log grafana-agent

# If using launchd (direct install)
tail -f /var/log/grafana-agent.log
tail -f /var/log/grafana-agent-error.log
```

**Common causes**:
1. **Config file error**: Check `/usr/local/etc/grafana-agent/config.yml` or `/opt/homebrew/etc/grafana-agent/config.yml`
2. **Permissions**: Ensure agent has read access to log files
3. **Network**: Check if 192.168.0.19 is reachable

**Fix permissions**:
```bash
# For Homebrew install
sudo chown -R $(whoami) /opt/homebrew/etc/grafana-agent
sudo chown -R $(whoami) /opt/homebrew/var/lib/grafana-agent

# For direct install
sudo chmod 755 /usr/local/bin/grafana-agent
sudo chmod 644 /usr/local/etc/grafana-agent/config.yml
```

### Issue: Full Disk Access Required

**Error**: Can't read system logs

**Solution**:
1. Open **System Preferences** → **Security & Privacy**
2. Click **Privacy** tab
3. Select **Full Disk Access**
4. Click the lock to make changes
5. Add Grafana Agent:
   - Homebrew: `/opt/homebrew/bin/grafana-agent`
   - Direct: `/usr/local/bin/grafana-agent`

### Issue: Metrics Endpoint Not Responding

**Error**: `curl http://localhost:12345/metrics` fails

**Troubleshooting**:
```bash
# Check if process is running
ps aux | grep grafana-agent

# If running, wait 30 seconds for startup
sleep 30
curl http://localhost:12345/metrics | head

# Check what's listening on port 12345
lsof -i :12345

# If nothing, check config file for correct port
grep -A 5 "server:" /usr/local/etc/grafana-agent/config.yml
```

### Issue: Logs Not Appearing in Grafana

**Symptoms**: Metrics work but logs don't show up

**Check connectivity**:
```bash
# Test if Loki is reachable
curl http://192.168.0.19:3100/ready

# Should return: ready

# Check agent is trying to send logs
tail -100 /var/log/grafana-agent.log | grep -i loki
```

**Check firewall**:
```bash
# macOS firewall may block outbound connections
# System Preferences → Security & Privacy → Firewall
# Click "Firewall Options"
# Ensure "Block all incoming connections" is OFF
# Or add Grafana Agent to allowed apps
```

---

## Verification Steps

After fixing issues, verify everything works:

### 1. Check Process
```bash
# Should show grafana-agent process
ps aux | grep grafana-agent
```

### 2. Check Metrics
```bash
# Should return Prometheus metrics
curl http://localhost:12345/metrics | head -20
```

### 3. Check Logs in Grafana
```bash
# From Raspberry Pi
ssh automation@100.112.203.63

# Check if hostname appears
curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq

# Should include your macOS hostname
```

### 4. Query Logs
Open Grafana: http://192.168.0.19:3000
- Go to **Explore**
- Select **Loki** data source
- Query: `{hostname="YOUR-MAC-HOSTNAME"}`
- Should see logs appearing

---

## Complete Reinstallation

If nothing works, completely remove and reinstall:

### Remove Homebrew Installation
```bash
# Stop service
brew services stop grafana-agent

# Uninstall
brew uninstall grafana-agent

# Remove config
rm -rf /opt/homebrew/etc/grafana-agent
rm -rf /opt/homebrew/var/lib/grafana-agent
```

### Remove Direct Installation
```bash
# Stop service
sudo launchctl unload /Library/LaunchDaemons/com.grafana.agent.plist

# Remove files
sudo rm /usr/local/bin/grafana-agent
sudo rm /Library/LaunchDaemons/com.grafana.agent.plist
sudo rm -rf /usr/local/etc/grafana-agent
sudo rm -rf /usr/local/var/lib/grafana-agent
sudo rm /var/log/grafana-agent*.log
```

### Reinstall Using Direct Method
```bash
cd homelab-security-hardening
./scripts/setup-monitoring-macos-direct.sh
```

---

## Getting Help

### Check Script Logs
The script should show what went wrong during installation. Look for:
- `✗` marks (failures)
- `⚠` marks (warnings)
- Error messages in red

### Manual Test
Try running Grafana Agent manually to see errors:
```bash
# Homebrew
/opt/homebrew/bin/grafana-agent \
  -config.file=/opt/homebrew/etc/grafana-agent/config.yml

# Direct install
/usr/local/bin/grafana-agent \
  -config.file=/usr/local/etc/grafana-agent/config.yml

# Press Ctrl+C to stop
# Look for any error messages
```

### Useful Commands
```bash
# Service status (Homebrew)
brew services list

# Service status (launchd)
launchctl list | grep grafana

# Recent logs
tail -50 /var/log/grafana-agent.log

# Test config file
/usr/local/bin/grafana-agent \
  -config.file=/usr/local/etc/grafana-agent/config.yml \
  -config.file.type=yaml \
  -dry-run
```

---

## Recommended Approach

**For simplest setup**, use the direct installation method:

```bash
# 1. Use the direct install script (no Homebrew needed)
./scripts/setup-monitoring-macos-direct.sh

# 2. Verify it's working
ps aux | grep grafana-agent
curl http://localhost:12345/metrics | head

# 3. Add to Prometheus config on Raspberry Pi
# (See UNIVERSAL-SETUP-GUIDE.md for details)
```

**This avoids Homebrew issues entirely** and gives you full control over the installation.

---

## Summary

**If you got the formula.jws.json error**:

✅ **Best solution**: Use `./scripts/setup-monitoring-macos-direct.sh`
- No Homebrew needed
- Direct binary download
- Works every time

✅ **Alternative**: Re-run updated universal script
- Now has fallback to direct download
- Better error handling

❌ **Don't manually fix Homebrew** unless you really want to use it
- More complex
- More things that can go wrong
- Direct install is simpler

---

**Created**: 2025-11-06
**Related Scripts**:
- `scripts/setup-monitoring-macos-direct.sh` (Recommended)
- `scripts/setup-monitoring-universal.sh` (Updated with fallback)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
