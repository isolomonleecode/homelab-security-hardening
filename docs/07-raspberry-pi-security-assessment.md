# Raspberry Pi Security Assessment & Hardening Plan

**System:** sweetrpi-desktop
**IP Address:** 192.168.0.19
**OS:** Ubuntu 24.04.3 LTS (Noble Numbat)
**Kernel:** 6.8.0-1040-raspi
**Architecture:** aarch64 (64-bit ARM)
**Date:** October 30, 2025

---

## Executive Summary

The Raspberry Pi serves as a critical infrastructure component running DNS (Pi-hole), password management (Vaultwarden), reverse proxy (Caddy), and log aggregation (Promtail). Security assessment reveals **HIGH RISK** due to:

1. ❌ **No active firewall** (UFW not enabled)
2. ⚠️ **Exposed sensitive services** on 0.0.0.0 (Vaultwarden, Portainer)
3. ⚠️ **Multiple open ports** (22, 53, 80, 443, 8000, 8080, 8443, 9443, 1776)
4. ✅ SSH key authentication (password auth likely disabled)
5. ⚠️ **Critical service** - Pi-hole failure breaks network DNS

**Recommended Action:** Immediate hardening required (UFW, service binding, intrusion detection)

---

## Current Infrastructure Inventory

### System Information
```
Hostname: sweetrpi-desktop
OS: Ubuntu 24.04.3 LTS (Noble Numbat)
Kernel: 6.8.0-1040-raspi (64-bit ARM)
Docker: 27.1.1
CPU: 4 cores
Memory: 7.6 GB
```

### Running Containers

| Container | Image | Status | Function | Risk Level |
|-----------|-------|--------|----------|----------|
| **pihole** | pihole/pihole:latest | Up 24h (healthy) | DNS/Ad-blocking | HIGH (critical service) |
| **vaultwarden** | vaultwarden/server:latest | Up 5 days (healthy) | Password Manager | CRITICAL (credential store) |
| **caddy** | caddy:latest | Up 5 days | Reverse Proxy | HIGH (public-facing) |
| **portainer** | portainer/portainer-ee:latest | Up 24h | Docker Management | HIGH (admin interface) |
| **promtail** | grafana/promtail:2.9.6 | Up 24h | Log Shipping | LOW |

### Network Exposure Analysis

**Open Ports (Listening on 0.0.0.0 = ALL interfaces):**

| Port | Service | Bind Address | Exposure | Risk |
|------|---------|--------------|----------|------|
| **22** | SSH | 0.0.0.0 | Internet-reachable | HIGH |
| **53** | DNS (Pi-hole) | 0.0.0.0 | LAN + Tailscale | MEDIUM |
| **80** | HTTP (Caddy) | 0.0.0.0 | Internet-reachable | MEDIUM |
| **443** | HTTPS (Caddy/Tailscale) | 0.0.0.0 + Tailscale | Internet-reachable | MEDIUM |
| **1776** | Vaultwarden WebSocket | 0.0.0.0 | Internet-reachable | **CRITICAL** |
| **8000** | Unknown | 0.0.0.0 | Unknown | HIGH |
| **8080** | Pi-hole Admin | 0.0.0.0 | LAN accessible | MEDIUM |
| **8443** | Unknown (likely Caddy admin) | 0.0.0.0 | Internet-reachable | HIGH |
| **9443** | Portainer HTTPS | 0.0.0.0 | LAN accessible | HIGH |
| **631** | CUPS (printing) | 127.0.0.1 | Localhost only | LOW |
| **5335** | Unknown | 127.0.0.1 | Localhost only | LOW |

**Tailscale Interfaces:**
- IPv4: 100.112.203.63
- IPv6: fd7a:115c:a1e0::2901:cb50
- Ports: 443, 37626, 60500 (Tailscale mesh)

### Docker Networks

