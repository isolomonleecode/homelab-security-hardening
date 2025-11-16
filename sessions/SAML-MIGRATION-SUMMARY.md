# SAML Lab Migration - PC to Raspberry Pi

**Date:** 2025-11-01
**Session:** 7
**Objective:** Centralize SAML security training infrastructure on Raspberry Pi

---

## Migration Summary

### ✅ Successfully Migrated

**Raspberry Pi (192.168.0.19):**
- ✅ **Keycloak (IdP)** - Running on port 8180
- ✅ **NextCloud (SP)** - Running on port 8082
- ✅ **MariaDB** - Running internally (port 3306)

**PC:**
- ✅ All SAML containers shut down
- ✅ Freed ~1.4GB RAM

### ⚠️  Architecture Compatibility Issue

**SimpleSAMLphp:**
- Image: `venatorfox/simplesamlphp`
- Architecture: AMD64 only
- Pi Architecture: ARM64
- Error: `exec /init: exec format error`
- Status: Removed from Pi deployment

---

## Current Infrastructure

### Raspberry Pi Services

```bash
NAMES               STATUS
saml-idp-keycloak   Up 20 minutes (port 8180)
saml-sp-nextcloud   Up 20 minutes (port 8082)
saml-nextcloud-db   Up 20 minutes (internal)
```

**Location:** `/home/automation/docker/saml-lab/`

**Networks:**
- `saml` - Internal SAML service communication
- `loki-stack_loki` - Integration with monitoring stack

**Resource Usage:**
- Keycloak: ~800MB RAM (dev mode, optimized for Pi)
- NextCloud: ~120MB RAM
- MariaDB: ~100MB RAM
- **Total: ~1.0GB**

**Pi Resources:**
- RAM: 7.6GB total, 6.3GB was free before migration
- After migration: ~5.3GB free (70% available)
- CPU Load: 0.73 average (low)
- Disk: 198GB free

---

## Access Information

### From Local Network (192.168.0.0/24)

| Service | URL | Credentials |
|---------|-----|-------------|
| **Keycloak Admin** | http://192.168.0.19:8180 | admin / admin123 |
| **NextCloud** | http://192.168.0.19:8082 | (configure in Week 4) |

### From Tailscale VPN

Replace `192.168.0.19` with Pi's Tailscale IP (`100.x.x.x`)

### Firewall Status

**Current:** UFW allows LAN access to ports 3000 (Grafana) and 80 (Pi-hole)

**Needed for SAML:**
```bash
# Option 1: Allow SAML from LAN
sudo ufw allow from 192.168.0.0/24 to any port 8180 comment 'Keycloak from LAN'
sudo ufw allow from 192.168.0.0/24 to any port 8082 comment 'NextCloud from LAN'

# Option 2: Tailscale only (more secure)
sudo ufw allow from 100.0.0.0/8 to any port 8180 comment 'Keycloak Tailscale only'
sudo ufw allow from 100.0.0.0/8 to any port 8082 comment 'NextCloud Tailscale only'
```

---

## SimpleSAMLphp Solution

### Recommended Approach (Week 1-2)

**Hybrid Deployment:**
- **Keycloak IdP:** Raspberry Pi (port 8180)
- **SimpleSAMLphp SP:** Keep on PC (port 8081)
- **Test SAML flow:** PC → Pi Keycloak → PC SimpleSAMLphp

**Why This Works:**
1. SAML is designed for cross-network authentication
2. Real-world scenario (IdP and SP on different systems)
3. No need to build ARM images immediately
4. Focus on learning SAML, not DevOps

**Configuration:**
- PC SimpleSAMLphp connects to: `http://192.168.0.19:8180`
- Keycloak redirects back to: `http://<PC_IP>:8081`

### Alternative: Build ARM SimpleSAMLphp (Week 3-4)

**If full Pi deployment is needed:**

```bash
# Create Dockerfile
FROM php:8.2-apache-bullseye

RUN apt-get update && apt-get install -y \
    git \
    libxml2-dev \
    libssl-dev \
    && docker-php-ext-install xml

RUN cd /var && \
    git clone https://github.com/simplesamlphp/simplesamlphp.git && \
    cd simplesamlphp && \
    composer install

# Configure Apache and SimpleSAMLphp...
```

**Build and deploy:**
```bash
docker build -t simplesamlphp:arm64 .
# Update docker-compose.yml to use local image
```

---

## Week 1 Learning Path (Updated)

### Day 1: Keycloak Configuration

**Access Keycloak:**
```
http://192.168.0.19:8180
Login: admin / admin123
```

**Tasks:**
1. Create realm: `homelab`
2. Create users: alice (role=user), bob (role=admin)
3. Configure SAML client for SimpleSAMLphp
4. Set up attribute mappers (username, email, role)
5. Download IdP metadata

**Follow guide:** `/run/media/ssjlox/gamer/homelab-security-hardening/sessions/SESSION-7-SAML-SECURITY-TRAINING.md`

### Day 2: SimpleSAMLphp Configuration

**Decision point:**
- **Option A:** Configure SimpleSAMLphp on PC (recommended)
- **Option B:** Build ARM image for Pi (advanced)

---

## Docker Compose Configuration

