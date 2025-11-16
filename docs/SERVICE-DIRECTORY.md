# Homelab Service Directory

**Last Updated:** 2025-11-09

Complete directory of all homelab services with DNS names, IPs, ports, and access URLs.

---

## Quick Access URLs

### Via Tailscale (Secure Remote Access)

| Service | URL | Notes |
|---------|-----|-------|
| **Nextcloud** | https://sweetrpi-desktop.tailc12764.ts.net:8443 | ✅ Trusted certificate,What's the best way to update the containers on the raspberryPI? should watchtower be installed? should I hit "recreate" on the containers individually in portainer?
SERVICE-DIRECTORY.md
//sweetrpi-desktop.tailc12764.ts.net:9000 | ✅ Trusted certificate, works from anywhere |
| **Pi-hole Admin** | http://pihole.homelab/admin | DNS/Ad-blocking (LAN only) |

### Via Local Network (LAN)

| Service | URL | Notes |
|---------|-----|-------|
| **Unraid Dashboard** | https://192.168.0.51 | Main Unraid web interface |
| **Nextcloud** | https://192.168.0.51:11000 | Self-signed cert warning |
| **Jellyfin** | http://jellyfin.homelab:8096 | Media server |
| **Radarr** | http://radarr.homelab:7878 | Movie management |
| **Sonarr** | http://sonarr.homelab:8989 | TV show management |
| **Lidarr** | http://lidarr.homelab:8686 | Music management |
| **Readarr** | http://readarr.homelab:8787 | Book management |
| **Bazarr** | http://bazarr.homelab:6767 | Subtitle management |
| **Prowlarr** | http://prowlarr.homelab:9696 | Indexer management |
| **Overseerr** | http://overseerr.homelab:5055 | Media request management |
| **Homarr** | http://homarr.homelab:10005 | Homepage/dashboard |
| **Krusader** | http://krusader.homelab:6080 | File manager |
| **Adminer** | http://adminer.homelab:8080 | Database management |
| **MeTube** | http://metube.homelab:8081 | YouTube downloader |
| **Nginx Proxy Manager** | http://npm.homelab:81 | Reverse proxy manager |
| **Pi-hole** | http://pihole.homelab/admin | DNS/Ad-blocking |

---

## DNS Records

### Pi-hole Custom DNS (`/data/pihole/data/dnsmasq/04-local-dns.conf`)

```
# Unraid services (all on 192.168.0.51)
address=/unraid.homelab/192.168.0.51
address=/jellyfin.homelab/192.168.0.51
address=/radarr.homelab/192.168.0.51
address=/sonarr.homelab/192.168.0.51
address=/lidarr.homelab/192.168.0.51
address=/readarr.homelab/192.168.0.51
address=/bazarr.homelab/192.168.0.51
address=/prowlarr.homelab/192.168.0.51
address=/overseerr.homelab/192.168.0.51
address=/homarr.homelab/192.168.0.51
address=/krusader.homelab/192.168.0.51
address=/adminer.homelab/192.168.0.51
address=/metube.homelab/192.168.0.51
address=/npm.homelab/192.168.0.51

# Pi-hole itself (192.168.0.19)
address=/pihole.homelab/192.168.0.19

# Tailscale services
address=/sweetrpi-desktop.tailc12764.ts.net/100.112.203.63
```

### /etc/hosts (Local Machine)

For machines not using Pi-hole as DNS:

```
100.112.203.63 sweetrpi-desktop.tailc12764.ts.net
```

---

## Network Topology

### Unraid Server (capcorplee)
- **LAN IP:** 192.168.0.51
- **Tailscale IP:** 100.69.191.4
- **Tailscale Hostname:** capcorplee.tailc12764.ts.net

#### Services on Unraid

| Service | Container Port | Host Port | Protocol | Access |
|---------|----------------|-----------|----------|--------|
| Unraid WebUI | N/A | 80, 443 | HTTP/HTTPS | LAN |
| Nextcloud | 443 | 11000 | HTTPS | LAN + Tailscale (via proxy) |
| Jellyfin | 8096 | 8096 | HTTP | LAN |
| Radarr | 7878 | 7878 | HTTP | LAN |
| Sonarr | 8989 | 8989 | HTTP | LAN |
| Lidarr | 8686 | 8686 | HTTP | LAN |
| Readarr | 8787 | 8787 | HTTP | LAN |
| Bazarr | 6767 | 6767 | HTTP | LAN |
| Prowlarr | 9696 | 9696 | HTTP | LAN |
| Overseerr | 5055 | 5055 | HTTP | LAN |
| Homarr | 10005 | 10005 | HTTP | LAN |
| Krusader | 6080 | 6080 | HTTP | LAN |
| Adminer | 8080 | 8080 | HTTP | LAN |
| MeTube | 8081 | 8081 | HTTP | LAN |
| Nginx Proxy Manager | 81, 80, 443 | 81, 8082, 4443 | HTTP/HTTPS | LAN |

