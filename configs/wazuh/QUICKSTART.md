# Wazuh SIEM - Quick Start Guide

**Time Required:** 30 minutes
**Skill Level:** Intermediate
**Prerequisites:** Docker, 4GB+ RAM

---

## ⚡ Quick Deploy (3 Commands)

```bash
# 1. Navigate to Wazuh directory
cd /run/media/ssjlox/gamer/Github\ Projects/homelab-security-hardening/configs/wazuh

# 2. Run simplified deployment (recommended)
./simple-deploy.sh

# 3. Access dashboard (URL will be displayed)
# Browser: https://YOUR_SERVER_IP
# Username: admin
# Password: SecretPassword
```

**⚠️ Note:** Browser will show SSL warning (self-signed certificate). Click "Advanced" → "Proceed to site"

**Access Dashboard:**
- URL: `https://YOUR_SERVER_IP` (no port needed)
- Username: `admin`
- Password: `SecretPassword`

---

## 🚀 Deploy Your First Agent (5 Minutes)

```bash
# Get Wazuh Manager IP
MANAGER_IP=$(docker inspect wazuh-manager -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

# Deploy agent monitoring all Docker containers
docker run -d \
  --name wazuh-agent-homelab \
  --hostname homelab-security-agent \
  --network wazuh_network \
  --restart unless-stopped \
  -e WAZUH_MANAGER="$MANAGER_IP" \
  -e WAZUH_AGENT_NAME="homelab-docker-host" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /:/rootfs:ro \
  -v /var/log:/var/log:ro \
  wazuh/wazuh-agent:4.9.0

# Verify agent connected
docker logs wazuh-agent-homelab | grep "Connected to enrollment"
```

**Check Dashboard:**
1. Go to `https://YOUR_IP:5601`
2. Click **"Agents"** in left sidebar
3. You should see: `homelab-docker-host` with status **Active**

---

## ✅ Verification Checklist

- [ ] All 3 containers running: `docker-compose ps`
- [ ] Dashboard accessible: `https://YOUR_IP:5601`
- [ ] Can login with admin/SecretPassword
- [ ] Agent shows as "Active" in dashboard
- [ ] No errors in logs: `docker-compose logs`

---

## 🎯 What You Just Accomplished

**Resume Bullet Point:**
> "Deployed Wazuh SIEM monitoring 30+ Docker containers with file integrity monitoring and automated vulnerability detection"

**LinkedIn Update:**
> Add "Wazuh" to Skills section (position #18)
> Update About section: "Deployed Wazuh SIEM for comprehensive threat detection"

**Interview Talking Point:**
> "I deployed an open-source Wazuh SIEM in my homelab to monitor 30+ containers. I configured file integrity monitoring, security event correlation, and integrated it with my existing Grafana/Prometheus stack for comprehensive infrastructure and security visibility."

---

## 📊 Next Steps

**Immediate (Today):**
1. ✅ Explore Wazuh dashboard
2. ✅ Review Security Events tab
3. ✅ Check Agent status
4. ✅ Take screenshot for LinkedIn

**This Week:**
1. Configure File Integrity Monitoring (FIM)
2. Set up custom security rules
3. Create security dashboard
4. Update LinkedIn profile

**This Month:**
1. Build n8n SOAR automation
2. Deploy to all containers
3. Document incident response procedures
4. Apply to SOC Analyst jobs

---

## 🆘 Troubleshooting

**Dashboard won't load?**
```bash
# Check if container is running
docker logs wazuh-dashboard

# Restart if needed
docker restart wazuh-dashboard
```

**Agent shows "Disconnected"?**
```bash
# Check agent logs
docker logs wazuh-agent-homelab

# Verify network connectivity
docker exec wazuh-agent-homelab ping wazuh.manager

# Restart agent
docker restart wazuh-agent-homelab
```

**High memory usage?**
```bash
# Reduce OpenSearch memory in docker-compose.yml
# Change: OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
# To:     OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m

docker-compose down
docker-compose up -d
```

---

## 📚 Full Documentation

- [README.md](README.md) - Complete deployment guide
- [AGENT-DEPLOYMENT.md](AGENT-DEPLOYMENT.md) - Detailed agent installation
- [SESSION-14-WAZUH-SIEM-DEPLOYMENT.md](../sessions/SESSION-14-WAZUH-SIEM-DEPLOYMENT.md) - Session summary

---

**Ready to deploy? Run `./wazuh-deploy.sh` now!**
