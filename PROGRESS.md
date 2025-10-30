# Project Progress Log

## Session 1: October 23, 2025

### Completed Tasks

#### Phase 1: Infrastructure Inventory ✅
- **Created repository structure** for security portfolio project
- **Documented all services** running in homelab (18 active containers, 8 stopped)
- **Mapped network architecture** including Docker bridges, Tailscale VPN, and local networks
- **Identified security priorities:**
  - Critical: Exposed database ports, Cloudflare tunnel audit
  - High: Network segmentation, vulnerability scanning
  - Medium: Centralized logging, intrusion detection

**Key Findings:**
- PostgreSQL (5432) and MariaDB (3306) exposed on 0.0.0.0
- Cloudflare tunnel providing public access
- All containers on shared Docker network (lateral movement risk)
- Pi-hole DNS misconfiguration

#### Phase 2: Pi-hole DNS Configuration ✅
- **Fixed Pi-hole DNS** for local domain resolution
- **Created 14 DNS records** for `.homelab` domain
- **Configured dnsmasq** with custom configuration file
- **Enabled `etc_dnsmasq_d`** in Pi-hole configuration

**Technical Details:**
- File: `/etc/dnsmasq.d/04-local-dns.conf`
- Format: `address=/service.homelab/192.168.0.51`
- Configuration persisted in Pi-hole container
- All services now accessible via friendly names

**Services Configured:**
```
http://jellyfin.homelab:8096
http://radarr.homelab:7878
http://sonarr.homelab:8989
http://homarr.homelab:10005
http://pihole.homelab/admin
... and 9 more services
```

### Skills Demonstrated

**Security+ Concepts Applied:**
- Asset inventory and management (Domain 5)
- Network architecture documentation (Domain 2)
- Attack surface analysis (Domain 2)
- Risk assessment and prioritization (Domain 5)

**Network+ Concepts Applied:**
- DNS configuration and troubleshooting (Domain 3, 5)
- Network topology mapping (Domain 1, 2)
- OSI model practical application (Layer 7 - DNS)
- Docker networking and bridges (Domain 2)

**Technical Skills:**
- Linux system administration via SSH
- Docker container management
- DNS server configuration (dnsmasq)
- Git version control
- Bash scripting
- Documentation best practices

### Troubleshooting Experience

**Problem 1: Pi-hole couldn't reach Tailscale DNS**
- Root Cause: Docker network isolation
- Solution: Local DNS records instead of forwarding
- Learning: Understanding Docker networking boundaries

**Problem 2: DNS records not resolving**
- Root Cause: `etc_dnsmasq_d = false` in pihole.toml
- Solution: Enabled the setting and restarted container
- Learning: Pi-hole configuration hierarchy

**Problem 3: Unraid WebGUI unresponsive**
- Root Cause: High I/O load (25+ load average, 25% I/O wait)
- Solution: Stopped VM and non-critical containers
- Learning: Performance troubleshooting methodology

### Repository Status

**Files Created:**
- `README.md` - Project overview and portfolio presentation
- `docs/01-infrastructure-inventory.md` - Complete asset documentation
- `docs/03-pihole-dns-configuration.md` - DNS configuration guide
- `docs/certification-concepts.md` - Security+/Network+ concept mapping
- `configs/pihole/04-local-dns.conf` - Pi-hole DNS configuration
- `scripts/test-dns.sh` - Automated DNS testing script
- `scripts/add-pihole-dns.sh` - DNS record management script

**Git Commits:**
1. Initial project setup with README and documentation
2. Phase 2 DNS configuration and scripts

### Next Session Goals

#### Phase 3: Security Audit & Vulnerability Assessment
- [ ] Install and configure container vulnerability scanner (Trivy)
- [ ] Scan all 18 running container images
- [ ] Document findings with CVE details
- [ ] Create remediation plan prioritized by severity

#### Phase 4: Security Hardening
- [ ] Bind databases to localhost only
- [ ] Implement Docker network segmentation
- [ ] Review and harden container configurations
- [ ] Implement least privilege (non-root containers)

