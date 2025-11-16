# Raspberry Pi Container Update - Complete Guide

**System**: sweetrpi-desktop (192.168.0.19 / 100.112.203.63)
**Date**: 2025-11-09
**Objective**: Safe, automated container updates with backups and rollback

---

## Quick Start

### Update All Compose Stacks (Recommended)

```bash
# Connect to Pi
ssh automation@100.112.203.63

# Update all docker-compose managed stacks
cd ~/docker
./update-compose-stacks.sh

# This updates:
# - Loki monitoring stack (Prometheus, Grafana, Loki)
# - Home Assistant + MQTT + Node-RED
# - SAML lab environment
```

### Update Individual Container

```bash
# Interactive mode (asks for each update)
./update-standalone-containers.sh

# Update specific container
./update-standalone-containers.sh pihole
./update-standalone-containers.sh vaultwarden
```

### Backup Before Updates

```bash
# Manual Vaultwarden backup
sudo /usr/local/bin/backup-vaultwarden

# Backups stored in: /data/vaultwarden-backups
# Retention: 30 days
```

---

## What's Been Set Up

### 1. Update Scripts ✅

Located in: `/home/automation/scripts/`

| Script | Purpose | Usage |
|--------|---------|-------|
| **update-compose-stacks.sh** | Update all docker-compose stacks | `./update-compose-stacks.sh` |
| **update-standalone-containers.sh** | Update individual containers | `./update-standalone-containers.sh [name]` |
| **backup-vaultwarden.sh** | Backup password vault database | `sudo /usr/local/bin/backup-vaultwarden` |
| **setup-backup-automation.sh** | Install backup automation | `./setup-backup-automation.sh` |

### 2. Automated Backups ✅

**Vaultwarden backups run automatically:**
- **Schedule**: Daily at 2:00 AM
- **Method**: Systemd timer + cron
- **Location**: `/data/vaultwarden-backups/`
- **Retention**: 30 days
- **Compression**: Gzip (saves ~80% space)

**Manual backup:**
```bash
sudo /usr/local/bin/backup-vaultwarden
```

**Verify backups:**
```bash
ls -lh /data/vaultwarden-backups/
# Should show: vault_backup_YYYYMMDD_HHMMSS.sqlite3.gz files
```

### 3. Grafana Monitoring Dashboard ✅

**Dashboard**: Container Updates & Maintenance

**Features**:
- ⏰ Container image age tracking
- 📊 CPU usage monitoring (detect update issues)
- 📝 Backup logs viewer
- ⚠️ Error detection for Pi-hole & Vaultwarden
- 🔄 Container restart tracking

**Import Dashboard**:
```bash
# Dashboard JSON available at:
# configs/grafana/dashboards/container-updates-monitoring.json

# Import via Grafana UI:
# 1. Go to http://192.168.0.19:3000
# 2. Dashboards → Import
# 3. Upload container-updates-monitoring.json
# 4. Select Prometheus and Loki datasources
```

### 4. Docker Compose Migration (Optional) ✅

**Available**: [configs/docker-compose/critical-services.yml](../configs/docker-compose/critical-services.yml)

**Migrate standalone containers to compose for**:
- Version control via git
- One-command updates
- Easy rollback
- Self-documenting configs

**See**: [DOCKER-COMPOSE-MIGRATION-GUIDE.md](DOCKER-COMPOSE-MIGRATION-GUIDE.md)

---

## Installation Steps

### Step 1: Deploy Scripts to Raspberry Pi

```bash
# From your local machine
cd /run/media/ssjlox/gamer/homelab-security-hardening

# Copy scripts to Pi
scp scripts/backup-vaultwarden.sh automation@100.112.203.63:~/scripts/
scp scripts/update-compose-stacks.sh automation@100.112.203.63:~/scripts/
scp scripts/update-standalone-containers.sh automation@100.112.203.63:~/scripts/
scp scripts/setup-backup-automation.sh automation@100.112.203.63:~/scripts/

# Make scripts executable
ssh automation@100.112.203.63 "chmod +x ~/scripts/*.sh"
```

### Step 2: Set Up Automated Backups

