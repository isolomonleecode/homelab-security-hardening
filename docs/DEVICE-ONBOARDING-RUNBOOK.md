# Home SOC: Device Onboarding Runbook

## Overview

This runbook covers adding/removing/managing devices in your home Security Operations Center (SOC) monitoring infrastructure.

**Architecture:**
- **Centralized Monitoring Stack:** Raspberry Pi (192.168.0.19)
  - Loki (logs aggregation)
  - Prometheus (metrics collection)
  - Grafana (visualization)
- **Distributed Agents:** Each monitored device runs:
  - Promtail (ships logs to Loki)
  - node_exporter (exposes metrics to Prometheus)

---

## Prerequisites for New Devices

Before adding a device to monitoring, ensure:

### 1. SSH Access Configured

**From capcorp9000 (your command center):**

```bash
# Generate SSH key if you haven't already
ssh-keygen -t ed25519 -C "homelab-monitoring"

# Copy public key to target device
ssh-copy-id ssjlox@<TARGET_IP>

# Test passwordless SSH
ssh ssjlox@<TARGET_IP> "echo 'SSH working'"
```

### 2. Docker Installed (for Linux/macOS)

**For Arch-based systems (CachyOS, Garuda):**
```bash
sudo pacman -S docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

**For Debian/Ubuntu:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

### 3. Firewall Configuration

Monitoring requires these ports open to LAN (192.168.0.0/24):
- **Port 9100** - node_exporter (metrics)
- **Port 9080** - Promtail (logs - optional, for debugging)

**For firewalld (CachyOS, Garuda, RHEL-based):**
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.0/24" port port="9100" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.0/24" port port="9080" protocol="tcp" accept'
sudo firewall-cmd --reload
```

**For UFW (Ubuntu, Debian):**
```bash
sudo ufw allow from 192.168.0.0/24 to any port 9100 proto tcp comment 'node_exporter'
sudo ufw allow from 192.168.0.0/24 to any port 9080 proto tcp comment 'promtail'
```

---

## Adding a New Linux Device

### Step 1: Identify Device Details

```bash
# Device information
IP_ADDRESS="192.168.0.XXX"
HOSTNAME="device-name"  # e.g., cachyos-1, workstation-2
USERNAME="ssjlox"       # SSH user
```

### Step 2: Create Promtail Configuration

```bash
cd /run/media/ssjlox/gamer/homelab-security-hardening

# Create config from template
sed "s/HOSTNAME_PLACEHOLDER/${HOSTNAME}/g" \
  configs/promtail/linux-workstation-template.yml > \
  configs/promtail/${HOSTNAME}-promtail-config.yml
```

### Step 3: Deploy Promtail

```bash
# Create directories on target
ssh ${USERNAME}@${IP_ADDRESS} "mkdir -p ~/monitoring/promtail"

# Copy config
scp configs/promtail/${HOSTNAME}-promtail-config.yml \
  ${USERNAME}@${IP_ADDRESS}:~/monitoring/promtail/config.yml

# Create positions file
ssh ${USERNAME}@${IP_ADDRESS} "touch ~/monitoring/promtail/positions.yaml"

# Deploy Promtail container
ssh ${USERNAME}@${IP_ADDRESS} "docker run -d \
  --name promtail-${HOSTNAME} \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /var/log/journal:/var/log/journal:ro \
  -v /run/log/journal:/run/log/journal:ro \
  -v /etc/machine-id:/etc/machine-id:ro \
  -v ~/monitoring/promtail/config.yml:/etc/promtail/config.yml:ro \
  -v ~/monitoring/promtail/positions.yaml:/tmp/positions.yaml \
  -p 9080:9080 \
  grafana/promtail:latest \
  -config.file=/etc/promtail/config.yml"
```

### Step 4: Deploy node_exporter

```bash
ssh ${USERNAME}@${IP_ADDRESS} "docker run -d \
  --name node-exporter-${HOSTNAME} \
  --restart unless-stopped \
  --net=host \
  --pid=host \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  quay.io/prometheus/node-exporter:latest \
  --path.procfs=/host/proc \
  --path.sysfs=/host/sys \
  --path.rootfs=/rootfs \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)(\$|/)'"
```

### Step 5: Verify Deployment

```bash
# Check containers are running
ssh ${USERNAME}@${IP_ADDRESS} "docker ps | grep -E '(promtail|node-exporter)'"

# Test node_exporter endpoint
ssh ${USERNAME}@${IP_ADDRESS} "curl -s http://localhost:9100/metrics | head -5"

# Check logs appearing in Loki (wait 30 seconds first)
ssh automation@100.112.203.63 "curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq -r '.data[]' | grep ${HOSTNAME}"
```