### Raspberry Pi (sweetrpi-desktop)
- **LAN IP:** 192.168.0.19
- **Tailscale IP:** 100.112.203.63
- **Tailscale Hostname:** sweetrpi-desktop.tailc12764.ts.net

#### Services on Raspberry Pi

| Service | Container Port | Host Port | Protocol | Access |
|---------|----------------|-----------|----------|--------|
| Pi-hole | 80, 53 | 80, 53 | HTTP/DNS | LAN |
| Caddy | 8080, 8443, 9000 | 8080, 8443, 9000 | HTTP/HTTPS | Tailscale |
| Vaultwarden | 80 | 1776 | HTTP | Behind Caddy |
| Prometheus | 9090 | 9090 | HTTP | LAN |
| Grafana | 3000 | 3000 | HTTP | LAN |
| Loki | 3100 | 3100 | HTTP | LAN |
| Node-RED | 1880 | 1880 | HTTP | Tailscale |

---

## Service Details

### Nextcloud (File Storage & Collaboration)
- **Primary Access:** https://sweetrpi-desktop.tailc12764.ts.net:8443
- **Alternative:** https://192.168.0.51:11000 (self-signed cert)
- **DNS:** sweetrpi-desktop.tailc12764.ts.net → 100.112.203.63
- **Flow:** Client → Caddy (Raspberry Pi) → Nextcloud (Unraid)
- **Certificate:** Let's Encrypt via Tailscale (expires Jan 23, 2026)
- **Mobile App:** Use primary URL, no certificate warnings

### Vaultwarden (Password Manager)
- **LAN Access:** https://vault.homelab:8443 (self-signed cert warning expected)
- **Tailscale Access:** https://sweetrpi-desktop.tailc12764.ts.net:9000 (✅ trusted Let's Encrypt cert)
- **DNS:** vault.homelab → 192.168.0.19 (LAN only)
- **Container:** Vaultwarden on Raspberry Pi (port 1776 → Caddy)
- **Security:** Restricted to LAN and Tailscale networks via UFW
- **Recommended:** Use Tailscale URL for mobile apps and remote access

### Pi-hole (DNS & Ad Blocking)
- **Access:** http://pihole.homelab/admin
- **DNS:** pihole.homelab → 192.168.0.19
- **Port:** 80 (HTTP)
- **DNS Port:** 53 (UDP/TCP)
- **Custom DNS Config:** `/data/pihole/data/dnsmasq/04-local-dns.conf`

### Jellyfin (Media Server)
- **Access:** http://jellyfin.homelab:8096
- **DNS:** jellyfin.homelab → 192.168.0.51
- **Port:** 8096 (HTTP)

### Arr Stack (Media Management)
- **Radarr (Movies):** http://radarr.homelab:7878
- **Sonarr (TV):** http://sonarr.homelab:8989
- **Lidarr (Music):** http://lidarr.homelab:8686
- **Readarr (Books):** http://readarr.homelab:8787
- **Bazarr (Subtitles):** http://bazarr.homelab:6767
- **Prowlarr (Indexers):** http://prowlarr.homelab:9696
- **DNS:** All resolve to 192.168.0.51

### Overseerr (Media Requests)
- **Access:** http://overseerr.homelab:5055
- **DNS:** overseerr.homelab → 192.168.0.51
- **Port:** 5055 (HTTP)

### Homarr (Dashboard)
- **Access:** http://homarr.homelab:10005
- **DNS:** homarr.homelab → 192.168.0.51
- **Port:** 10005 (HTTP)

---

## Firewall Rules

### Raspberry Pi (UFW)

```bash
# SSH
22/tcp    ALLOW from 192.168.0.0/24
22/tcp    ALLOW from 100.0.0.0/8

# DNS (Pi-hole)
53        ALLOW from 192.168.0.0/24

# HTTP/HTTPS (Caddy)
8080/tcp  ALLOW from 100.0.0.0/8  # HTTP
8443/tcp  ALLOW from 100.0.0.0/8  # HTTPS (Nextcloud)
9000/tcp  ALLOW from 100.0.0.0/8  # HTTPS (Vaultwarden)

# Pi-hole Admin
80/tcp    ALLOW from 192.168.0.0/24

# Node-RED
1880/tcp  ALLOW from 100.0.0.0/8

# Monitoring
9090/tcp  ALLOW from 192.168.0.0/24  # Prometheus
3000/tcp  ALLOW from 192.168.0.0/24  # Grafana
```

