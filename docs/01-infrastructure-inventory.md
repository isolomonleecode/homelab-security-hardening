# Infrastructure Inventory & Asset Documentation

**Date:** October 23, 2025
**Auditor:** ssjlox
**Environment:** Production Homelab

## Executive Summary

This document provides a comprehensive inventory of all networked assets, services, and infrastructure components. Understanding your attack surface is the first step in any security assessment.

**Security+ Concept:** Asset Management (Domain 5: Governance, Risk & Compliance)
**Network+ Concept:** Network Documentation & Topology Mapping

## Network Architecture

### Physical & Virtual Interfaces

**Host Server: capcorplee (Unraid)**
- **Primary Interface (br0):** 192.168.0.51/24
  - Physical bond0 (eth0) bridged
  - Default gateway to LAN
  - Subnet: 192.168.0.0/24

- **Tailscale VPN (tailscale1):** 100.69.191.4/32
  - Mesh VPN overlay network
  - MagicDNS: capcorplee.tailc12764.ts.net
  - IPv6: fd7a:115c:a1e0::5f01:bf04

- **Docker Networks:**
  - docker0: 172.17.0.1/16 (default bridge)
  - br-098fbbd0b8d7: 172.19.0.1/16 (custom bridge)
  - br-2ecb9c668f31: 172.18.0.1/16 (custom bridge)

- **Libvirt (VM network):** 192.168.122.1/24
  - virbr0 interface
  - NAT mode for VMs

**Network+ Learning Point:**
- Bridge interfaces connect multiple networks at Layer 2
- Docker creates virtual bridges to isolate container networks
- Tailscale operates at Layer 3 (IP) creating encrypted tunnels

### External DNS & Routing

**DNS Infrastructure:**
- Primary DNS: Pi-hole at 192.168.0.19
- Tailscale MagicDNS: 100.100.100.100
- Upstream: Cloudflare (1.1.1.1)

**Public Access:**
- Cloudflare Tunnel: server.havenleefamily.online
- Tailscale access: capcorplee.tailc12764.ts.net
- Local access: 192.168.0.51

## Service Inventory

### Running Containers (18 Active)

| Service Name | Image | Exposed Ports | Network | Risk Level |
|--------------|-------|---------------|---------|------------|
| postgresql17 | postgres:17 | 5432 (TCP) | 172.19.x | **HIGH** - Database exposed |
| mariadb | linuxserver/mariadb | 3306 (TCP) | 172.19.x | **HIGH** - Database exposed |
| MeTube | alexta69/metube | 8081 (TCP) | host | MEDIUM |
| bazarr | linuxserver/bazarr | 6767 (TCP) | 172.19.x | LOW |
| homarr | homarr-labs/homarr | 10005 (TCP) | 172.19.x | LOW - Dashboard |
| binhex-radarr | binhex/arch-radarr | 7878 (TCP) | 172.19.x | MEDIUM |
| binhex-jellyfin | binhex/arch-jellyfin | 8096 (TCP) | 172.17.x | MEDIUM - Media server |
| adminer | adminer | 8087 (TCP) | 172.19.x | **HIGH** - DB admin tool |
| binhex-lidarr | binhex/arch-lidarr | 8686 (TCP) | 172.19.x | MEDIUM |
| binhex-flaresolverr | binhex/arch-flaresolverr | 8191 (TCP) | 172.17.x | MEDIUM |
| NginxProxyManager | jlesage/nginx-proxy-manager | 18443, 1880, 7818 (TCP) | 172.19.x | **HIGH** - Reverse proxy |
| binhex-overseerr | binhex/arch-overseerr | 5055 (TCP) | 172.19.x | MEDIUM |
| binhex-prowlarr | binhex/arch-prowlarr | 9696 (TCP) | 172.19.x | MEDIUM |
| binhex-readarr | binhex/arch-readarr | 8787 (TCP) | 172.19.x | MEDIUM |
| binhex-sonarr | binhex/arch-sonarr | 8989, 9897 (TCP) | 172.19.x | MEDIUM |
| watchtower | containrrr/watchtower | 8080 (internal) | N/A | LOW - Auto-updater |
| Unraid-Cloudflared-Tunnel | figro/unraid-cloudflared-tunnel | 46495 (TCP) | 172.17.x | **CRITICAL** - Public tunnel |
| Krusader | ich777/krusader | 8085 (TCP) | 172.17.x | MEDIUM - File manager |