### Step 6: Add to Prometheus

```bash
# SSH to Raspberry Pi
ssh automation@100.112.203.63

# Edit Prometheus config
nano /home/automation/docker/loki-stack/prometheus.yml

# Add new target under 'node' job:
#      - targets: ['<IP_ADDRESS>:9100']
#        labels:
#          instance: '<HOSTNAME>'
#          hostname: '<HOSTNAME>'

# Reload Prometheus
docker exec prometheus kill -HUP 1

# Verify target is scraped
curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.hostname=="<HOSTNAME>") | {health: .health}'
```

### Step 7: Verify in Grafana

1. Open Grafana: `http://192.168.0.19:3000`
2. Go to Explore → Select Loki
3. Query: `{hostname="<HOSTNAME>"}`
4. Should see logs from the new device
5. Switch to Prometheus data source
6. Query: `node_uname_info{hostname="<HOSTNAME>"}`
7. Should see system metrics

---

## Adding a macOS Device

### Step 1: Install Grafana Agent

```bash
# On the macOS device
brew install grafana-agent

# Or download from: https://github.com/grafana/agent/releases
```

### Step 2: Configure Grafana Agent

Create `/opt/homebrew/etc/grafana-agent/config.yml`:

```yaml
server:
  log_level: info

metrics:
  wal_directory: /opt/homebrew/var/lib/grafana-agent
  global:
    scrape_interval: 15s
    remote_write:
      - url: http://192.168.0.19:9090/api/v1/write
  configs:
    - name: macos-metrics
      scrape_configs:
        - job_name: 'node'
          static_configs:
            - targets: ['localhost:12345']
              labels:
                hostname: 'macbook-hostname'

integrations:
  node_exporter:
    enabled: true
    enabled_collectors:
      - cpu
      - disk
      - filesystem
      - loadavg
      - memory
      - network

logs:
  configs:
    - name: macos-logs
      clients:
        - url: http://192.168.0.19:3100/loki/api/v1/push
      positions:
        filename: /opt/homebrew/var/lib/grafana-agent/positions.yaml
      scrape_configs:
        - job_name: system
          static_configs:
            - targets: ['localhost']
              labels:
                job: 'system'
                hostname: 'macbook-hostname'
                __path__: /var/log/system.log
```

### Step 3: Start Grafana Agent

```bash
brew services start grafana-agent

# Verify
brew services list | grep grafana-agent
```

---

## Adding a Windows Device

### Step 1: Download Grafana Agent

1. Download Windows installer: https://github.com/grafana/agent/releases
2. Install as Windows service

### Step 2: Configure Grafana Agent

Create `C:\Program Files\Grafana Agent\config.yml`:

```yaml
server:
  log_level: info

metrics:
  wal_directory: 'C:/ProgramData/Grafana Agent'
  global:
    scrape_interval: 15s
    remote_write:
      - url: http://192.168.0.19:9090/api/v1/write
  configs:
    - name: windows-metrics
      scrape_configs:
        - job_name: 'windows'
          static_configs:
            - targets: ['localhost:12345']
              labels:
                hostname: 'windows-hostname'

integrations:
  windows_exporter:
    enabled: true
    enabled_collectors:
      - cpu
      - cs
      - logical_disk
      - net
      - os
      - system

logs:
  configs:
    - name: windows-logs
      clients:
        - url: http://192.168.0.19:3100/loki/api/v1/push
      positions:
        filename: 'C:/ProgramData/Grafana Agent/positions.yaml'
      scrape_configs:
        - job_name: windows-events
          windows_events:
            use_incoming_timestamp: true
            eventlog_name: "Security"
            labels:
              job: 'windows-security'
              hostname: 'windows-hostname'
          relabel_configs:
            - source_labels: ['event_id']
              target_label: 'event_id'
```

### Step 3: Start Service

```powershell
# Start Grafana Agent service
Start-Service "Grafana Agent"

# Verify
Get-Service "Grafana Agent"
```

### Step 4: Configure Windows Firewall

```powershell
# Allow Prometheus to scrape metrics
New-NetFirewallRule -DisplayName "Grafana Agent Metrics" `
  -Direction Inbound `
  -LocalPort 12345 `
  -Protocol TCP `
  -Action Allow `
  -RemoteAddress 192.168.0.0/24