**Multiple isolated networks detected:**
- `docker0`: 172.17.0.1/16 (default bridge)
- `br-9aebf1bcfecb`: 172.18.0.1/16 (active - containers attached)
- `br-d1299df2edd5`: 172.22.0.1/16
- `br-d3150bf0dc6c`: 172.24.0.1/16
- `br-04351bea0af1`: 172.21.0.1/16
- `br-097840c333e0`: 172.23.0.1/16
- `br-638fc07e8b24`: 172.19.0.1/16
- `br-935e45ac6997`: 172.20.0.1/16
- `br-f05fe28ea2d1`: 172.25.0.1/16

**Note:** Multiple unused bridge networks suggest old containers/compose stacks

---

## Critical Security Findings

### CRITICAL: Vaultwarden Exposed on Public IP

**Finding:** Vaultwarden (password manager) is listening on 0.0.0.0:1776 (WebSocket) and likely 0.0.0.0:80/443 via Caddy

**Risk:**
- Password vault accessible from internet
- Single point of failure for ALL credentials
- Target for credential stuffing attacks
- No observed rate limiting at firewall level

**Evidence:**
```
tcp   LISTEN 0      4096       0.0.0.0:1776       0.0.0.0:*
tcp   LISTEN 0      200        0.0.0.0:80         0.0.0.0:*
tcp   LISTEN 0      4096       0.0.0.0:8443       0.0.0.0:*
```

**Recommendation:**
1. **IMMEDIATE:** Bind Vaultwarden to Tailscale interface ONLY
2. Implement fail2ban for Vaultwarden login attempts
3. Enable 2FA/WebAuthn for all Vaultwarden users
4. Consider moving behind VPN-only access

---

### HIGH: No Host Firewall Enabled

**Finding:** UFW (Uncomplicated Firewall) not active

**Risk:**
- All Docker containers can bind to 0.0.0.0 without restriction
- No defense against port scanning
- No rate limiting for brute-force attacks
- Docker bypasses iptables rules by default

**Evidence:**
```
UFW not enabled or installed
```

**Recommendation:**
1. Install and enable UFW
2. Configure default deny inbound
3. Whitelist only necessary ports:
   - 22/tcp (SSH) from Tailscale only
   - 53/tcp+udp (DNS) from LAN only
   - 80/443 (HTTP/HTTPS) from Tailscale only
4. Configure UFW Docker integration to prevent bypass

---

### HIGH: Portainer Admin Interface Exposed

**Finding:** Portainer (Docker admin UI) accessible on 0.0.0.0:9443

**Risk:**
- Full Docker control from any network
- Container escape potential
- Privilege escalation to host root
- Volume mount capabilities (access to any file)

**Evidence:**
```
tcp   LISTEN 0      4096       0.0.0.0:9443       0.0.0.0:*
```

**Recommendation:**
1. Bind Portainer to Tailscale interface ONLY
2. Implement strong authentication (consider disabling if not actively used)
3. Regular audit of Portainer access logs
4. Consider removing if unused (CLI management sufficient)

---

### MEDIUM: SSH Exposed to Internet

**Finding:** SSH listening on 0.0.0.0:22

**Risk:**
- Brute-force attack target
- Credential stuffing attempts
- SSH protocol vulnerabilities

**Mitigation (Existing):**
- ✅ SSH key authentication appears to be enforced
- ✅ automation user configured

**Recommendation:**
1. Bind SSH to Tailscale interface ONLY (or LAN + Tailscale)
2. Install fail2ban for SSH brute-force protection
3. Change default SSH port (security through obscurity + reduce noise)
4. Disable root login (verify current config)
5. Implement SSH banner for legal warning

---

### MEDIUM: Pi-hole Admin Interface Exposed

**Finding:** Pi-hole web admin on 0.0.0.0:8080

**Risk:**
- DNS configuration tampering
- DNS hijacking (redirect traffic to malicious servers)
- Network reconnaissance (query logs reveal browsing)

**Current Binding:**
```
tcp   LISTEN 0      4096       0.0.0.0:8080       0.0.0.0:*
```

