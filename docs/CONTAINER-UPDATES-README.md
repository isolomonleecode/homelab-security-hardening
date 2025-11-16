# Container Updates - Quick Reference

**System**: Raspberry Pi (sweetrpi-desktop)
**Last Updated**: 2025-11-09

---

## 🚀 Quick Start

### Update Everything (Recommended)

```bash
ssh automation@100.112.203.63
cd ~/scripts
./update-compose-stacks.sh
```

### Update Individual Container

```bash
./update-standalone-containers.sh pihole
./update-standalone-containers.sh vaultwarden
```

### Manual Backup

```bash
sudo /usr/local/bin/backup-vaultwarden
```

---

## 📁 What's Included

### Scripts (All Executable)

| Script | Purpose |
|--------|---------|
| [backup-vaultwarden.sh](scripts/backup-vaultwarden.sh) | Backup password vault database |
| [update-compose-stacks.sh](scripts/update-compose-stacks.sh) | Update all docker-compose stacks |
| [update-standalone-containers.sh](scripts/update-standalone-containers.sh) | Update individual containers |
| [setup-backup-automation.sh](scripts/setup-backup-automation.sh) | Install backup automation |

### Configurations

| File | Purpose |
|------|---------|
| [critical-services.yml](configs/docker-compose/critical-services.yml) | Docker Compose for Pi-hole, Vaultwarden, Caddy |
| [container-updates-monitoring.json](configs/grafana/dashboards/container-updates-monitoring.json) | Grafana monitoring dashboard |
| [vaultwarden-backup.yml](configs/promtail/vaultwarden-backup.yml) | Promtail config for backup logs |

### Documentation

| Guide | Description |
|-------|-------------|
| [CONTAINER-UPDATE-COMPLETE-GUIDE.md](docs/CONTAINER-UPDATE-COMPLETE-GUIDE.md) | **Complete setup & usage guide** |
| [DOCKER-COMPOSE-MIGRATION-GUIDE.md](docs/DOCKER-COMPOSE-MIGRATION-GUIDE.md) | Migrate to docker-compose |
| [07-raspberry-pi-security-assessment.md](docs/07-raspberry-pi-security-assessment.md) | Security baseline |

---

## 📦 Installation

### 1. Deploy Scripts to Raspberry Pi

```bash
# From your local machine
cd /run/media/ssjlox/gamer/homelab-security-hardening

scp scripts/*.sh automation@100.112.203.63:~/scripts/
ssh automation@100.112.203.63 "chmod +x ~/scripts/*.sh"
```

### 2. Set Up Automated Backups

```bash
ssh automation@100.112.203.63
cd ~/scripts
./setup-backup-automation.sh
```

**This configures**:
- ✅ Daily backups at 2 AM
- ✅ 30-day retention
- ✅ Compression
- ✅ Pre-update hooks

### 3. Import Grafana Dashboard

```bash
# Copy dashboard to Pi
scp configs/grafana/dashboards/container-updates-monitoring.json \
    automation@100.112.203.63:/tmp/

# Import via Grafana UI
# http://192.168.0.19:3000 → Dashboards → Import
```

---

## 🎯 Key Features

### ✅ Automated Backups
- **Vaultwarden**: Daily at 2 AM
- **Location**: `/data/vaultwarden-backups/`
- **Retention**: 30 days
- **Compression**: Automatic (saves 80% space)

### ✅ Safe Updates
- Backup before critical service updates
- Health checks after updates
- Easy rollback via git
- Interactive mode for standalone containers

### ✅ Monitoring
- Grafana dashboard for container updates
- Backup success/failure tracking
- Container restart detection
- Image age tracking

### ✅ Docker Compose Ready
- Migrate standalone containers to compose
- Version control via git
- One-command updates
- Self-documenting infrastructure

---

## 🔄 Update Procedures

### Docker Compose Stacks (Easy)

```bash
cd ~/docker/loki-stack
docker compose pull && docker compose up -d
```

**Managed stacks**:
- `~/docker/loki-stack/` - Prometheus, Grafana, Loki
- `~/homeassistant/` - Home Assistant, MQTT, Node-RED
- `~/docker/saml-lab/` - SAML test environment

### Standalone Containers (Use Script)

```bash
cd ~/scripts

# Interactive mode
./update-standalone-containers.sh

# Specific container
./update-standalone-containers.sh vaultwarden
```

**Managed containers**:
- pihole (DNS)
- vaultwarden (Password vault)
- caddy (Reverse proxy)
- portainer (Docker UI)