```bash
# Connect to Pi
ssh automation@100.112.203.63

# Run setup script
cd ~/scripts
./setup-backup-automation.sh

# This will:
# - Create backup directory
# - Install backup script to /usr/local/bin
# - Set up daily cron job (2 AM)
# - Create systemd timer
# - Configure log rotation
# - Run test backup
```

**Verify setup:**
```bash
# Check cron job
crontab -l | grep backup-vaultwarden

# Check systemd timer
sudo systemctl status vaultwarden-backup.timer

# Check backup directory
ls -lh /data/vaultwarden-backups/
```

### Step 3: Test Update Scripts

```bash
# Test compose stack updates (dry run)
cd ~/scripts
./update-compose-stacks.sh loki-stack

# Test standalone container update (check only)
./update-standalone-containers.sh
# Choose 'N' to skip actual updates during testing
```

### Step 4: Import Grafana Dashboard

```bash
# Copy dashboard JSON to Pi
scp configs/grafana/dashboards/container-updates-monitoring.json \
    automation@100.112.203.63:/tmp/

# Import via Grafana UI:
# 1. Open: http://192.168.0.19:3000
# 2. Login: admin / <your_password>
# 3. Left menu → Dashboards → Import
# 4. Upload: /tmp/container-updates-monitoring.json
# 5. Select datasources:
#    - Prometheus: prometheus
#    - Loki: loki
# 6. Click Import
```

### Step 5: Configure Promtail for Backup Logs (Optional)

```bash
# Add backup log scraping to Promtail
scp configs/promtail/vaultwarden-backup.yml \
    automation@100.112.203.63:~/docker/loki-stack/

# Update Loki stack compose to include new config
ssh automation@100.112.203.63

# Edit promtail config
cd ~/docker/loki-stack
# Add to promtail service in docker-compose.yml:
#   volumes:
#     - ./vaultwarden-backup.yml:/etc/promtail/vaultwarden-backup.yml

# Restart Promtail
docker compose restart promtail
```

---

## Update Schedule Recommendations

### Daily (Automated)
- ✅ **Vaultwarden backups** (2:00 AM) - Already configured
- ✅ **System security updates** (via unattended-upgrades)

### Weekly (Semi-Automated)
**Every Sunday at 3:00 AM:**

```bash
# Add to crontab
crontab -e

# Add this line:
0 3 * * 0 /home/automation/scripts/update-compose-stacks.sh >> /var/log/container-updates.log 2>&1
```

This updates:
- Loki stack (Prometheus, Grafana, Loki)
- Home Assistant stack
- SAML lab

### Monthly (Manual)
**First Saturday of each month:**

1. **Review Grafana dashboard** for container health
2. **Update critical services** (Pi-hole, Vaultwarden, Caddy)
3. **Read release notes** for major updates
4. **Test after updates** (DNS, password vault, reverse proxy)

```bash
# Manual critical service updates
ssh automation@100.112.203.63
cd ~/scripts

# Update each service individually with verification
./update-standalone-containers.sh pihole
# Test DNS: dig @192.168.0.19 google.com

./update-standalone-containers.sh vaultwarden
# Test login: https://sweetrpi-desktop.tailc12764.ts.net:9000

./update-standalone-containers.sh caddy
# Test Nextcloud: https://sweetrpi-desktop.tailc12764.ts.net:8443
```

### Quarterly (Planned Maintenance)
- Review Home Assistant breaking changes
- Update Pi-hole to major versions
- Test disaster recovery procedures
- Verify all backups are working

---

## Update Procedures by Service Type

### Docker Compose Stacks (Easy & Safe)

**Loki Monitoring Stack:**
```bash
cd ~/docker/loki-stack
docker compose pull
docker compose up -d
docker compose logs -f
```

**Home Assistant:**
```bash
# Read release notes first!
# https://www.home-assistant.io/latest-release-notes/

cd ~/homeassistant
docker compose pull
docker compose up -d
docker compose logs -f homeassistant
```

**SAML Lab:**
```bash
cd ~/docker/saml-lab
docker compose pull
docker compose up -d
```

### Standalone Containers (Requires Care)