```

---

## Removing a Device from Monitoring

### Step 1: Stop Containers (Linux)

```bash
ssh ${USERNAME}@${IP_ADDRESS} "docker stop promtail-${HOSTNAME} node-exporter-${HOSTNAME}"
ssh ${USERNAME}@${IP_ADDRESS} "docker rm promtail-${HOSTNAME} node-exporter-${HOSTNAME}"
```

### Step 2: Remove from Prometheus

```bash
ssh automation@100.112.203.63
nano /home/automation/docker/loki-stack/prometheus.yml

# Remove the target entry for the device
# Reload Prometheus
docker exec prometheus kill -HUP 1
```

### Step 3: Clean Up Configs

```bash
cd /run/media/ssjlox/gamer/homelab-security-hardening
rm configs/promtail/${HOSTNAME}-promtail-config.yml
```

---

## Troubleshooting

### Logs Not Appearing in Loki

```bash
# Check Promtail container logs
ssh ${USERNAME}@${IP_ADDRESS} "docker logs promtail-${HOSTNAME} --tail 50"

# Common issues:
# 1. Network connectivity to Loki
ssh ${USERNAME}@${IP_ADDRESS} "curl -v http://192.168.0.19:3100/ready"

# 2. Promtail config syntax error
ssh ${USERNAME}@${IP_ADDRESS} "docker exec promtail-${HOSTNAME} cat /etc/promtail/config.yml"

# 3. Check Loki is receiving data
ssh automation@100.112.203.63 "docker logs loki --tail 50 | grep 'POST /loki/api/v1/push'"
```

### Metrics Not Appearing in Prometheus

```bash
# Check node_exporter is running
ssh ${USERNAME}@${IP_ADDRESS} "curl -s http://localhost:9100/metrics | head"

# Check Prometheus can reach node_exporter
ssh automation@100.112.203.63 "curl -s http://<IP_ADDRESS>:9100/metrics | head"

# If "no route to host" - firewall issue
ssh ${USERNAME}@${IP_ADDRESS} "sudo firewall-cmd --list-all"

# Check Prometheus scrape targets
ssh automation@100.112.203.63 "curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.hostname==\"${HOSTNAME}\")'"
```

### Container Restart Loops

```bash
# Check container logs
ssh ${USERNAME}@${IP_ADDRESS} "docker logs promtail-${HOSTNAME}"

# Common issues:
# 1. Config file permissions
ssh ${USERNAME}@${IP_ADDRESS} "ls -la ~/monitoring/promtail/"

# 2. Port already in use
ssh ${USERNAME}@${IP_ADDRESS} "sudo netstat -tulpn | grep 9080"

# 3. Docker socket permissions
ssh ${USERNAME}@${IP_ADDRESS} "ls -la /var/run/docker.sock"
```

---

## Bulk Operations

### Check Status of All Devices

```bash
#!/bin/bash
# check-all-monitoring.sh

declare -A HOSTS
HOSTS["192.168.0.19"]="sweetrpi-desktop"
HOSTS["192.168.0.51"]="unraid-server"
HOSTS["192.168.0.52"]="capcorp9000"
HOSTS["192.168.0.13"]="cachyos-1"
HOSTS["192.168.0.95"]="cachyos-2"
HOSTS["192.168.0.119"]="cachyos-3"
HOSTS["192.168.0.202"]="garuda-xfce"

echo "Device Status Report"
echo "===================="
echo ""

for IP in "${!HOSTS[@]}"; do
    HOSTNAME="${HOSTS[$IP]}"
    echo -n "$HOSTNAME ($IP): "

    if ping -c 1 -W 1 $IP >/dev/null 2>&1; then
        echo -n "ONLINE - "

        # Check if in Loki
        IN_LOKI=$(ssh automation@100.112.203.63 "curl -s 'http://localhost:3100/loki/api/v1/label/hostname/values' | jq -r '.data[]' | grep -c $HOSTNAME" || echo "0")

        # Check if in Prometheus
        IN_PROM=$(ssh automation@100.112.203.63 "curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.hostname==\"$HOSTNAME\") | .health' | grep -c up" || echo "0")

        echo "Loki: $([ $IN_LOKI -gt 0 ] && echo '✅' || echo '❌') Prometheus: $([ $IN_PROM -gt 0 ] && echo '✅' || echo '❌')"
    else
        echo "OFFLINE"
    fi
done
```

### Update All Promtail Configs

```bash
#!/bin/bash
# update-all-promtail.sh
# Use when you update the template and want to push to all devices

