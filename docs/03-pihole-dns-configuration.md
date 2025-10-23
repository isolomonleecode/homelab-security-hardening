# Pi-hole Local DNS Configuration

**Date:** October 23, 2025
**Purpose:** Enable local domain name access to homelab services
**Method:** Custom DNS A records in Pi-hole

## Network+ Concepts Applied

**DNS Resource Records:**
- **A Record:** Maps domain name to IPv4 address
- **Local DNS:** Authoritative responses for internal domains
- **Split-horizon DNS:** Different answers for internal vs external queries

**Why This Works:**
1. Client queries Pi-hole for `jellyfin.homelab`
2. Pi-hole checks local DNS records first
3. Finds match, returns `192.168.0.51`
4. Client connects using domain name instead of IP

## Implementation Methods

### Method 1: Pi-hole Web UI (Recommended)

**Access:** http://192.168.0.19/admin

**Steps:**
1. Login to Pi-hole admin interface
2. Navigate to **Local DNS** → **DNS Records**
3. Add each record below:
   - **Domain:** service.homelab
   - **IP Address:** 192.168.0.51 (Unraid server IP)
4. Click **Add** for each entry
5. Test with `nslookup service.homelab 192.168.0.19`

### Method 2: Configuration File (Advanced)

**File:** `/etc/dnsmasq.d/02-local-dns.conf` (in Pi-hole container)

**Format:**
```
address=/service.homelab/192.168.0.51
```

**Requires:** SSH access to Pi-hole host, container restart

---

## DNS Records to Add

### Primary Services (Unraid Server: 192.168.0.51)

| Service | Domain Name | IP Address | Port | Notes |
|---------|-------------|------------|------|-------|
| Unraid WebGUI | unraid.homelab | 192.168.0.51 | 443 | Main server interface |
| Jellyfin | jellyfin.homelab | 192.168.0.51 | 8096 | Media streaming |
| Radarr | radarr.homelab | 192.168.0.51 | 7878 | Movie management |
| Sonarr | sonarr.homelab | 192.168.0.51 | 8989 | TV show management |
| Lidarr | lidarr.homelab | 192.168.0.51 | 8686 | Music management |
| Readarr | readarr.homelab | 192.168.0.51 | 8787 | Book management |
| Bazarr | bazarr.homelab | 192.168.0.51 | 6767 | Subtitle management |
| Prowlarr | prowlarr.homelab | 192.168.0.51 | 9696 | Indexer manager |
| Overseerr | overseerr.homelab | 192.168.0.51 | 5055 | Media requests |
| Homarr | homarr.homelab | 192.168.0.51 | 10005 | Dashboard |
| Krusader | krusader.homelab | 192.168.0.51 | 8085 | File manager |
| Adminer | adminer.homelab | 192.168.0.51 | 8087 | Database admin |
| MeTube | metube.homelab | 192.168.0.51 | 8081 | Video downloader |
| Nginx Proxy Manager | npm.homelab | 192.168.0.51 | 1880 | Web UI |
| NPM Admin | npm-admin.homelab | 192.168.0.51 | 7818 | Admin interface |

### Database Services (Consider Restricting Access)

| Service | Domain Name | IP Address | Port | Security Note |
|---------|-------------|------------|------|---------------|
| PostgreSQL | postgres.homelab | 192.168.0.51 | 5432 | **HIGH RISK** - Should not be publicly accessible |
| MariaDB | mariadb.homelab | 192.168.0.51 | 3306 | **HIGH RISK** - Should not be publicly accessible |

**Security+ Note:** Exposing databases via easy-to-remember domains increases attack surface. Consider:
- Using IP:PORT for databases (security through obscurity - not true security but reduces casual scanning)
- Binding databases to localhost only
- Using SSH tunnels for remote database access

### Nextcloud Services (Currently Stopped)

| Service | Domain Name | IP Address | Port | Notes |
|---------|-------------|------------|------|-------|
| Nextcloud | nextcloud.homelab | 192.168.0.51 | 11000 | When restarted |

**Alternative:** Use Tailscale domain `capcorplee.tailc12764.ts.net` for Nextcloud (already configured)

### Network Services

| Service | Domain Name | IP Address | Port | Notes |
|---------|-------------|------------|------|-------|
| Pi-hole | pihole.homelab | 192.168.0.19 | 80 | DNS admin interface |
| Unraid Server | capcorplee.homelab | 192.168.0.51 | 443 | Alternative to .tailc12764.ts.net |

---

## Quick Reference: Add All Records

**Copy-paste this into Pi-hole (one at a time):**

```
Domain: unraid.homelab          IP: 192.168.0.51
Domain: jellyfin.homelab        IP: 192.168.0.51
Domain: radarr.homelab          IP: 192.168.0.51
Domain: sonarr.homelab          IP: 192.168.0.51
Domain: lidarr.homelab          IP: 192.168.0.51
Domain: readarr.homelab         IP: 192.168.0.51
Domain: bazarr.homelab          IP: 192.168.0.51
Domain: prowlarr.homelab        IP: 192.168.0.51
Domain: overseerr.homelab       IP: 192.168.0.51
Domain: homarr.homelab          IP: 192.168.0.51
Domain: krusader.homelab        IP: 192.168.0.51
Domain: adminer.homelab         IP: 192.168.0.51
Domain: metube.homelab          IP: 192.168.0.51
Domain: npm.homelab             IP: 192.168.0.51
Domain: pihole.homelab          IP: 192.168.0.19
```