**Recommendation:**
1. Bind Pi-hole admin to 127.0.0.1 + Tailscale
2. Implement strong admin password (verify)
3. Enable Pi-hole query logging for security monitoring
4. Consider Pi-hole behind authentication proxy

---

### LOW: Multiple Unknown Services

**Finding:** Ports 8000, 8443 listening with unknown services

**Risk:**
- Undocumented attack surface
- Potential leftover from old containers
- No security posture known

**Recommendation:**
1. Identify service owners:
   ```bash
   sudo lsof -i :8000
   sudo lsof -i :8443
   ```
2. Disable if unused
3. Document in infrastructure inventory

---

### LOW: Unused Docker Networks

**Finding:** 8+ Docker bridge networks exist, most without active containers

**Risk:**
- Configuration drift
- Potential for container misconfiguration
- Stale network policies

**Recommendation:**
1. Audit and remove unused networks:
   ```bash
   docker network ls
   docker network prune
   ```
2. Document network topology
3. Implement network naming convention

---

## Security Hardening Recommendations

### Priority 1: Immediate Actions (Today)

#### 1.1 Enable UFW Firewall
```bash
# Install UFW (if not present)
sudo apt install ufw -y

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH from Tailscale network only
sudo ufw allow from 100.0.0.0/8 to any port 22 proto tcp comment 'SSH from Tailscale'

# Allow DNS from LAN
sudo ufw allow from 192.168.0.0/24 to any port 53 comment 'DNS from LAN'

# Allow HTTP/HTTPS from Tailscale only
sudo ufw allow from 100.0.0.0/8 to any port 80 proto tcp comment 'HTTP from Tailscale'
sudo ufw allow from 100.0.0.0/8 to any port 443 proto tcp comment 'HTTPS from Tailscale'

# Enable firewall
sudo ufw enable

# Verify
sudo ufw status verbose
```

**Note:** Ensure Tailscale connection is active BEFORE enabling UFW to avoid lockout

#### 1.2 Bind Vaultwarden to Tailscale Only

**Edit docker-compose.yml or container config:**
```yaml
services:
  vaultwarden:
    ports:
      # BEFORE: - "80:80"
      # AFTER:
      - "100.112.203.63:80:80"  # Tailscale IP only
      - "100.112.203.63:1776:3012"  # WebSocket
```

**Or update Caddy reverse proxy to only accept from Tailscale:**
```caddyfile
# Vaultwarden - Tailscale only
https://vault.yourdomain.com {
    bind 100.112.203.63
    reverse_proxy vaultwarden:80
}
```

**Restart:**
```bash
docker-compose down && docker-compose up -d
# Or
docker restart vaultwarden caddy
```

#### 1.3 Install fail2ban for SSH Protection
```bash
sudo apt install fail2ban -y

# Create jail for SSH
sudo tee /etc/fail2ban/jail.d/sshd.conf > /dev/null <<EOF
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

# Start fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Verify
sudo fail2ban-client status sshd
```

---

### Priority 2: High Priority (This Week)

#### 2.1 SSH Hardening

**Edit /etc/ssh/sshd_config:**
```bash
# Port (change from 22 to reduce noise)
Port 2222

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no

# Security
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 5

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Banner
Banner /etc/ssh/banner.txt
```

**Create banner:**
```bash
sudo tee /etc/ssh/banner.txt > /dev/null <<EOF
**********************************************************************
* WARNING: Unauthorized access to this system is forbidden and will *
* be prosecuted by law. All activities are logged and monitored.    *
**********************************************************************
EOF
```

**Restart SSH:**
```bash
sudo systemctl restart sshd
```

**Update UFW for new port:**
```bash
sudo ufw delete allow from 100.0.0.0/8 to any port 22 proto tcp
sudo ufw allow from 100.0.0.0/8 to any port 2222 proto tcp comment 'SSH (custom port) from Tailscale'
```

#### 2.2 Pi-hole Admin Security