#### Phase 5: Monitoring & Logging
- [ ] Deploy lightweight SIEM or log aggregation
- [ ] Configure centralized logging for containers
- [ ] Set up basic intrusion detection

### Learning Reflections

**What Went Well:**
- Systematic approach to infrastructure documentation
- Successfully troubleshot multiple DNS issues
- Created reusable scripts and configuration
- Good documentation practices for portfolio

**Challenges Overcome:**
- Understanding Pi-hole's configuration hierarchy
- Docker network isolation preventing DNS forwarding
- Performance issues requiring service management

**Key Takeaways:**
- Always document before making changes (baseline)
- DNS is critical infrastructure - understanding it deeply is essential
- Container networking requires different mental model than traditional networking
- Portfolio work doubles as study material for certifications

### Certification Preparation Notes

**Security+ Study Points:**
- Practiced asset inventory (GRC domain)
- Applied risk assessment methodology
- Documented attack surface analysis
- Implemented defense in depth principles

**Network+ Study Points:**
- DNS record types and configuration
- Network troubleshooting methodology
- OSI model layers 3-7 in practice
- Docker bridge networking

---

**Hours Invested:** ~3 hours
**Lines of Documentation:** ~1200+
**Scripts Created:** 2
**Git Commits:** 2
**Services Configured:** 18

**Next Session:** Phase 3 - Vulnerability Assessment with automated scanning

## Session 2: October 30, 2025

### Completed Tasks

#### Phase 5: Monitoring & Logging (Initial Deploy) ✅
- Deployed local Loki on Grafana host (port 3100)
- Connected `loki` container to existing Docker network `saml-lab_saml-net`
- Deployed Promtail on Raspberry Pi 4 (Ubuntu) to ship Docker logs
- Configured Promtail client to push to `http://192.168.0.52:3100/loki/api/v1/push`
- Verified ingestion in Grafana Explore with query `{host="pi4"}`

**Technical Details:**
- Grafana UI: `http://grafana.homelab.local:8083`
- Loki container: `grafana/loki:2.9.6` listening on `3100`
- Promtail container: `grafana/promtail:2.9.6` on Pi4 with `--network host`
- Promtail config path (Pi4): `~/sec/homelab-security-hardening/configs/logging/promtail-pi4-config.yml`
- Promtail labels: `host=pi4`, `container`, `image`, `container_id`

**Key Commands Executed:**
```
# On Grafana host
docker network create observability || true
docker rm -f loki || true
docker run -d --name loki --network observability -p 3100:3100 \
  -v loki-data:/loki \
  grafana/loki:2.9.6 -config.file=/etc/loki/local-config.yaml

# Connect Loki to app network for service discovery with Grafana
docker network connect saml-lab_saml-net loki

# On Pi4 (Promtail)
docker rm -f promtail || true
docker run -d --name promtail --network host \
  -v /var/log:/var/log:ro \
  -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/sec/homelab-security-hardening/configs/logging/promtail-pi4-config.yml:/etc/promtail/config.yml:ro \
  grafana/promtail:2.9.6 \
  -config.file=/etc/promtail/config.yml
```

**Troubleshooting & Fixes:**
- DNS resolution failed for `grafana.homelab.local` on Pi -> used IP `192.168.0.52`
- Grafana data source 404 resolved by attaching `loki` to `saml-lab_saml-net` and using `http://loki:3100` from Grafana container

### Next Session Goals

#### Phase 3: Vulnerability Assessment (Complete Coverage)
- [ ] Run `./scripts/scan-all-containers.sh` for all services
- [ ] Consolidate findings and remediation plan

#### Phase 4: Security Hardening
- [ ] Apply least-privilege and read-only FS where feasible
- [ ] Bind sensitive services to localhost or internal networks
- [ ] Network segmentation validation

#### Phase 5: Monitoring & Logging
- [ ] Add dashboards for container restarts and error rates
- [ ] Persist Promtail with docker compose or systemd on Pi4
- [ ] Optional: Switch Promtail client back to hostname after Pi-hole A record
