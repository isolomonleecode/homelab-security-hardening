# Wazuh Deployment Troubleshooting Guide

Quick solutions for common deployment issues.

---

## 🔧 Deployment Issues

### Error: "docker: invalid reference format"

**Cause:** Path with spaces not properly quoted

**Solution:** Use the simplified deployment script:

```bash
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh
./simple-deploy.sh
```

---

### Error: "Docker is not running"

**Solution:**

```bash
# Check Docker status
systemctl status docker

# Start Docker if stopped
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker
```

---

### Error: "Insufficient memory"

**Cause:** Less than 4GB RAM available

**Solutions:**

1. **Close other applications** to free up RAM
2. **Reduce Wazuh memory allocation** (edit after deployment):

```bash
cd wazuh-docker/single-node
# Edit docker-compose.yml
# Find: OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
# Change to: OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m
docker compose restart wazuh.indexer
```

---

## 🌐 Dashboard Access Issues

### Can't Access Dashboard

**Check 1: Are containers running?**

```bash
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh/wazuh-docker/single-node
docker compose ps
```

All containers should show "Up" status.

**Check 2: Is dashboard ready?**

```bash
# Check dashboard logs
docker compose logs wazuh.dashboard

# Look for: "Server running at https://0.0.0.0:443"
```

**Check 3: Correct URL?**

```bash
# Get your server IP
hostname -I | awk '{print $1}'

# URL should be: https://YOUR_IP (no port)
```

---

### Browser Shows "Connection Refused"

**Solution:** Wait longer (dashboard takes 2-3 minutes to start)

```bash
# Check if dashboard is starting
docker compose logs -f wazuh.dashboard

# Wait for: "Server running at https://0.0.0.0:443"
```

---

### Browser Shows "Your connection is not private"

**This is normal!** Wazuh uses self-signed SSL certificates.

**Solution:**

1. Click **"Advanced"** (or "Show Details")
2. Click **"Proceed to [IP address]"** (or "Accept Risk")
3. Login will appear

---

### Dashboard Shows "Unable to connect to Wazuh API"

**Solution 1: Wait for manager to start**

```bash
docker compose logs wazuh.manager | grep "Listening on port 55000"
```

**Solution 2: Restart dashboard**

```bash
docker compose restart wazuh.dashboard
```

---

## 🤖 Agent Issues

### Agent Shows "Disconnected"

**Check 1: Is agent running?**

```bash
docker ps | grep wazuh-agent
```

**Check 2: Can agent reach manager?**

```bash
docker exec wazuh-agent-homelab ping -c 3 wazuh.manager
```

**Check 3: Check agent logs**

```bash
docker logs wazuh-agent-homelab

# Look for: "Connected to enrollment service"
```

**Solution: Restart agent**

```bash
docker restart wazuh-agent-homelab
```

---

### Agent Not Appearing in Dashboard

**Check 1: Is agent registered?**

```bash
# Enter manager container
docker exec -it single-node-wazuh.manager-1 bash

# List agents
/var/ossec/bin/agent_control -l

# Exit container
exit
```

**Check 2: Network connectivity**

```bash
# Verify agent is on wazuh network
docker inspect wazuh-agent-homelab | grep NetworkMode
```

**Solution: Recreate agent with correct network**

```bash
# Remove old agent
docker rm -f wazuh-agent-homelab

# Redeploy (from QUICKSTART.md)
docker run -d \
  --name wazuh-agent-homelab \
  --hostname homelab-security-agent \
  --network single-node_default \
  --restart unless-stopped \
  -e WAZUH_MANAGER='wazuh.manager' \
  -e WAZUH_AGENT_NAME='homelab-docker-host' \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /:/rootfs:ro \
  -v /var/log:/var/log:ro \
  wazuh/wazuh-agent:4.9.0
```

---

## 💾 Performance Issues

### High Memory Usage

**Check current usage:**

```bash
docker stats --no-stream
```

**Solution: Reduce indexer memory**

```bash
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh/wazuh-docker/single-node

# Edit docker-compose.yml
# Change: OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
# To:     OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m

docker compose restart wazuh.indexer
```

---

### High CPU Usage

**Normal:** High CPU for first 5-10 minutes (indexing)

**If persistent:**

```bash
# Check which container
docker stats

# Restart the problematic container
docker compose restart [container_name]
```

---

## 🔄 Reset/Cleanup

### Stop Wazuh (Keep Data)

```bash
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh/wazuh-docker/single-node
docker compose down
```

### Stop Wazuh (Remove All Data)

```bash
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh/wazuh-docker/single-node
docker compose down -v

# ⚠️ WARNING: This deletes all security events and configuration!
```

### Start Fresh Deployment

```bash
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh

# Remove old deployment
rm -rf wazuh-docker

# Run deployment again
./simple-deploy.sh
```

---

## 📋 Verification Checklist

Use this checklist to verify successful deployment:

```bash
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh/wazuh-docker/single-node

# 1. All containers running
docker compose ps
# Expected: 3 containers with "Up" status

# 2. Manager is ready
docker compose logs wazuh.manager | grep "Listening on port 55000"
# Expected: "Listening on port 55000 (connection)"

# 3. Indexer is ready
docker compose logs wazuh.indexer | grep "Node started"
# Expected: "Node started"

# 4. Dashboard is ready
docker compose logs wazuh.dashboard | grep "Server running"
# Expected: "Server running at https://0.0.0.0:443"

# 5. Get access URL
echo "Dashboard URL: https://$(hostname -I | awk '{print $1}')"
```

**All checks passed?** You're ready to access the dashboard!

---

## 🆘 Still Having Issues?

### Collect Diagnostic Information

```bash
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh/wazuh-docker/single-node

# Save all logs
docker compose logs > wazuh-logs.txt

# Check system resources
free -h > system-resources.txt
df -h >> system-resources.txt

# Container status
docker compose ps > container-status.txt
```

### Check Official Documentation

- [Wazuh Docker Documentation](https://documentation.wazuh.com/current/deployment-options/docker/index.html)
- [Wazuh Troubleshooting Guide](https://documentation.wazuh.com/current/user-manual/troubleshooting/index.html)

### Common Commands Reference

```bash
# Navigate to deployment directory
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh/wazuh-docker/single-node

# View all logs (live)
docker compose logs -f

# View specific container logs
docker compose logs wazuh.manager
docker compose logs wazuh.indexer
docker compose logs wazuh.dashboard

# Restart specific service
docker compose restart wazuh.manager

# Check container resource usage
docker stats

# Execute command in manager
docker exec -it single-node-wazuh.manager-1 bash
```

---

**Most issues resolve with:** Wait 3 minutes after deployment, then refresh browser.