---

## Testing DNS Configuration

### From Linux/Mac Terminal

```bash
# Test single record
nslookup jellyfin.homelab 192.168.0.19

# Expected output:
Server:  192.168.0.19
Address: 192.168.0.19#53

Name:    jellyfin.homelab
Address: 192.168.0.51
```

### From Windows Command Prompt

```cmd
nslookup jellyfin.homelab 192.168.0.19
```

### From Web Browser

After adding records, test by visiting:
- http://jellyfin.homelab:8096
- http://radarr.homelab:7878
- http://homarr.homelab:10005

**Note:** You still need to include the port number since we're not using reverse proxy yet.

---

## Advanced: Wildcard DNS (Optional)

**Scenario:** You want `*.homelab` to all point to Unraid server

**Configuration:**
```
Domain: *.homelab
IP: 192.168.0.51
```

**Pros:**
- Access any service via `servicename.homelab` without individual records
- Easy to add new services

**Cons:**
- Less explicit (harder to audit what services exist)
- Can't point different services to different IPs
- Security+ principle: Explicit is better than implicit

**Recommendation:** Use explicit records (what we're doing) for better documentation and security.

---

## Reverse Proxy Configuration (Future Enhancement)

### Current State: Domain + Port
```
http://jellyfin.homelab:8096
http://radarr.homelab:7878
```

### Future Goal: Domain Only (Using Nginx Reverse Proxy)
```
https://jellyfin.homelab  (port 443, proxies to :8096)
https://radarr.homelab    (port 443, proxies to :7878)
```

**Requirements:**
1. Pi-hole DNS records (what we're doing now) ✓
2. Nginx reverse proxy with virtual hosts
3. SSL certificates (wildcard certificate for *.homelab)
4. Nginx configuration for each service

**Security+ Benefit:**
- Centralized authentication
- Centralized TLS termination
- Easier to implement WAF (Web Application Firewall)
- Single point for access logging

**We'll tackle this in Phase 4: Security Hardening**

---

## Troubleshooting

### DNS Not Resolving

**Check 1: Is Pi-hole your DNS server?**
```bash
# Linux/Mac
cat /etc/resolv.conf
# Should show: nameserver 192.168.0.19

# Windows
ipconfig /all
# Look for DNS Servers: 192.168.0.19
```

**Check 2: Is record added correctly?**
- Login to Pi-hole admin
- Local DNS → DNS Records
- Verify record exists

**Check 3: Clear DNS cache**
```bash
# Linux
sudo systemd-resolve --flush-caches

# Mac
sudo dscacheutil -flushcache

# Windows
ipconfig /flushdns
```

**Check 4: Test Pi-hole directly**
```bash
nslookup jellyfin.homelab 192.168.0.19
# Bypasses local cache, queries Pi-hole directly
```

### Browser Shows "Site Can't Be Reached"

**Cause:** DNS works, but service isn't running or firewall blocking

**Debug:**
```bash
# Test if service is listening
curl http://192.168.0.51:8096

# If this works but domain doesn't, it's DNS issue
# If this fails too, service is down or firewall blocking
```

---

## Documentation for Portfolio

**What This Demonstrates:**
- Understanding of DNS architecture and resolution
- Network troubleshooting methodology
- Service documentation and asset tracking
- Security-conscious design decisions

**Interview Talking Points:**
- "I configured split-horizon DNS using Pi-hole to enable local name resolution"
- "I documented all services with DNS records for better asset management"
- "I chose explicit records over wildcard for security and audibility"
- "I recognized that exposing databases via easy DNS names increases attack surface"

---

## Security Considerations

### Security+ Domain 2: Architecture & Design

**Potential Risks:**
1. **Information Disclosure:** DNS records reveal your infrastructure
   - Mitigation: Internal DNS only (not public)
   - Pi-hole doesn't respond to external queries

2. **DNS Spoofing:** Attacker poisons Pi-hole cache
   - Mitigation: DNSSEC validation (check Pi-hole settings)
   - Limited risk in home network

3. **Service Enumeration:** Attacker queries DNS to find services
   - Mitigation: Internal-only DNS server
   - Network segmentation (VLANs would help)

**Best Practices:**
- ✅ Use internal TLD (.homelab, not .com)
- ✅ Don't expose Pi-hole to internet
- ✅ Document all DNS records (this file!)
- ✅ Use descriptive names (jellyfin vs srv01)
- ⚠️ Consider access controls for sensitive services
- ⚠️ Implement HTTPS for all services (future phase)

---

## Next Steps

1. **Add DNS records via Pi-hole Web UI** (do this now)
2. **Test from multiple devices** (phone, laptop, desktop)
3. **Update bookmarks** to use domain names instead of IPs
4. **Update Homarr dashboard** to use new domain names
5. **Document in inventory** (update 01-infrastructure-inventory.md)

After DNS is working, we'll proceed to Phase 3: Container Security Scanning

---

**Last Updated:** October 23, 2025
**Status:** Configuration pending user action
**Next Review:** After DNS records are added and tested