for IP in 13 95 119 202; do
    HOSTNAME=$(ssh ssjlox@192.168.0.$IP "hostname" 2>/dev/null)
    if [ ! -z "$HOSTNAME" ]; then
        echo "Updating $HOSTNAME..."
        sed "s/HOSTNAME_PLACEHOLDER/${HOSTNAME}/g" configs/promtail/linux-workstation-template.yml > /tmp/promtail-${HOSTNAME}.yml
        scp /tmp/promtail-${HOSTNAME}.yml ssjlox@192.168.0.$IP:~/monitoring/promtail/config.yml
        ssh ssjlox@192.168.0.$IP "docker restart promtail-${HOSTNAME}"
    fi
done
```

---

## Security Considerations

### Network Segmentation
- All monitoring traffic stays within 192.168.0.0/24 LAN
- Firewall rules restrict access to LAN only
- No external exposure of metrics/logs

### Authentication
- Grafana protected by authentication (configured separately)
- SSH key-based authentication only
- No password authentication for monitoring agents

### Data Retention
- Loki logs: 30 days (configurable in Loki config)
- Prometheus metrics: 15 days (configurable in Prometheus config)
- Adjust based on disk space and compliance needs

### Sensitive Data
- Logs may contain sensitive information
- Review log pipelines to exclude secrets
- Consider encrypting Loki storage
- Implement Grafana RBAC for multi-user access

---

## Interview Talking Points

### Architecture Design
*"I implemented a centralized logging and metrics infrastructure using Loki and Prometheus. This mirrors enterprise SIEM architectures where you have a central data lake with distributed collection agents. The design is horizontally scalable - I can add new devices without reconfiguring the central stack."*

### Security Event Detection
*"My Promtail configs use regex matching to extract security-relevant events from systemd journal logs. I'm monitoring SSH failed logins, sudo privilege escalations, and authentication failures across all devices. The LogQL queries allow me to correlate events across the fleet - for example, detecting if the same source IP is brute-forcing multiple hosts."*

### Multi-OS Support
*"I deployed monitoring across Linux (Arch-based and Debian), macOS, and Windows. Each OS requires different approaches - Docker containers for Linux, Grafana Agent as a Homebrew service on macOS, and Windows service with Event Log integration. This demonstrates understanding of OS-specific security logging mechanisms."*

### Automation & DevOps
*"I created deployment scripts that are idempotent and handle offline devices gracefully. The template-based configuration system allows me to onboard new devices in under 5 minutes. This follows infrastructure-as-code principles and would scale to hundreds of endpoints in an enterprise environment."*

### Incident Response
*"With centralized logging, I can quickly investigate security incidents. For example, if I see a failed login on one device, I can query Loki for that source IP across all devices to see if it's a coordinated attack. The time-series metrics let me establish baselines and detect anomalies in CPU, network, or process behavior."*

---

## Quick Reference Commands

### Common LogQL Queries
```
# All logs from a specific host
{hostname="cachyos-1"}

# SSH failed logins across all hosts
{syslog_identifier="sshd"} |~ "(?i)failed|connection closed.*preauth"

# Container errors from Unraid
{hostname="unraid-server", job="docker"} |~ "(?i)error|fatal"

# Sudo commands from a specific user
{syslog_identifier="sudo"} |= "COMMAND" |= "user=ssjlox"
```

### Common PromQL Queries
```
# CPU usage by host
100 - (avg by (hostname) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage by host
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage by host and mount point
100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)

# Network traffic by host
rate(node_network_receive_bytes_total[5m])
```

---

## Maintenance Tasks

### Weekly
- [ ] Check all devices are reporting to Loki/Prometheus
- [ ] Review Grafana dashboards for anomalies
- [ ] Check disk space on Raspberry Pi (Loki/Prometheus storage)

### Monthly
- [ ] Update Promtail/node_exporter/Grafana Agent images
- [ ] Review and prune old logs/metrics if disk space low
- [ ] Test incident response playbooks

### Quarterly
- [ ] Review and update firewall rules
- [ ] Audit which devices are being monitored
- [ ] Update documentation with any changes

---

## Resources

- **Loki Documentation:** https://grafana.com/docs/loki/latest/
- **Prometheus Documentation:** https://prometheus.io/docs/
- **Grafana Agent:** https://grafana.com/docs/agent/latest/
- **LogQL Syntax:** https://grafana.com/docs/loki/latest/logql/
- **PromQL Syntax:** https://prometheus.io/docs/prometheus/latest/querying/basics/
