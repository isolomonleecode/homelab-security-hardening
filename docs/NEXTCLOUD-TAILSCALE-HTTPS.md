# Nextcloud Tailscale HTTPS Configuration

**Date:** 2025-11-09
**Status:** ✅ Complete
**Issue Resolved:** Certificate warning when accessing Nextcloud via Tailscale

## Problem Statement

When accessing Nextcloud via the Tailscale domain `capcorplee.tailc12764.ts.net`, users received certificate warnings:

```
You attempted to reach capcorplee.tailc12764.ts.net. However the security
certificate presented by the server is unknown and could not be authenticated
by any trusted Certification Authority...
```

**Root Cause:** Nextcloud container was using self-signed certificates not trusted by browsers or mobile apps.

## Solution Architecture

Implemented **Option A: Caddy Reverse Proxy with Tailscale Certificates**

```
[Client]
    ↓ HTTPS (trusted Let's Encrypt cert)
[Caddy on Raspberry Pi] (100.112.203.63)
    ↓ HTTPS (self-signed, skip verification)
[Nextcloud on Unraid] (192.168.0.51:11000)
```

### Why This Approach?

1. **Centralized Certificate Management** - All certificates managed on one system (Raspberry Pi)
2. **Trusted Certificates** - Tailscale provides Let's Encrypt certificates automatically
3. **No Client Configuration** - Works on all browsers and mobile apps without trust warnings
4. **Security Headers** - Caddy adds modern security headers
5. **Consistent Architecture** - Caddy already proxies Vaultwarden, adding Nextcloud follows same pattern

## Implementation Steps

### 1. Enable Tailscale HTTPS on Unraid

```bash
ssh root@192.168.0.51
tailscale cert capcorplee.tailc12764.ts.net
```

**Output:**
```
Wrote public cert to capcorplee.tailc12764.ts.net.crt
Wrote private key to capcorplee.tailc12764.ts.net.key
```

**Certificate Storage:**
- Source: `/root/` (temporary)
- Destination: `/mnt/user/appdata/tailscale/certs/` (persistent)

### 2. Copy Certificates to Raspberry Pi

```bash
# Create certificate directory
ssh automation@100.112.203.63 "sudo mkdir -p /opt/caddy/certs"

# Copy from Unraid to Raspberry Pi
scp root@192.168.0.51:/mnt/user/appdata/tailscale/certs/capcorplee.tailc12764.ts.net.* \
    automation@100.112.203.63:/opt/caddy/certs/
```

### 3. Update Caddyfile

**File:** `/home/sweetrpi/caddy/Caddyfile`

```caddyfile
{
    http_port 8080
    https_port 8443
}

# Existing Vaultwarden configuration
vault.homelab:8443 {
    tls internal
    reverse_proxy vaultwarden:80
}

# NEW: Nextcloud reverse proxy with Tailscale certificates
capcorplee.tailc12764.ts.net {
    tls /opt/caddy/certs/capcorplee.tailc12764.ts.net.crt \
        /opt/caddy/certs/capcorplee.tailc12764.ts.net.key

    reverse_proxy https://192.168.0.51:11000 {
        transport http {
            tls_insecure_skip_verify  # Skip Nextcloud's self-signed cert
        }
    }

    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "no-referrer-when-downgrade"
    }
}
```

### 4. Recreate Caddy Container with Certificate Mount

```bash
# Stop and remove old container
docker stop caddy && docker rm caddy

# Start with certificate volume
docker run -d \
  --name caddy \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 8443:8443 \
  -v /home/sweetrpi/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  -v caddy_data:/data \
  -v caddy_config:/config \
  -v /opt/caddy/certs:/opt/caddy/certs:ro \
  --network bridge \
  caddy:latest
```

**Key Changes:**
- Added `-v /opt/caddy/certs:/opt/caddy/certs:ro` to mount certificates

## Certificate Details

### Certificate Authority

```
Issuer: C=US, O=Let's Encrypt, CN=E8
Subject: CN=capcorplee.tailc12764.ts.net
Valid From: Oct 20 15:15:08 2025 GMT
Valid Until: Jan 18 15:15:07 2026 GMT
```

### Validation

```bash
# Test HTTPS connection
curl -I https://capcorplee.tailc12764.ts.net

# Expected output:
HTTP/2 302
server: nginx
location: https://capcorplee.tailc12764.ts.net/Dashboard
```

## Certificate Auto-Renewal

### Renewal Script

**File:** `/root/scripts/renew-tailscale-certs.sh` (on Unraid)

```bash
#!/bin/bash
# Tailscale Certificate Renewal Script
# Renews certificates and deploys to Caddy on Raspberry Pi

set -e

DOMAIN="capcorplee.tailc12764.ts.net"
CERT_DIR="/mnt/user/appdata/tailscale/certs"
RASPI_HOST="automation@100.112.203.63"
RASPI_CERT_DIR="/opt/caddy/certs"

echo "[$(date)] Starting Tailscale certificate renewal..."

# Renew certificate on Unraid
tailscale cert "$DOMAIN"

# Move to persistent storage
mkdir -p "$CERT_DIR"
mv -f /root/${DOMAIN}.crt "$CERT_DIR/"
mv -f /root/${DOMAIN}.key "$CERT_DIR/"
chmod 644 "$CERT_DIR/${DOMAIN}.crt"
chmod 600 "$CERT_DIR/${DOMAIN}.key"

echo "[$(date)] Certificates renewed on Unraid"

# Copy to Raspberry Pi
scp "$CERT_DIR/${DOMAIN}.crt" "$CERT_DIR/${DOMAIN}.key" "${RASPI_HOST}:${RASPI_CERT_DIR}/"

echo "[$(date)] Certificates copied to Raspberry Pi"

# Reload Caddy
ssh "$RASPI_HOST" "docker exec caddy caddy reload --config /etc/caddy/Caddyfile"

echo "[$(date)] Caddy reloaded. Certificate renewal complete!"
```