**Pi-hole (DNS - Network Impact):**
```bash
# Backup first
docker exec pihole pihole -a -t > ~/pihole_backup_$(date +%Y%m%d).tar.gz

# Use script or manual
./update-standalone-containers.sh pihole

# OR via Portainer:
# 1. Open: https://100.112.203.63:9443
# 2. Containers → pihole → Duplicate/Edit
# 3. Enable "Re-pull image"
# 4. Deploy

# Test DNS after update
dig @192.168.0.19 google.com
dig @192.168.0.19 pihole.homelab
```

**Vaultwarden (Password Vault - Critical):**
```bash
# Automatic backup runs before update
./update-standalone-containers.sh vaultwarden

# Verify backup ran
ls -lh /data/vaultwarden-backups/

# Test login after update
# https://sweetrpi-desktop.tailc12764.ts.net:9000

# Check logs for errors
docker logs vaultwarden --tail 50
```

**Caddy (Reverse Proxy - External Access):**
```bash
# Update via script
./update-standalone-containers.sh caddy

# Test Nextcloud access
curl -I https://sweetrpi-desktop.tailc12764.ts.net:8443

# Test Vaultwarden access
curl -I https://sweetrpi-desktop.tailc12764.ts.net:9000

# Verify certificates still valid
docker exec caddy caddy list-modules | grep tls
```

---

## Rollback Procedures

### Docker Compose Rollback

```bash
# Stop updated stack
cd ~/docker/loki-stack
docker compose down

# Restore previous docker-compose.yml
cp docker-compose.yml.backup.YYYYMMDD_HHMMSS docker-compose.yml

# Start with old configuration
docker compose up -d
```

### Vaultwarden Database Rollback

```bash
# Stop Vaultwarden
docker stop vaultwarden

# List available backups
ls -lh /data/vaultwarden-backups/

# Decompress backup
gunzip /data/vaultwarden-backups/vault_backup_20251109_020000.sqlite3.gz

# Copy to container
docker cp /data/vaultwarden-backups/vault_backup_20251109_020000.sqlite3 \
    vaultwarden:/data/db.sqlite3

# Start Vaultwarden
docker start vaultwarden

# Verify
docker logs vaultwarden --tail 50
```

### Container Image Rollback

```bash
# Pull specific old version instead of :latest
docker pull pihole/pihole:2024.07.0

# Update container to use specific tag via Portainer
# Or recreate with docker run using old image
```

---

## Monitoring & Alerts

### Grafana Alerts (Recommended Setup)

**Alert: Container Update Available**
```promql
# Alert when container image is >30 days old
(time() - container_last_seen{name=~"pihole|vaultwarden|caddy"}) / 86400 > 30
```

**Alert: Backup Failed**
```logql
{job="vaultwarden-backup"} |~ "(?i)error|failed"
```

**Alert: Container Restart After Update**
```promql
changes(container_last_seen{name=~".*"}[1h]) > 2
```

### Manual Health Checks

**After any update, verify:**

```bash
# All containers running
docker ps

# No errors in logs
docker logs pihole --tail 50
docker logs vaultwarden --tail 50
docker logs caddy --tail 50

# Services accessible
curl -I http://pihole.homelab/admin
curl -I https://sweetrpi-desktop.tailc12764.ts.net:9000
curl -I https://sweetrpi-desktop.tailc12764.ts.net:8443

# DNS resolution working
dig @192.168.0.19 google.com
nslookup pihole.homelab 192.168.0.19
```

---

## Best Practices

### DO ✅

1. **Always backup before updating critical services**
   - Vaultwarden: Automatic via script
   - Pi-hole: `docker exec pihole pihole -a -t`

2. **Read release notes for major updates**
   - Home Assistant: Breaking changes common
   - Pi-hole: Check compatibility with existing blocklists

3. **Update during low-usage times**
   - Early morning (2-4 AM)
   - Minimize impact on family/users

4. **Test one service at a time**
   - Update monitoring stack first (low impact)
   - Then non-critical services
   - Finally critical services (Pi-hole, Vaultwarden)

5. **Monitor after updates**
   - Check Grafana dashboard
   - Watch logs for errors
   - Test service functionality

6. **Keep update logs**
   - Document what was updated
   - Note any issues encountered
   - Track rollbacks

### DON'T ❌

1. **Don't install Watchtower**
   - Automatic updates caused issues on Unraid
   - No control over when updates happen
   - Can break critical services unexpectedly

2. **Don't update all containers at once**
   - Harder to identify which update caused issues
   - Overwhelming to troubleshoot multiple failures

