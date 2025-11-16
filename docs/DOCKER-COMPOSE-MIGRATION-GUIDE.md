# Docker Compose Migration Guide

**Date**: 2025-11-09
**System**: Raspberry Pi (sweetrpi-desktop)
**Goal**: Migrate standalone containers to docker-compose for easier management

---

## Overview

This guide helps you migrate your standalone containers (currently managed via Portainer) to docker-compose stacks for:

✅ **Version Control** - Store configs in git
✅ **Easy Updates** - `docker compose pull && up -d`
✅ **Reproducibility** - Disaster recovery via docker-compose.yml
✅ **Documentation** - Self-documenting infrastructure
✅ **Rollback** - Git-based version history

---

## Current State

### Containers to Migrate

| Container | Current State | Target Compose File |
|-----------|--------------|---------------------|
| pihole | Standalone | critical-services.yml |
| vaultwarden | Standalone | critical-services.yml |
| caddy | Standalone | critical-services.yml |
| portainer | Standalone | critical-services.yml (optional) |

### Already in Docker Compose

| Stack | Location | Status |
|-------|----------|--------|
| Loki Stack | ~/docker/loki-stack/docker-compose.yml | ✅ Managed |
| Home Assistant | ~/homeassistant/docker-compose.yml | ✅ Managed |
| SAML Lab | ~/docker/saml-lab/docker-compose.yml | ✅ Managed |

---

## Migration Plan

### Phase 1: Preparation (Do First)

**1. Backup Everything**

```bash
# Backup Vaultwarden database
sudo /usr/local/bin/backup-vaultwarden

# Backup Pi-hole configuration
docker exec pihole pihole -a -t > ~/pihole_backup_$(date +%Y%m%d).tar.gz

# Backup Caddy config
sudo cp -r /home/sweetrpi/caddy ~/caddy_backup_$(date +%Y%m%d)
sudo cp -r /opt/caddy/certs ~/caddy_certs_backup_$(date +%Y%m%d)

# Export all container configs
for container in pihole vaultwarden caddy portainer; do
    docker inspect $container > ~/backup_${container}_config.json
done
```

**2. Document Current Settings**

```bash
# Get all current environment variables, ports, volumes
docker inspect pihole --format='{{json .Config}}' | jq '.' > ~/pihole_config.json
docker inspect vaultwarden --format='{{json .Config}}' | jq '.' > ~/vaultwarden_config.json
docker inspect caddy --format='{{json .Config}}' | jq '.' > ~/caddy_config.json
docker inspect portainer --format='{{json .Config}}' | jq '.' > ~/portainer_config.json
```

**3. Test Docker Compose File**

```bash
# Copy critical-services.yml to Pi
scp configs/docker-compose/critical-services.yml automation@100.112.203.63:~/docker/

# Validate syntax
cd ~/docker
docker compose -f critical-services.yml config

# Check for errors - should output valid YAML
```

### Phase 2: Migration (Maintenance Window Required)

**Time Required**: 30-60 minutes
**Downtime**: ~5 minutes per service
**Best Time**: Late night / early morning

**Step 1: Stop Old Containers**

```bash
# IMPORTANT: Do this in order to minimize downtime
# Start with non-critical services first

# Stop Portainer (least critical)
docker stop portainer
docker rm portainer

# Stop Caddy (Nextcloud/Vaultwarden access will be down)
docker stop caddy
docker rm caddy

# Stop Vaultwarden (password vault down - do during low usage)
docker stop vaultwarden
docker rm vaultwarden

# Stop Pi-hole LAST (DNS will be down - make this quick!)
docker stop pihole
docker rm pihole
```

**Step 2: Start via Docker Compose**

```bash
cd ~/docker

# Start all services
docker compose -f critical-services.yml up -d

# Monitor startup
docker compose -f critical-services.yml logs -f
# Press Ctrl+C when all services are healthy
```

**Step 3: Verify Services**

```bash
# Check all containers are running
docker compose -f critical-services.yml ps

# Should show:
# NAME          STATUS        PORTS
# pihole        Up (healthy)  53:53/tcp, 53:53/udp, 80:80/tcp
# vaultwarden   Up (healthy)  Exposed ports
# caddy         Up (healthy)  8080, 8443, 9000
# portainer     Up            9443, 8000

# Test DNS
dig @192.168.0.19 google.com
nslookup pihole.homelab 192.168.0.19

# Test Vaultwarden
curl -I https://sweetrpi-desktop.tailc12764.ts.net:9000

# Test Nextcloud via Caddy
curl -I https://sweetrpi-desktop.tailc12764.ts.net:8443

# Test Pi-hole web UI
curl -I http://pihole.homelab/admin
```

**Step 4: Update Firewall Rules (if needed)**

```bash
# Verify UFW rules still work with new network
sudo ufw status numbered

# Test from another device on LAN
ping 192.168.0.19
dig @192.168.0.19 google.com
```

### Phase 3: Cleanup

```bash
# Remove old volumes (ONLY after confirming new setup works)
# WARNING: This deletes old container data!

# List old volumes
docker volume ls

# Remove if no longer needed (be very careful!)
# docker volume rm <old_volume_name>

# Clean up backup config files (keep for 30 days)
# ls -la ~/backup_*_config.json
```

---

## Post-Migration Updates

### How to Update After Migration

**Update all critical services:**

```bash
cd ~/docker
docker compose -f critical-services.yml pull
docker compose -f critical-services.yml up -d
```

**Update specific service:**