**File:** `/home/automation/docker/saml-lab/docker-compose.yml`

```yaml
networks:
  saml:
    driver: bridge
  loki:
    external: true
    name: loki-stack_loki

services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: saml-idp-keycloak
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin123
      KC_HTTP_ENABLED: "true"
      KC_HOSTNAME_STRICT: "false"
      KC_HOSTNAME_STRICT_HTTPS: "false"
      KC_PROXY: edge
    command: start-dev
    ports:
      - "8180:8080"
    networks:
      - saml
      - loki
    restart: unless-stopped

  nextcloud:
    image: nextcloud:latest
    container_name: saml-sp-nextcloud
    environment:
      MYSQL_HOST: nextcloud-db
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: nextcloud_secure_pass
    ports:
      - "8082:80"
    networks:
      - saml
      - loki
    depends_on:
      - nextcloud-db
    restart: unless-stopped

  nextcloud-db:
    image: mariadb:10.6
    container_name: saml-nextcloud-db
    environment:
      MYSQL_ROOT_PASSWORD: root_secure_pass
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: nextcloud_secure_pass
    networks:
      - saml
    restart: unless-stopped
    volumes:
      - nextcloud-db-data:/var/lib/mysql

volumes:
  nextcloud-db-data:
```

---

## Management Commands

### On Raspberry Pi

```bash
# SSH to Pi
ssh automation@192.168.0.19

# Navigate to SAML lab
cd /home/automation/docker/saml-lab

# View status
docker ps --filter 'name=saml'

# View logs
docker compose logs -f keycloak
docker compose logs -f nextcloud

# Restart service
docker compose restart keycloak

# Stop all
docker compose down

# Start all
docker compose up -d
```

### Monitor Resources

```bash
# Check Pi resources
ssh automation@192.168.0.19 "free -h && echo && docker stats --no-stream"
```

---

## Benefits of Pi Deployment

✅ **Centralized Infrastructure**
- All authentication services on one system
- Pi as dedicated security lab platform
- PC freed for endpoint testing

✅ **Resource Optimization**
- Pi has abundant capacity (70% RAM free after migration)
- PC RAM freed for other tasks
- Efficient use of homelab resources

✅ **Production-Like Setup**
- IdP on dedicated server (realistic architecture)
- Network-based authentication (not localhost)
- Multi-system SAML flow (real-world scenario)

✅ **Monitoring Integration**
- SAML services connected to loki network
- Can add Promtail for log shipping later
- View SAML logs in existing Grafana

✅ **Remote Access**
- Access lab from any device via Tailscale
- Continue learning from laptop/phone
- Lab available 24/7

---

## Next Steps

### Immediate (Week 1 Day 1)

1. **Configure Keycloak realm**
   - Access: http://192.168.0.19:8180
   - Follow SESSION-7 guide Task 1-7

2. **Decide on SimpleSAMLphp approach**
   - Recommended: Use PC for Week 1-2
   - Advanced: Build ARM image

3. **Add UFW rules** (if accessing from LAN)
   ```bash
   ssh automation@192.168.0.19
   sudo ufw allow from 192.168.0.0/24 to any port 8180 comment 'Keycloak from LAN'
   ```

### Future (Week 3-4)

4. **Build ARM SimpleSAMLphp** (optional)
5. **Configure NextCloud SAML** (Week 4)
6. **Add Promtail logging** for SAML services
7. **Create Grafana SAML dashboard**

---

## Troubleshooting

### Keycloak not accessible

**Check container status:**
```bash
ssh automation@192.168.0.19 "docker ps | grep keycloak"
```

**View logs:**
```bash
ssh automation@192.168.0.19 "docker logs saml-idp-keycloak | tail -50"
```

**Keycloak takes 30-60 seconds to fully start** - wait and retry

### Connection refused from PC

**Check firewall:**
```bash
ssh automation@192.168.0.19 "sudo ufw status | grep 8180"
```

**Test connectivity:**
```bash
curl -I http://192.168.0.19:8180
# Should return HTTP 302 (redirect)
```

### Out of memory on Pi

**Check current usage:**
```bash
ssh automation@192.168.0.19 "free -h"
```

**If needed, restart Keycloak (dev mode uses less RAM):**
```bash
ssh automation@192.168.0.19 "cd /home/automation/docker/saml-lab && docker compose restart keycloak"
```

---

## Summary

✅ **Migration successful**
- Keycloak, NextCloud, MariaDB running on Pi
- PC SAML lab shut down
- ~1GB RAM used on Pi (plenty available)

⚠️  **SimpleSAMLphp ARM compatibility**
- Recommend hybrid approach (Keycloak on Pi, SimpleSAMLphp on PC)
- Alternative: Build ARM image (advanced)

✅ **Ready for Week 1 training**
- Access Keycloak at http://192.168.0.19:8180
- Follow SESSION-7 guide for configuration
- Start learning SAML security!

---

**For detailed training guide, see:**
`/run/media/ssjlox/gamer/homelab-security-hardening/sessions/SESSION-7-SAML-SECURITY-TRAINING.md`

**For Pi deployment details, see:**
`/home/automation/docker/saml-lab/README.md` (on Pi)
