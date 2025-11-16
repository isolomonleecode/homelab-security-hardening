# Tailscale + Pi-hole DNS Configuration

**Date:** 2025-11-09
**Goal:** Use Pi-hole as DNS server for all Tailscale devices
**Benefit:** `.homelab` domains work everywhere without manual /etc/hosts entries

---

## Problem

Currently, Tailscale devices use MagicDNS (100.100.100.100) which only resolves `.ts.net` domains. Your custom `.homelab` domains from Pi-hole don't work, requiring manual `/etc/hosts` entries on each device.

**Current DNS:** 100.100.100.100 (Tailscale MagicDNS)
**Desired DNS:** 192.168.0.19 (Pi-hole) → resolves both `.homelab` and `.ts.net` domains

---

## Solution Overview

Configure Tailscale to use Pi-hole as a global nameserver, which will:
1. ✅ Resolve `.homelab` domains (from Pi-hole's custom DNS)
2. ✅ Resolve `.ts.net` domains (forwarded to Tailscale)
3. ✅ Provide ad-blocking on all Tailscale devices
4. ✅ Work seamlessly across all devices (no /etc/hosts needed)

---

## Implementation Steps

### Step 1: Configure Pi-hole to Forward `.ts.net` Queries

Pi-hole needs to forward Tailscale domain queries back to Tailscale's DNS.

**On Raspberry Pi:**

```bash
ssh automation@100.112.203.63
sudo nano /data/pihole/data/dnsmasq/05-tailscale-dns.conf
```

**Add this content:**
```
# Forward Tailscale domains to Tailscale DNS
server=/ts.net/100.100.100.100
```

**Reload Pi-hole:**
```bash
docker exec pihole pihole reloaddns
```

### Step 2: Configure Tailscale Global Nameservers

**Option A: Via Tailscale Admin Console (Recommended)**

1. Go to https://login.tailscale.com/admin/dns
2. Under **Global nameservers**, click **Add nameserver**
3. Enter Pi-hole's Tailscale IP: `100.112.203.63`
4. Click **Save**
5. Under **Override local DNS**, toggle it **ON** (this ensures all devices use Pi-hole)

**Option B: Via Command Line (on each device)**

```bash
# On Linux
sudo tailscale set --accept-dns=true

# This will automatically use the global nameserver configured above
```

### Step 3: Verify Configuration

**Test DNS resolution:**

```bash
# Should resolve via Pi-hole
nslookup vault.homelab

# Should resolve via Tailscale (forwarded by Pi-hole)
nslookup sweetrpi-desktop.tailc12764.ts.net

# Should resolve via Pi-hole
nslookup jellyfin.homelab
```

**Check active DNS server:**
```bash
cat /etc/resolv.conf
# Should show: nameserver 100.112.203.63
```

---

## Configuration Files

### Pi-hole Tailscale DNS Forwarding

**File:** `/data/pihole/data/dnsmasq/05-tailscale-dns.conf` (on Raspberry Pi)

```
# Forward Tailscale domains to Tailscale DNS
server=/ts.net/100.100.100.100

# Optional: Forward specific domains if needed
# server=/example.com/1.1.1.1
```

### Local Repository Copy

Save a copy to your repository:

```bash
# On your local machine
cat > configs/pihole/05-tailscale-dns.conf << 'EOF'
# Forward Tailscale domains to Tailscale DNS
server=/ts.net/100.100.100.100
EOF
```

**Deploy command:**
```bash
scp configs/pihole/05-tailscale-dns.conf automation@100.112.203.63:/tmp/
ssh automation@100.112.203.63 "sudo cp /tmp/05-tailscale-dns.conf /data/pihole/data/dnsmasq/05-tailscale-dns.conf && docker exec pihole pihole reloaddns"
```

---

## Benefits After Configuration

### Before (MagicDNS Only)
```
❌ vault.homelab → DNS FAIL (requires /etc/hosts)
✅ sweetrpi-desktop.tailc12764.ts.net → 100.112.203.63
❌ jellyfin.homelab → DNS FAIL (requires /etc/hosts)
❌ pihole.homelab → DNS FAIL (requires /etc/hosts)
```

### After (Pi-hole + Tailscale)
```
✅ vault.homelab → 192.168.0.19 (via Pi-hole)
✅ sweetrpi-desktop.tailc12764.ts.net → 100.112.203.63 (via Pi-hole → Tailscale)
✅ jellyfin.homelab → 192.168.0.51 (via Pi-hole)
✅ pihole.homelab → 192.168.0.19 (via Pi-hole)
🎁 BONUS: Ad-blocking on all Tailscale devices!
```

---

## Troubleshooting

### DNS Not Resolving `.homelab` Domains

**Check if Tailscale is using Pi-hole:**
```bash
cat /etc/resolv.conf
# Expected: nameserver 100.112.203.63
# If you see: nameserver 100.100.100.100
# Fix: Enable "Override local DNS" in Tailscale admin console
```

**Check Pi-hole is reachable:**
```bash
ping 100.112.203.63
nslookup google.com 100.112.203.63
```

### `.ts.net` Domains Not Resolving

**Check Pi-hole is forwarding to Tailscale:**
```bash
ssh automation@100.112.203.63
cat /data/pihole/data/dnsmasq/05-tailscale-dns.conf
# Should contain: server=/ts.net/100.100.100.100
```

**Test forwarding:**
```bash
nslookup sweetrpi-desktop.tailc12764.ts.net
# Should return: 100.112.203.63
```

### Pi-hole Firewall Blocking Tailscale

**Check UFW allows DNS from Tailscale:**
```bash
ssh automation@100.112.203.63
sudo ufw status | grep 53
# Should see: 53 ALLOW from 100.0.0.0/8
```

**If missing, add rule:**
```bash
sudo ufw allow from 100.0.0.0/8 to any port 53 proto udp comment 'DNS from Tailscale'
sudo ufw allow from 100.0.0.0/8 to any port 53 proto tcp comment 'DNS from Tailscale'
```

### Some Devices Still Using Local DNS

**Force DNS on specific device:**
```bash
sudo tailscale set --accept-dns=true
```

**Disable local DNS overrides:**
- Some Linux distributions (systemd-resolved) ignore Tailscale DNS
- Add to `/etc/systemd/resolved.conf`:
  ```
  [Resolve]
  DNS=100.112.203.63
  Domains=~.
  ```
- Restart: `sudo systemctl restart systemd-resolved`

---

## Network Flow

### DNS Query Path

```
┌─────────────────────────────────────────────────────────────┐
│  Device (capcorp9000)                                        │
│  Query: vault.homelab                                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Tailscale DNS (100.112.203.63)                              │
│  Configured: Pi-hole as global nameserver                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Pi-hole (192.168.0.19)                                      │
│  - Check custom DNS: 04-local-dns.conf                       │
│  - Match found: vault.homelab → 192.168.0.19                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Response: 192.168.0.19                                      │
│  Device can now access: https://vault.homelab:8443           │
└─────────────────────────────────────────────────────────────┘
```

### For `.ts.net` Domains

```
┌─────────────────────────────────────────────────────────────┐
│  Device Query: sweetrpi-desktop.tailc12764.ts.net            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Pi-hole                                                     │
│  - Check: 05-tailscale-dns.conf                              │
│  - Rule: server=/ts.net/100.100.100.100                      │
│  - Forward to: Tailscale MagicDNS                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Tailscale MagicDNS (100.100.100.100)                        │
│  - Resolve: sweetrpi-desktop.tailc12764.ts.net               │
│  - Return: 100.112.203.63                                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Response: 100.112.203.63                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Security Considerations

### DNS Over Tailscale

**Encryption:** All DNS queries between devices and Pi-hole are encrypted via WireGuard
**Privacy:** DNS queries don't leak to ISP (travels over Tailscale mesh)
**Integrity:** Tailscale prevents DNS spoofing/MITM attacks

### Pi-hole Access Control

**Current UFW Rules:**
```
Port 53 (DNS) → ALLOW from 192.168.0.0/24 (LAN)
Port 53 (DNS) → ALLOW from 100.0.0.0/8 (Tailscale)
Port 80 (Admin) → ALLOW from 192.168.0.0/24 (LAN ONLY)
```

**Security Notes:**
- ✅ DNS accessible from Tailscale (needed for this setup)
- ✅ Admin panel restricted to LAN only
- ✅ No DNS exposed to internet

### Ad-Blocking on Tailscale

**Bonus Benefit:** All Tailscale devices get ad-blocking!
- Mobile devices: Ad-free browsing
- Remote laptops: Protected from trackers
- Works everywhere: Home, coffee shops, hotels

---

## Maintenance

### Adding New DNS Records

**Process:**
1. Edit `configs/pihole/04-local-dns.conf` locally
2. Add entry: `address=/newservice.homelab/192.168.0.XX`
3. Deploy:
   ```bash
   scp configs/pihole/04-local-dns.conf automation@100.112.203.63:/tmp/
   ssh automation@100.112.203.63 "sudo cp /tmp/04-local-dns.conf /data/pihole/data/dnsmasq/04-local-dns.conf && docker exec pihole pihole reloaddns"
   ```
4. Test: `nslookup newservice.homelab` (should work on all Tailscale devices)

### Updating Tailscale Forwarding

**If Tailscale changes DNS servers:**
1. Update `05-tailscale-dns.conf` with new IP
2. Reload Pi-hole DNS

### Monitoring

**Check Pi-hole query logs:**
- Admin panel: http://pihole.homelab/admin
- Tools → Query Log
- Filter by client IP to see Tailscale devices

**Common queries from Tailscale devices:**
- `.homelab` domains (custom)
- `.ts.net` domains (forwarded)
- External domains (regular queries)

---

## Alternative: Split DNS (Advanced)

If you want different DNS behavior for LAN vs Tailscale:

**Scenario:**
- LAN devices: Use Pi-hole directly (192.168.0.19)
- Tailscale devices: Use split DNS (some queries to Pi-hole, some to other servers)

**Configuration:**
1. Create separate dnsmasq config for Tailscale
2. Use Tailscale's split DNS feature
3. Configure per-domain routing

**When to use:** If you have multiple DNS servers or want different filtering rules for remote devices

---

## Quick Reference

### Essential Commands

```bash
# Check current DNS
cat /etc/resolv.conf

# Test Pi-hole DNS
nslookup vault.homelab 100.112.203.63

# Reload Pi-hole DNS
docker exec pihole pihole reloaddns

# Force Tailscale to use configured DNS
sudo tailscale set --accept-dns=true

# Check Tailscale DNS status
tailscale status --json | grep -i dns
```

### Key Files

| File | Location | Purpose |
|------|----------|---------|
| 04-local-dns.conf | /data/pihole/data/dnsmasq/ | Custom .homelab domains |
| 05-tailscale-dns.conf | /data/pihole/data/dnsmasq/ | Forward .ts.net to Tailscale |
| /etc/resolv.conf | Local machine | Shows active DNS server |

### Access URLs After Setup

```
# These work from ANY Tailscale device without /etc/hosts:
https://vault.homelab:8443              # Vaultwarden
https://sweetrpi-desktop.tailc12764.ts.net:8443  # Nextcloud
http://pihole.homelab/admin             # Pi-hole (LAN only)
http://jellyfin.homelab:8096            # Jellyfin
http://homarr.homelab:10005             # Homarr
```

---

## Rollback Plan

**If something breaks:**

1. **Disable Pi-hole in Tailscale:**
   - Go to https://login.tailscale.com/admin/dns
   - Remove `100.112.203.63` from global nameservers
   - Devices will revert to MagicDNS

2. **Re-enable local DNS on device:**
   ```bash
   sudo tailscale set --accept-dns=false
   ```

3. **Temporarily use /etc/hosts:**
   ```bash
   sudo nano /etc/hosts
   # Add manual entries as needed
   ```

---

## Success Criteria

After configuration, you should be able to:

1. ✅ Access `https://vault.homelab:8443` from any Tailscale device
2. ✅ Access `http://jellyfin.homelab:8096` from any Tailscale device
3. ✅ Access `https://sweetrpi-desktop.tailc12764.ts.net:8443` (still works)
4. ✅ See Pi-hole query logs showing Tailscale device IPs
5. ✅ Get ad-blocking on all Tailscale devices
6. ✅ No manual /etc/hosts entries required

---

**Last Updated:** 2025-11-09
**Status:** Ready to implement
**Documentation:** Part of homelab-security-hardening project

## Next Steps

1. Create `05-tailscale-dns.conf` on Raspberry Pi
2. Configure Tailscale global nameserver in admin console
3. Test DNS resolution from multiple devices
4. Remove manual `/etc/hosts` entries once verified working