3. **Don't skip backups**
   - Vaultwarden contains all your passwords
   - Pi-hole config has all your custom DNS entries

4. **Don't use 'latest' tag blindly**
   - Consider using specific version tags
   - Test updates in non-production first

5. **Don't forget to verify**
   - Always test services after update
   - Check logs for errors
   - Ensure users can still access services

---

## Troubleshooting

### Issue: Update Script Fails

**Symptoms**: Script exits with errors

**Solutions**:
```bash
# Check Docker daemon is running
sudo systemctl status docker

# Check network connectivity
ping 8.8.8.8
nslookup index.docker.io

# Check disk space
df -h /

# Check script permissions
ls -l ~/scripts/update-*.sh
chmod +x ~/scripts/*.sh
```

### Issue: Container Won't Start After Update

**Symptoms**: Container status is "Exited"

**Solutions**:
```bash
# Check logs
docker logs <container_name>

# Check for port conflicts
sudo netstat -tulpn | grep <port>

# Try manual start
docker start <container_name>

# Rollback to previous image
docker pull <image>:<old_version>
# Recreate container with old image
```

### Issue: Backup Failed

**Symptoms**: No new backup files or error in logs

**Solutions**:
```bash
# Check Vaultwarden is running
docker ps | grep vaultwarden

# Check backup directory permissions
ls -ld /data/vaultwarden-backups/
sudo chown automation:automation /data/vaultwarden-backups

# Run backup manually with verbose output
sudo /usr/local/bin/backup-vaultwarden

# Check backup logs
tail -f /var/log/vaultwarden-backup.log
```

---

## Files Reference

### Scripts Created

```
scripts/
├── backup-vaultwarden.sh              # Automated Vaultwarden backup
├── update-compose-stacks.sh           # Update all docker-compose stacks
├── update-standalone-containers.sh    # Update individual containers
└── setup-backup-automation.sh         # Install backup automation
```

### Configuration Files

```
configs/
├── docker-compose/
│   └── critical-services.yml          # Compose file for Pi-hole, Vaultwarden, Caddy
├── grafana/dashboards/
│   └── container-updates-monitoring.json  # Grafana dashboard
└── promtail/
    └── vaultwarden-backup.yml         # Promtail config for backup logs
```

### Documentation

```
docs/
├── CONTAINER-UPDATE-COMPLETE-GUIDE.md # This file
├── DOCKER-COMPOSE-MIGRATION-GUIDE.md  # Migration to docker-compose
├── 07-raspberry-pi-security-assessment.md  # Security baseline
└── SERVICE-DIRECTORY.md               # Service inventory
```

---

## Summary

### What You Now Have

✅ **Automated Backups**
- Daily Vaultwarden backups at 2 AM
- 30-day retention
- Compression to save space
- Pre-update hooks for critical services

✅ **Update Scripts**
- Safe docker-compose stack updates
- Interactive standalone container updates
- Automatic health checks
- Easy rollback procedures

✅ **Monitoring**
- Grafana dashboard for container updates
- Backup success/failure tracking
- Container restart detection
- Update age tracking

✅ **Documentation**
- Complete update procedures
- Rollback plans
- Troubleshooting guides
- Docker compose migration path

### Recommended Next Steps

1. **Deploy the scripts** (15 minutes)
   ```bash
   ssh automation@100.112.203.63
   cd ~/scripts
   ./setup-backup-automation.sh
   ```

2. **Test the backup** (5 minutes)
   ```bash
   sudo /usr/local/bin/backup-vaultwarden
   ls -lh /data/vaultwarden-backups/
   ```

3. **Import Grafana dashboard** (10 minutes)
   - Upload container-updates-monitoring.json
   - Configure datasources

4. **Test update workflow** (20 minutes)
   ```bash
   # Test on low-risk service first
   cd ~/scripts
   ./update-compose-stacks.sh loki-stack
   ```

5. **Schedule first update** (Next maintenance window)
   - Review Grafana dashboard
   - Update monitoring stack
   - Update non-critical services
   - Document results

---

**Created**: 2025-11-09
**Author**: Claude Code
**Maintained By**: isolomonlee
**Repository**: https://github.com/isolomonleecode/homelab-security-hardening

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