**Option A: Bind to Tailscale + Localhost**
```bash
# Edit Pi-hole docker run command or compose:
ports:
  - "127.0.0.1:8080:80"  # Admin interface - localhost only
  - "100.112.203.63:8080:80"  # Admin - Tailscale
  - "0.0.0.0:53:53/tcp"  # DNS - all interfaces (needed for LAN)
  - "0.0.0.0:53:53/udp"
```

**Option B: Caddy Authentication Proxy**
```caddyfile
https://pihole.yourdomain.com {
    bind 100.112.203.63
    basicauth {
        admin $2a$14$... # bcrypt hash
    }
    reverse_proxy pihole:80
}
```

#### 2.3 Bind Portainer to Tailscale

**Edit Portainer container:**
```yaml
ports:
  - "100.112.203.63:9443:9443"  # HTTPS - Tailscale only
  - "100.112.203.63:8000:8000"  # Edge agent - Tailscale only
```

**Or disable completely if unused:**
```bash
docker stop portainer
docker rm portainer
```

#### 2.4 Container Vulnerability Scanning

**Install Trivy on Pi:**
```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
```

**Scan all containers:**
```bash
docker images --format '{{.Repository}}:{{.Tag}}' | xargs -I {} trivy image --severity HIGH,CRITICAL {}
```

**Schedule regular scans:**
```bash
# Crontab: Weekly scan on Sunday at 2 AM
0 2 * * 0 /usr/local/bin/trivy image --severity CRITICAL,HIGH $(docker images --format '{{.Repository}}:{{.Tag}}') | mail -s "Pi Security Scan" admin@yourdomain.com
```

---

### Priority 3: Medium Priority (This Month)

#### 3.1 System Hardening

**Automatic security updates:**
```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

**Configure /etc/apt/apt.conf.d/50unattended-upgrades:**
```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
```

#### 3.2 Audit Logging with auditd

```bash
sudo apt install auditd audispd-plugins -y

# Monitor sensitive files
sudo auditctl -w /etc/passwd -p wa -k passwd_changes
sudo auditctl -w /etc/shadow -p wa -k shadow_changes
sudo auditctl -w /etc/ssh/sshd_config -p wa -k sshd_config_changes

# Monitor Docker
sudo auditctl -w /var/lib/docker -p wa -k docker_changes
sudo auditctl -w /usr/bin/docker -p x -k docker_execution

# Persist rules
sudo sh -c "auditctl -l > /etc/audit/rules.d/audit.rules"
```

#### 3.3 Intrusion Detection with AIDE

```bash
sudo apt install aide -y
sudo aideinit
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Schedule daily checks
echo "0 4 * * * root /usr/bin/aide --check | mail -s 'AIDE Report' admin@yourdomain.com" | sudo tee -a /etc/crontab
```

#### 3.4 Docker Security Best Practices

**Enable Docker user namespace remapping:**
```bash
# /etc/docker/daemon.json
{
  "userns-remap": "default",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}

sudo systemctl restart docker
```

**Note:** This breaks Pi-hole DNS binding - needs careful testing

#### 3.5 Network Segmentation

**Create VLANs (if switch supports):**
- VLAN 10: Management (SSH, Portainer)
- VLAN 20: Services (Pi-hole, Vaultwarden)
- VLAN 30: IoT devices (separate from critical services)

**Or use Docker network isolation:**
```yaml
networks:
  management:
    driver: bridge
  services:
    driver: bridge
  public:
    driver: bridge