### Stopped Containers (8 Inactive)

| Service Name | Last Status | Notes |
|--------------|-------------|-------|
| nextcloud-aio-mastercontainer | Exited (0) | Stopped for security review |
| nextcloud-aio-apache | Exited (137) | Nextcloud web server |
| nextcloud-aio-nextcloud | Exited (0) | Main Nextcloud app |
| nextcloud-aio-clamav | Exited (0) | Antivirus scanner |
| nextcloud-aio-redis | Exited (137) | Cache layer |
| nextcloud-aio-database | Exited (137) | Nextcloud PostgreSQL |
| nextcloud-aio-notify-push | Exited (143) | Push notifications |
| freshrss | Exited (0) | RSS reader (had stuck processes) |

### Virtual Machines

| VM Name | Status | Purpose | Risk Level |
|---------|--------|---------|------------|
| Ubuntu | Shut off | Testing/development | MEDIUM |
| Windows 10 | Shut off | Not in use | LOW |
| Windows 11 | Shut off | Not in use | LOW |

## Attack Surface Analysis

### Publicly Exposed Services

**CRITICAL FINDINGS:**

1. **Cloudflare Tunnel (port 46495)**
   - Provides public access to internal services
   - Tunnel endpoint: server.havenleefamily.online
   - **Risk:** Any misconfiguration exposes entire homelab
   - **Mitigation needed:** Audit tunnel routes, implement authentication

2. **Nginx Proxy Manager (ports 18443, 1880, 7818)**
   - Manages reverse proxy configurations
   - Admin interface potentially exposed
   - **Risk:** Unauthorized proxy modifications
   - **Mitigation needed:** Review authentication, access controls

3. **Databases (ports 3306, 5432)**
   - PostgreSQL and MariaDB exposed on 0.0.0.0
   - **Risk:** Direct database access from LAN
   - **Mitigation needed:** Bind to localhost only, require authentication

4. **Adminer (port 8087)**
   - Web-based database administration
   - **Risk:** Credential brute-forcing, information disclosure
   - **Mitigation needed:** Restrict access, implement fail2ban

### Network Segmentation Issues

**Current State:** Most containers share the same Docker bridge network (172.19.0.0/16)

**Security Concern:**
- Containers can communicate freely with each other
- No network isolation between sensitive services (databases) and public-facing apps
- Lateral movement possible if one container is compromised

**Security+ Concept:** Network Segmentation (Domain 2: Architecture & Design)
**Recommendation:** Implement Docker network policies or separate bridge networks

### DNS Security Considerations

**Pi-hole Configuration:**
- Running in Docker container
- Cannot reach Tailscale DNS (100.100.100.100) due to network isolation
- **Impact:** Local domain name resolution not working
- **Solution Required:** Configure Pi-hole local DNS records

## Security Priorities

### Immediate (Critical)
1. Secure database ports (bind to localhost or specific IPs)
2. Audit Cloudflare tunnel routes
3. Review Nginx Proxy Manager access controls
4. Configure Pi-hole local DNS for internal services

### Short-term (High)
1. Implement network segmentation for containers
2. Scan all container images for vulnerabilities
3. Review container privilege levels
4. Implement secret management solution

### Medium-term (Medium)
1. Deploy centralized logging (SIEM)
2. Implement intrusion detection
3. Create automated backup & recovery procedures
4. Document incident response procedures

## Compliance & Best Practices

**Frameworks to Apply:**
- CIS Docker Benchmark
- CIS Linux Benchmark
- NIST Cybersecurity Framework

**Security+ Domain Mapping:**
- Asset Management → Domain 5 (GRC)
- Network Segmentation → Domain 2 (Architecture)
- Access Control → Domain 3 (Implementation)
- Vulnerability Management → Domain 1 (Threats)

## Next Steps

1. Configure Pi-hole for local domain name resolution
2. Perform automated vulnerability scanning of containers
3. Create hardened Docker Compose configurations
4. Implement monitoring and alerting

---

**Last Updated:** October 23, 2025
**Next Review:** After Phase 2 completion