---

## 🛡️ Safety Features

### Before Updates
- ✅ Automatic Vaultwarden backup
- ✅ Pull latest images
- ✅ Validate docker-compose syntax

### During Updates
- ✅ Health checks
- ✅ Service verification
- ✅ Log monitoring

### After Updates
- ✅ Container status verification
- ✅ Service functionality tests
- ✅ Automatic cleanup of old backups

### Rollback Available
- ✅ Git-based config rollback
- ✅ Database restoration from backup
- ✅ Previous image tags available

---

## 📅 Recommended Schedule

| Frequency | Action | Automated? |
|-----------|--------|------------|
| **Daily** | Vaultwarden backup | ✅ Yes (2 AM) |
| **Weekly** | Update compose stacks | ⏳ Can automate |
| **Monthly** | Update critical services | ❌ Manual |
| **Quarterly** | Major version updates | ❌ Manual |

---

## 🚨 Emergency Procedures

### Restore Vaultwarden from Backup

```bash
docker stop vaultwarden
gunzip /data/vaultwarden-backups/vault_backup_LATEST.sqlite3.gz
docker cp /data/vaultwarden-backups/vault_backup_LATEST.sqlite3 vaultwarden:/data/db.sqlite3
docker start vaultwarden
```

### Rollback Docker Compose Stack

```bash
cd ~/docker/loki-stack
docker compose down
cp docker-compose.yml.backup.YYYYMMDD docker-compose.yml
docker compose up -d
```

### Fix DNS (Pi-hole Down)

```bash
# Quick restart
docker restart pihole

# If that fails, check logs
docker logs pihole --tail 50

# Restore from backup
gunzip ~/pihole_backup_LATEST.tar.gz
docker exec pihole pihole -a restoreconfig pihole_backup_LATEST.tar
```

---

## 📊 Monitoring

### Grafana Dashboard
**URL**: http://192.168.0.19:3000
**Dashboard**: Container Updates & Maintenance

**Panels**:
- Container image age
- CPU usage after updates
- Backup logs
- Error detection
- Restart tracking

### Manual Health Checks

```bash
# All containers running
docker ps

# Test services
dig @192.168.0.19 google.com
curl -I https://sweetrpi-desktop.tailc12764.ts.net:9000
curl -I https://sweetrpi-desktop.tailc12764.ts.net:8443

# Check logs
docker logs pihole --tail 20
docker logs vaultwarden --tail 20
```

---

## ❓ Troubleshooting

### Script Won't Run
```bash
chmod +x ~/scripts/*.sh
```

### Update Fails
```bash
# Check Docker daemon
sudo systemctl status docker

# Check network
ping 8.8.8.8
nslookup index.docker.io

# Check disk space
df -h /
```

### Backup Fails
```bash
# Check Vaultwarden is running
docker ps | grep vaultwarden

# Check permissions
sudo chown automation:automation /data/vaultwarden-backups

# Run manually
sudo /usr/local/bin/backup-vaultwarden
```

---

## 📚 Full Documentation

**For complete details, see**: [docs/CONTAINER-UPDATE-COMPLETE-GUIDE.md](docs/CONTAINER-UPDATE-COMPLETE-GUIDE.md)

**Topics covered**:
- Detailed installation steps
- Update procedures by service
- Rollback procedures
- Best practices
- Complete troubleshooting guide
- Grafana alert configuration
- Docker Compose migration

---

## 🎓 Interview Talking Points

This implementation demonstrates:

### Technical Skills
- **Container orchestration** (Docker, Docker Compose)
- **Backup automation** (SQLite, cron, systemd timers)
- **Infrastructure as Code** (docker-compose.yml in git)
- **Monitoring & observability** (Grafana, Prometheus, Loki)
- **Shell scripting** (Bash automation with error handling)

### Security Best Practices
- **Defense in depth** (backups before changes)
- **Least privilege** (automation user, no root)
- **Disaster recovery** (tested rollback procedures)
- **Audit logging** (backup logs to Loki)
- **Risk management** (prioritize critical services)

### Operational Excellence
- **Automation** (reduce human error)
- **Documentation** (self-service troubleshooting)
- **Monitoring** (proactive issue detection)
- **Change management** (controlled updates)
- **Incident response** (rollback procedures)

---

**Created**: 2025-11-09
**Repository**: https://github.com/isolomonleecode/homelab-security-hardening
**Maintained By**: isolomonlee

🤖 Generated with [Claude Code](https://claude.com/claude-code)
