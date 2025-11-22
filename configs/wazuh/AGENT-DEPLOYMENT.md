# Wazuh Agent Deployment Guide

**Author:** Latrent Childs
**Purpose:** Install Wazuh agents on Docker containers for security monitoring
**Estimated Time:** 10 minutes per agent

## Overview

This guide shows how to install Wazuh agents on your Docker containers to enable:
- File Integrity Monitoring (FIM)
- Log collection and analysis
- Vulnerability detection
- Security event correlation
- Compliance monitoring

## Prerequisites

- ✅ Wazuh Manager running (from wazuh-deploy.sh)
- ✅ Access to Wazuh Dashboard (https://YOUR_IP)
- ✅ Docker containers running in your homelab

## Agent Deployment Methods

### Method 1: Add Agent to Existing Container (Recommended for Testing)

This method installs the Wazuh agent **inside** an existing container.

**⚠️ Note:** Changes will be lost when container is recreated. For persistent monitoring, use Method 2.

#### Step 1: Get Wazuh Manager IP

```bash
# Get Wazuh Manager container IP
docker inspect wazuh-manager | grep IPAddress
```

#### Step 2: Install Agent in Target Container

```bash
# Example: Installing in a container named "my-nginx"
docker exec -it my-nginx bash

# Inside the container, install Wazuh agent
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list

apt-get update
WAZUH_MANAGER='172.25.0.2' apt-get install wazuh-agent -y

# Start the agent
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent
```

---

### Method 2: Docker Sidecar Container (Recommended for Production)

This method runs a Wazuh agent as a **separate container** monitoring the host or other containers.

#### Create Agent Container

```bash
# Run Wazuh agent container
docker run -d \
  --name wazuh-agent-01 \
  --hostname my-docker-host \
  --network wazuh_network \
  -e WAZUH_MANAGER='wazuh.manager' \
  -e WAZUH_AGENT_NAME='docker-host-01' \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /:/rootfs:ro \
  wazuh/wazuh-agent:4.9.0
```

**Explanation:**
- `--network wazuh_network`: Connects to Wazuh manager
- `-e WAZUH_MANAGER`: Wazuh manager hostname
- `-e WAZUH_AGENT_NAME`: Friendly agent name
- `-v /var/run/docker.sock`: Monitor Docker events
- `-v /:/rootfs:ro`: Monitor host filesystem (read-only)

---

### Method 3: Agent per Container (Best Security Isolation)

Run one Wazuh agent **for each container** you want to monitor.

#### Docker Compose Integration

Add to your existing `docker-compose.yml`:

```yaml
services:
  # Your existing service
  nginx:
    image: nginx:latest
    container_name: my-nginx
    # ... other config ...

  # Wazuh agent for nginx
  wazuh-agent-nginx:
    image: wazuh/wazuh-agent:4.9.0
    container_name: wazuh-agent-nginx
    hostname: nginx-agent
    environment:
      - WAZUH_MANAGER=wazuh.manager
      - WAZUH_AGENT_NAME=nginx-container
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - nginx-logs:/var/log/nginx:ro  # Monitor nginx logs
    networks:
      - wazuh_network
    depends_on:
      - nginx

networks:
  wazuh_network:
    external: true
```

---

## Quick Start: Monitor 5 Containers (15 minutes)

Let's monitor your most critical containers with **Method 2 (sidecar approach)**.

### 1. List Your Running Containers

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

### 2. Deploy Agent for Container Monitoring

```bash
cd /path/to/homelab-security-hardening/configs/wazuh

# Create agent deployment script
cat > deploy-agents.sh << 'EOF'
#!/bin/bash

# Wazuh Agent Deployment for Multiple Containers
# Deploys one agent to monitor all Docker containers on this host

WAZUH_MANAGER_IP=$(docker inspect wazuh-manager -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
HOST_NAME=$(hostname)

echo "Deploying Wazuh agent for Docker host: $HOST_NAME"
echo "Wazuh Manager IP: $WAZUH_MANAGER_IP"

docker run -d \
  --name wazuh-agent-docker-host \
  --hostname "$HOST_NAME-agent" \
  --network wazuh_network \
  --restart unless-stopped \
  -e WAZUH_MANAGER="$WAZUH_MANAGER_IP" \
  -e WAZUH_AGENT_NAME="docker-host-$HOST_NAME" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /:/rootfs:ro \
  -v /var/log:/var/log:ro \
  wazuh/wazuh-agent:4.9.0

echo ""
echo "✓ Wazuh agent deployed!"
echo ""
echo "Verify in dashboard:"
echo "  1. Open https://YOUR_IP:5601"
echo "  2. Go to 'Agents' section"
echo "  3. Look for agent: docker-host-$HOST_NAME"
EOF

chmod +x deploy-agents.sh
./deploy-agents.sh
```

### 3. Verify Agent Connection

```bash
# Check agent container logs
docker logs wazuh-agent-docker-host

# You should see:
# "INFO: Connected to enrollment service."
# "INFO: Successfully registered agent"
```

### 4. Check Dashboard

1. Open Wazuh Dashboard: `https://YOUR_IP:5601`
2. Login: `admin` / `SecretPassword`
3. Navigate to **"Agents"** in left sidebar
4. You should see your agent with status: **Active**

---

## Agent Configuration Examples

### Enable File Integrity Monitoring (FIM)

Monitor specific directories for unauthorized changes:

```bash
# Edit agent config
docker exec -it wazuh-agent-docker-host vi /var/ossec/etc/ossec.conf
```

Add FIM configuration:

```xml
<syscheck>
  <directories check_all="yes" realtime="yes">/etc</directories>
  <directories check_all="yes" realtime="yes">/root/.ssh</directories>
  <directories check_all="yes">/var/www</directories>

  <!-- Ignore common false positives -->
  <ignore>/etc/mtab</ignore>
  <ignore>/etc/hosts.deny</ignore>
</syscheck>
```

Restart agent:
```bash
docker restart wazuh-agent-docker-host
```

### Monitor Docker Logs

```bash
# Configure agent to collect Docker logs
docker exec -it wazuh-agent-docker-host bash

cat >> /var/ossec/etc/ossec.conf << 'EOF'
<localfile>
  <log_format>syslog</log_format>
  <location>/var/lib/docker/containers/*/*.log</location>
</localfile>
EOF

# Restart agent
/var/ossec/bin/wazuh-control restart
```

---

## Monitoring Multiple Container Types

### Example: Monitor Nginx Container

```bash
docker run -d \
  --name wazuh-agent-nginx \
  --hostname nginx-security-agent \
  --network wazuh_network \
  -e WAZUH_MANAGER='wazuh.manager' \
  -e WAZUH_AGENT_NAME='nginx-web-server' \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v nginx-logs:/monitored-logs:ro \
  wazuh/wazuh-agent:4.9.0
```

### Example: Monitor Database Container

```bash
docker run -d \
  --name wazuh-agent-postgres \
  --hostname postgres-security-agent \
  --network wazuh_network \
  -e WAZUH_MANAGER='wazuh.manager' \
  -e WAZUH_AGENT_NAME='postgres-database' \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v postgres-data:/monitored-data:ro \
  wazuh/wazuh-agent:4.9.0
```

---

## Troubleshooting

### Agent Shows as "Disconnected"

```bash
# Check agent logs
docker logs wazuh-agent-docker-host

# Common issues:
# 1. Network connectivity
docker exec wazuh-agent-docker-host ping wazuh.manager

# 2. Manager IP wrong
docker exec wazuh-agent-docker-host cat /var/ossec/etc/ossec.conf | grep server-ip

# 3. Restart agent
docker restart wazuh-agent-docker-host
```

### Agent Not Appearing in Dashboard

```bash
# Check if agent is registered
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# Force agent registration
docker exec wazuh-agent-docker-host /var/ossec/bin/agent-auth -m wazuh.manager
```

### High Resource Usage

Reduce agent activity:

```bash
docker exec -it wazuh-agent-docker-host vi /var/ossec/etc/ossec.conf

# Increase check intervals
<syscheck>
  <frequency>43200</frequency>  <!-- Check every 12 hours instead of default -->
</syscheck>
```

---

## Quick Reference

### Useful Commands

```bash
# List all Wazuh agents
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# Check agent status
docker exec wazuh-manager /var/ossec/bin/agent_control -i AGENT_ID

# Remove agent
docker exec wazuh-manager /var/ossec/bin/manage_agents -r AGENT_ID

# View agent logs
docker logs wazuh-agent-docker-host -f

# Restart agent
docker restart wazuh-agent-docker-host
```

### Agent States

| State | Meaning |
|-------|---------|
| **Active** | ✅ Agent connected and sending data |
| **Disconnected** | ❌ Agent not communicating with manager |
| **Never connected** | ⚠️ Agent registered but never started |
| **Pending** | ⏳ Agent waiting for manager approval |

---

## Career Impact

After deploying agents, update your documentation:

**LinkedIn Experience Update:**
```
• Deployed Wazuh SIEM agents across 30+ Docker containers for security monitoring
• Configured file integrity monitoring (FIM) detecting unauthorized configuration changes
• Implemented centralized log collection and security event correlation
```

**Resume Talking Points:**
- "Deployed Wazuh agents across containerized infrastructure for real-time threat detection"
- "Configured FIM monitoring critical directories (/etc, /root/.ssh) for intrusion detection"
- "Integrated Wazuh with existing Grafana/Prometheus stack for comprehensive security visibility"

**Interview Preparation:**
Be ready to explain:
1. Why you chose Wazuh (open-source, feature-rich, widely used)
2. How agents communicate with manager (encrypted, port 1514)
3. What you monitor (FIM, logs, vulnerabilities, compliance)
4. How you handle alerts (centralized dashboard, integration with n8n for automation)

---

**Next Steps:** [Security Rules Configuration](SECURITY-RULES.md)