```bash
# Update only Vaultwarden
docker compose -f critical-services.yml pull vaultwarden
docker compose -f critical-services.yml up -d vaultwarden

# View logs
docker compose -f critical-services.yml logs -f vaultwarden
```

**Rollback if update breaks:**

```bash
# Stop services
docker compose -f critical-services.yml down

# Restore old docker-compose.yml from git
git checkout HEAD~1 configs/docker-compose/critical-services.yml

# Restart with old version
docker compose -f critical-services.yml up -d
```

---

## Advantages After Migration

### Before (Portainer Management)
❌ No version control
❌ Manual documentation required
❌ Portainer UI required for updates
❌ Hard to reproduce configuration
❌ No easy rollback
❌ Updates require clicking through UI

### After (Docker Compose)
✅ Git version control
✅ Self-documenting (docker-compose.yml)
✅ CLI updates (`docker compose pull && up -d`)
✅ One-command disaster recovery
✅ Git-based rollback (`git checkout`)
✅ Scriptable and automatable

---

## Integration with Update Scripts

Once migrated, use the existing update scripts:

```bash
# Update compose stacks (now includes critical-services)
sudo /home/automation/scripts/update-compose-stacks.sh

# The script will automatically detect and update:
# - ~/docker/loki-stack/
# - ~/homeassistant/
# - ~/docker/saml-lab/
# - ~/docker/critical-services.yml (add to script)
```

### Update Script Modification

Add to [update-compose-stacks.sh](../scripts/update-compose-stacks.sh):

```bash
COMPOSE_DIRS=(
    "/home/automation/docker/loki-stack"
    "/home/automation/homeassistant"
    "/home/automation/docker/saml-lab"
    "/home/automation/docker"  # Add this for critical-services.yml
)

STACK_NAMES=(
    "loki-stack"
    "homeassistant"
    "saml-lab"
    "critical-services"
)
```

---

## Rollback Plan

If migration fails:

### Emergency Rollback

```bash
# Stop compose stack
cd ~/docker
docker compose -f critical-services.yml down

# Restore from backup configs
# Option A: Recreate via Portainer UI using saved configs
# Option B: Use docker run commands from backup JSON

# Example for Pi-hole:
docker run -d \
  --name pihole \
  # ... (parameters from backup config)

# Restore Vaultwarden database if needed
gunzip /data/vaultwarden-backups/vault_backup_*.sqlite3.gz
docker cp /data/vaultwarden-backups/vault_backup_*.sqlite3 vaultwarden:/data/db.sqlite3
docker restart vaultwarden
```

### Validation Checklist

After migration, verify:

- [ ] DNS resolution working (`dig @192.168.0.19 google.com`)
- [ ] Pi-hole admin accessible (`http://pihole.homelab/admin`)
- [ ] Vaultwarden login works (`https://sweetrpi-desktop.tailc12764.ts.net:9000`)
- [ ] Nextcloud accessible (`https://sweetrpi-desktop.tailc12764.ts.net:8443`)
- [ ] All containers show healthy status
- [ ] No errors in logs (`docker compose logs`)
- [ ] Firewall rules still working
- [ ] Tailscale connectivity intact

---

## Troubleshooting

### Issue: Pi-hole DNS Not Working

**Symptoms**: Cannot resolve domains after migration

**Fix**:
```bash
# Check Pi-hole container
docker compose -f critical-services.yml logs pihole

# Verify DNS port binding
sudo netstat -tulpn | grep :53

# Restart Pi-hole
docker compose -f critical-services.yml restart pihole

# Reload DNS
docker exec pihole pihole reloaddns
```

### Issue: Vaultwarden Not Accessible

**Symptoms**: Cannot login to password vault

**Fix**:
```bash
# Check Caddy is running
docker compose -f critical-services.yml ps caddy

# Check Vaultwarden logs
docker compose -f critical-services.yml logs vaultwarden

# Verify Caddy can reach Vaultwarden
docker exec caddy wget -O- http://vaultwarden:80/alive
```

### Issue: Network Connectivity Problems

**Symptoms**: Containers can't communicate

**Fix**:
```bash
# Check network exists
docker network ls | grep critical

# Inspect network
docker network inspect critical-services_critical_network

# Recreate network if needed
docker compose -f critical-services.yml down
docker network prune
docker compose -f critical-services.yml up -d
```

---

## Next Steps

After successful migration:

1. ✅ **Commit to Git**
   ```bash
   cd /run/media/ssjlox/gamer/homelab-security-hardening
   git add configs/docker-compose/critical-services.yml
   git commit -m "Migrate critical services to docker-compose"
   git push
   ```

2. ✅ **Update Documentation**
   - Update [SERVICE-DIRECTORY.md](SERVICE-DIRECTORY.md) with new compose paths
   - Document compose commands in team wiki

3. ✅ **Set Up Automated Updates**
   - Add critical-services to update script
   - Schedule weekly update checks
   - Configure Grafana alerts for failed updates

4. ✅ **Consider Removing Portainer**
   - If you're comfortable with CLI management
   - Reduces attack surface
   - Saves resources (Portainer uses ~150MB RAM)

---

## Related Documentation

- [Container Update Scripts](../scripts/update-compose-stacks.sh)
- [Vaultwarden Backup](../scripts/backup-vaultwarden.sh)
- [Raspberry Pi Security Assessment](07-raspberry-pi-security-assessment.md)
- [Service Directory](SERVICE-DIRECTORY.md)

---

**Created**: 2025-11-09
**Author**: Claude Code
**Status**: Ready for implementation

🤖 Generated with [Claude Code](https://claude.com/claude-code)
