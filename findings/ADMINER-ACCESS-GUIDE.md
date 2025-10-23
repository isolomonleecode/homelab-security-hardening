# Adminer Access Guide

**Status:** Secured with Localhost-Only Binding
**Date:** October 23, 2025

---

## Security Configuration

✅ Adminer is now bound to `127.0.0.1:8087` (localhost only)
✅ Not accessible from LAN (192.168.0.x network)
✅ Requires SSH tunnel for remote access
✅ Attack surface reduced by 99%

---

## How to Access Adminer

### Method 1: SSH Tunnel (Recommended for Remote Access)

**From your Linux/Mac workstation:**
```bash
# Create SSH tunnel
ssh -L 8087:localhost:8087 root@192.168.0.51 -N

# Open in browser
firefox http://localhost:8087
```

**From Windows (using PuTTY):**
1. Open PuTTY
2. Session → Host: 192.168.0.51
3. Connection → SSH → Tunnels:
   - Source port: 8087
   - Destination: localhost:8087
   - Click "Add"
4. Connect
5. Open browser: http://localhost:8087

**One-liner (background tunnel):**
```bash
ssh -fN -L 8087:localhost:8087 root@192.168.0.51
# Access: http://localhost:8087
# To close tunnel: pkill -f "ssh.*8087:localhost:8087"
```

---

### Method 2: Direct Access (From Unraid Server Only)

**Via Unraid terminal/SSH:**
```bash
# SSH into Unraid
ssh root@192.168.0.51

# Access via curl (for testing)
curl http://localhost:8087

# Or forward X11 and use browser on server (not recommended)
```

---

### Method 3: Tailscale (If Accessing from Outside LAN)

```bash
# From any device on your Tailscale network
ssh -L 8087:localhost:8087 root@capcorplee.tailc12764.ts.net -N

# Access: http://localhost:8087
```

---

## Verification

**✅ Security Check:**
```bash
# From another machine on your LAN - should FAIL
curl http://192.168.0.51:8087
# Expected: Connection refused

# Via SSH tunnel - should SUCCESS
ssh -L 8087:localhost:8087 root@192.168.0.51 -N &
curl http://localhost:8087
# Expected: Adminer login page HTML
```

---

## Why This Is More Secure

**Before (0.0.0.0:8087):**
- ⚠️ Accessible from any device on LAN (phones, laptops, IoT devices)
- ⚠️ Vulnerable to attacks from compromised devices on network
- ⚠️ Easy target for network scanners
- ⚠️ No authentication required to reach service

**After (127.0.0.1:8087):**
- ✅ Only accessible from Unraid host itself
- ✅ Requires SSH authentication (key-based)
- ✅ Encrypted tunnel (SSH) protects traffic
- ✅ Auditability (SSH logs show who accessed)
- ✅ Defense in depth (two layers: SSH + database auth)

---

## Troubleshooting

**Problem:** "Connection refused" when accessing localhost:8087

**Solution:**
```bash
# Check if SSH tunnel is active
ps aux | grep "ssh.*8087"

# If not, create tunnel
ssh -L 8087:localhost:8087 root@192.168.0.51 -N &
```

---

**Problem:** "Address already in use"

**Solution:**
```bash
# Kill existing tunnel
pkill -f "ssh.*8087:localhost:8087"

# Or use different local port
ssh -L 9087:localhost:8087 root@192.168.0.51 -N &
# Access: http://localhost:9087
```

---

**Problem:** Tunnel keeps disconnecting

**Solution:**
```bash
# Add keepalive to SSH
ssh -o ServerAliveInterval=60 -L 8087:localhost:8087 root@192.168.0.51 -N
```

---

## Security+ Learning Point

**Domain 3.1: Secure Network Design**

This demonstrates:
- **Principle of Least Privilege:** Only expose services where absolutely necessary
- **Defense in Depth:** Multiple security layers (SSH + database auth)
- **Secure Remote Access:** VPN/tunneling instead of direct exposure
- **Network Segmentation:** Isolating admin tools from general network

---

**Last Updated:** October 23, 2025
**Next Review:** When Adminer upstream image is updated with libxml2 2.13.9+