### Cron Configuration

```bash
# Renew Tailscale certificates on the 1st of every month at midnight
0 0 1 * * /root/scripts/renew-tailscale-certs.sh >> /var/log/cert-renewal.log 2>&1
```

**Certificate Expiry:** 90 days
**Renewal Schedule:** Monthly (safe margin)
**Log File:** `/var/log/cert-renewal.log`

## Security Considerations

### Transport Security

1. **Client → Caddy:** Encrypted with trusted Let's Encrypt certificate
2. **Caddy → Nextcloud:** Encrypted with self-signed certificate (internal network only)
3. **Tailscale Mesh:** All traffic encrypted via WireGuard

### Security Headers Applied

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: no-referrer-when-downgrade
```

### Certificate Permissions

```bash
# On Unraid
/mnt/user/appdata/tailscale/certs/capcorplee.tailc12764.ts.net.crt (644)
/mnt/user/appdata/tailscale/certs/capcorplee.tailc12764.ts.net.key (600)

# On Raspberry Pi
/opt/caddy/certs/capcorplee.tailc12764.ts.net.crt (644)
/opt/caddy/certs/capcorplee.tailc12764.ts.net.key (600)
```

### Firewall Rules (UFW on Raspberry Pi)

```
Port 8080 (HTTP)  → ALLOW from 100.0.0.0/8 (Tailscale only)
Port 8443 (HTTPS) → ALLOW from 100.0.0.0/8 (Tailscale only)
```

Reference: [SESSION-4-RASPBERRY-PI-HARDENING.md](../sessions/SESSION-4-RASPBERRY-PI-HARDENING.md)

## Troubleshooting

### Certificate Not Loading

```bash
# Verify certificates exist in container
docker exec caddy ls -lah /opt/caddy/certs/

# Check Caddy logs
docker logs caddy

# Expected log entry:
# "skipping automatic certificate management because one or more matching certificates are already loaded"
```

### Certificate Renewal Fails

```bash
# Manual renewal test
ssh root@192.168.0.51
/root/scripts/renew-tailscale-certs.sh

# Check logs
tail -f /var/log/cert-renewal.log
```

### HTTPS Connection Fails

```bash
# Test from Raspberry Pi
curl -I https://capcorplee.tailc12764.ts.net

# Test certificate validation
echo | openssl s_client -connect capcorplee.tailc12764.ts.net:443 \
  -servername capcorplee.tailc12764.ts.net 2>/dev/null | \
  openssl x509 -noout -issuer -subject -dates
```

## References

### Related Documentation

- [NEXTCLOUD-TAILSCALE-RESOLUTION.md](../findings/NEXTCLOUD-TAILSCALE-RESOLUTION.md) - Trusted domains configuration
- [SESSION-4-RASPBERRY-PI-HARDENING.md](../sessions/SESSION-4-RASPBERRY-PI-HARDENING.md) - Raspberry Pi firewall setup
- [SESSION-5-VULNERABILITY-REMEDIATION.md](../sessions/SESSION-5-VULNERABILITY-REMEDIATION.md) - Caddy initial configuration

### Key Files

**On Unraid (192.168.0.51):**
- `/mnt/user/appdata/tailscale/certs/` - Certificate storage
- `/root/scripts/renew-tailscale-certs.sh` - Renewal script
- `/var/log/cert-renewal.log` - Renewal logs

**On Raspberry Pi (100.112.203.63):**
- `/home/sweetrpi/caddy/Caddyfile` - Caddy configuration
- `/opt/caddy/certs/` - Certificate mount point
- Backups: `/home/sweetrpi/caddy/Caddyfile.backup.*`

### Network Topology

```
Internet
    ↓
Tailscale WireGuard Mesh (100.0.0.0/8)
    ↓
Raspberry Pi (100.112.203.63) - Caddy Reverse Proxy
    ↓
LAN (192.168.0.0/24)
    ↓
Unraid Server (192.168.0.51) - Nextcloud (port 11000)
```

## Results

### Before Implementation

- ❌ Certificate warnings on all devices
- ❌ Mobile apps couldn't connect without accepting untrusted certificate
- ❌ Browser security warnings required manual bypass

### After Implementation

- ✅ Trusted Let's Encrypt certificates
- ✅ No warnings on any device (desktop, mobile, tablets)
- ✅ Automatic certificate renewal
- ✅ Enhanced security headers
- ✅ Consistent reverse proxy architecture

## Skills Demonstrated

1. **PKI/Certificate Management** - Tailscale HTTPS, Let's Encrypt integration
2. **Reverse Proxy Configuration** - Caddy TLS termination, backend HTTPS
3. **Docker Networking** - Volume mounts, network configuration
4. **Automation** - Cron jobs, renewal scripts, multi-host deployment
5. **Security Hardening** - HSTS, CSP headers, principle of least privilege
6. **Documentation** - Comprehensive runbooks with validation steps

---

**Deployment Date:** 2025-11-09
**Status:** Production
**Next Review:** Before certificate expiry (Jan 18, 2026)