### Unraid Server

No firewall configured (relies on network-level security)

---

## Browser Bookmarks (Recommended)

### Essential Services
```
Nextcloud (Tailscale):      https://sweetrpi-desktop.tailc12764.ts.net:8443
Vaultwarden (Tailscale):    https://sweetrpi-desktop.tailc12764.ts.net:9000
Vaultwarden (LAN):          https://vault.homelab:8443
Unraid:                     https://192.168.0.51
Pi-hole:                    http://pihole.homelab/admin
Jellyfin:                   http://jellyfin.homelab:8096
Overseerr:                  http://overseerr.homelab:5055
Homarr:                     http://homarr.homelab:10005
Grafana:                    http://192.168.0.19:3000
```

### Media Management
```
Radarr:    http://radarr.homelab:7878
Sonarr:    http://sonarr.homelab:8989
Lidarr:    http://lidarr.homelab:8686
Readarr:   http://readarr.homelab:8787
Bazarr:    http://bazarr.homelab:6767
Prowlarr:  http://prowlarr.homelab:9696
```

---

## Maintenance

### DNS Updates

**To add a new service DNS entry:**

1. Edit local config:
   ```bash
   nano /run/media/ssjlox/gamer/homelab-security-hardening/configs/pihole/04-local-dns.conf
   ```

2. Add entry:
   ```
   address=/service-name.homelab/192.168.0.XX
   ```

3. Deploy to Pi-hole:
   ```bash
   scp configs/pihole/04-local-dns.conf automation@100.112.203.63:/tmp/
   ssh automation@100.112.203.63 "sudo cp /tmp/04-local-dns.conf /data/pihole/data/dnsmasq/04-local-dns.conf && docker exec pihole pihole reloaddns"
   ```

4. Update this document!

### Certificate Renewal (Nextcloud/Caddy)

**Expiry:** January 23, 2026

**Manual renewal:**
```bash
ssh automation@100.112.203.63
sudo tailscale cert sweetrpi-desktop.tailc12764.ts.net
sudo mv sweetrpi-desktop.tailc12764.ts.net.* /opt/caddy/certs/
sudo chown automation:automation /opt/caddy/certs/sweetrpi-desktop.tailc12764.ts.net.*
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## Troubleshooting

### DNS Not Resolving

**Symptoms:** `*.homelab` domains don't resolve

**Fixes:**
1. Verify Pi-hole is your DNS server: `cat /etc/resolv.conf`
2. If using Tailscale DNS (100.100.100.100), add to `/etc/hosts`
3. Check Pi-hole DNS is running: `docker ps | grep pihole`
4. Reload Pi-hole DNS: `docker exec pihole pihole reloaddns`

### Can't Access Service

**Check list:**
1. ✅ Service container running? `docker ps | grep service-name`
2. ✅ Firewall allows port? `sudo ufw status | grep PORT`
3. ✅ DNS resolves? `ping service-name.homelab`
4. ✅ Port correct in URL?
5. ✅ On correct network? (LAN vs Tailscale)

### Certificate Warnings

**Nextcloud via Caddy:** Should have NO warnings (Let's Encrypt trusted)
**Direct Unraid access:** Expected (self-signed certificates)
**Vaultwarden:** Expected (self-signed certificate for .homelab domain)

---

## Security Notes

### Network Segmentation
- **LAN (192.168.0.0/24):** Full access to all services
- **Tailscale (100.0.0.0/8):** Limited access via firewall rules
- **Internet:** No direct access (no port forwarding)

### Access Control
- **Nextcloud:** Reverse proxy with trusted certificates
- **Vaultwarden:** Restricted to Tailscale network only
- **Arr Stack:** LAN only (no remote access)
- **Pi-hole Admin:** LAN only recommended

### Certificates
- **Let's Encrypt (Tailscale):** sweetrpi-desktop.tailc12764.ts.net
- **Self-signed:** vault.homelab, Unraid, direct Nextcloud access

---

**Last Updated:** 2025-11-09
**Maintained By:** isolomonlee
**Documentation:** https://github.com/isolomonleecode/homelab-security-hardening