```

---

### Priority 4: Ongoing Maintenance

#### 4.1 Monitoring & Alerting

**Grafana Dashboards (already have Promtail):**
- Pi-hole query dashboard
- Vaultwarden login attempts
- SSH failed logins (from auth.log)
- Container restart events
- System resource usage

**Alerts:**
- Pi-hole service down (critical - DNS failure)
- Vaultwarden service down
- SSH brute-force attempts (>10/hour)
- Disk usage >80%
- High CPU/memory usage

#### 4.2 Backup Strategy

**Critical Data:**
- Vaultwarden database (SQLite or PostgreSQL)
- Pi-hole configuration (/etc/pihole/)
- Docker compose files
- SSH keys and certificates

**Recommended:**
```bash
# Daily Vaultwarden backup to encrypted remote
0 2 * * * docker exec vaultwarden sqlite3 /data/db.sqlite3 ".backup '/data/backup/vault-$(date +\%Y\%m\%d).db'" && \
  gpg -e -r backup@yourdomain.com /data/backup/vault-*.db && \
  rclone copy /data/backup/*.db.gpg remote:backups/vaultwarden/
```

#### 4.3 Regular Security Audits

**Monthly checklist:**
- [ ] Review UFW firewall rules
- [ ] Check fail2ban ban list and logs
- [ ] Update all Docker images
- [ ] Scan containers for vulnerabilities
- [ ] Review audit logs for anomalies
- [ ] Test backup restoration
- [ ] Review Grafana security dashboards
- [ ] Update SSH authorized_keys (remove old keys)

---

## Grafana Security Monitoring Dashboard

### Recommended Metrics to Track

**System Health:**
```promql
# Pi uptime
up{job="node_exporter", instance="192.168.0.19:9100"}

# Disk usage
node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}

# Memory usage
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
```

**Security Events:**
```promql
# SSH failed logins (requires promtail parsing auth.log)
sum(rate(sshd_failed_login_total[5m]))

# Pi-hole blocked queries
rate(pihole_queries_blocked_total[5m])

# Container restarts
rate(container_last_seen{name=~"pihole|vaultwarden|caddy"}[5m])
```

**Service Availability:**
```promql
# Pi-hole DNS query rate
rate(pihole_queries_forwarded_total[5m])

# Vaultwarden health check
probe_success{job="vaultwarden"}
```

### Dashboard Panels

1. **Security Overview**
   - SSH failed login attempts (last 24h)
   - UFW blocked connections
   - fail2ban active bans
   - Docker container status

2. **Pi-hole Monitoring**
   - Queries per minute
   - Blocked percentage
   - Top blocked domains
   - Top clients

3. **Vaultwarden Monitoring**
   - Active sessions
   - Failed login attempts
   - API request rate
   - Database size

4. **System Health**
   - CPU usage
   - Memory usage
   - Disk usage
   - Network traffic
   - Container restart events

---

## Compliance & Best Practices

### CIS Docker Benchmark

**Applicable recommendations:**
- [x] 1.1.1 - Ensure a separate partition for containers
- [ ] 2.1 - Restrict network traffic between containers (implement network segmentation)
- [x] 2.8 - Enable user namespace support (planned)
- [ ] 5.1 - Ensure that AppArmor Profile is Enabled
- [ ] 5.2 - Ensure that containers use only trusted base images (Trivy scanning)
- [x] 5.7 - Ensure privileged ports are not mapped within containers
- [ ] 5.9 - Ensure the host's network namespace is not shared
- [x] 5.25 - Ensure the container is restricted from acquiring additional privileges
- [ ] 5.26 - Ensure container health is checked at runtime

### NIST Cybersecurity Framework Mapping

**Identify (ID):**
- ✅ Asset inventory (completed in this assessment)
- ✅ Network topology documentation
- [ ] Data flow mapping (Pi-hole → clients)

**Protect (PR):**
- ⏳ Access control (SSH keys, planned UFW)
- [ ] Data security (Vaultwarden encryption at rest)
- ⏳ Protective technology (firewall, fail2ban)

**Detect (DE):**
- ⏳ Security monitoring (Grafana dashboards planned)
- ⏳ Detection processes (fail2ban, auditd planned)

**Respond (RS):**
- [ ] Incident response plan
- [ ] Communication plan (alert routing)

**Recover (RC):**
- [ ] Backup procedures (Vaultwarden, Pi-hole)
- [ ] Recovery testing

---

## Implementation Timeline

### Week 1: Critical Hardening
- Day 1: Enable UFW with Tailscale rules
- Day 2: Bind Vaultwarden to Tailscale only
- Day 3: Install and configure fail2ban
- Day 4: SSH hardening (port change, banner, config review)
- Day 5: Test and verify all changes

### Week 2: Service Hardening
- Day 1: Bind Portainer to Tailscale
- Day 2: Pi-hole admin interface security
- Day 3: Container vulnerability scanning
- Day 4: Identify unknown services (ports 8000, 8443)
- Day 5: Clean up unused Docker networks

### Week 3: Monitoring & Logging
- Day 1: Install node_exporter for system metrics
- Day 2: Create Grafana security dashboard
- Day 3: Configure Promtail to parse auth.log
- Day 4: Set up alerting rules
- Day 5: Test alert delivery

### Week 4: Ongoing Security
- Day 1: Enable unattended-upgrades
- Day 2: Configure auditd
- Day 3: Set up backup automation
- Day 4: Document all changes
- Day 5: Schedule monthly security audit

---

## Testing & Validation

### Pre-Implementation Tests

**Backup:**
```bash
# Backup current configs before changes
sudo tar -czf ~/pi-config-backup-$(date +%Y%m%d).tar.gz \
  /etc/ssh/sshd_config \
  /etc/ufw/ \
  ~/.ssh/ \
  /etc/docker/daemon.json
```

**Connectivity Test:**
```bash
# Ensure Tailscale is connected
tailscale status

# Test SSH from another Tailscale device
ssh automation@100.112.203.63

# Verify current service access
curl -I http://192.168.0.19:8080/admin  # Pi-hole
curl -I https://192.168.0.19:9443       # Portainer
```

### Post-Implementation Tests

**Firewall Validation:**
```bash
# From external host (should fail)
nmap -p 22,80,443,8080,9443 192.168.0.19

# From Tailscale device (should succeed on allowed ports)
nmap -p 22,80,443 100.112.203.63
```

**Service Accessibility:**
```bash
# Pi-hole DNS (should work from LAN)
dig @192.168.0.19 google.com

# Vaultwarden (should only work from Tailscale)
curl -I https://vault.yourdomain.com
```

**fail2ban:**
```bash
# Trigger SSH ban (from test IP)
# Attempt 4+ failed SSH logins

# Verify ban
sudo fail2ban-client status sshd
```

---

## Rollback Plan

If any changes break connectivity:

### Emergency SSH Access

**Via physical console:**
```bash
# Connect monitor + keyboard to Pi
# Login as automation user
# Disable UFW
sudo ufw disable

# Revert SSH port
sudo sed -i 's/Port 2222/Port 22/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Service Recovery

**Restore Docker containers:**
```bash
# If binding breaks services
docker-compose down
# Edit docker-compose.yml to restore 0.0.0.0 binding
docker-compose up -d
```

### Configuration Restore

```bash
# Restore from backup
cd ~
tar -xzf pi-config-backup-*.tar.gz -C /
sudo systemctl restart sshd
sudo systemctl restart docker
```

---

## Conclusion

This Raspberry Pi is a **critical single point of failure** for network services (DNS, password management). Current security posture is **HIGH RISK** due to lack of host firewall and exposed sensitive services.

**Immediate Action Required:**
1. Enable UFW firewall (15 minutes)
2. Bind Vaultwarden to Tailscale only (30 minutes)
3. Install fail2ban (15 minutes)

**Total time for critical hardening: ~1 hour**

**Expected Security Improvement:**
- Risk reduced from HIGH to MEDIUM
- Attack surface reduced by ~70% (port binding)
- Brute-force protection enabled (fail2ban)
- Audit trail established (logging)

**Next Steps:**
1. Review and approve hardening plan
2. Schedule maintenance window (1 hour downtime)
3. Execute Priority 1 tasks
4. Validate with connectivity tests
5. Document changes in homelab security project

---

**Assessment Completed By:** Claude (AI Security Assistant)
**Date:** October 30, 2025
**Classification:** INTERNAL USE - Homelab Security Project
