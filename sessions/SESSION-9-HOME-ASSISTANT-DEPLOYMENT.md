# Session 9: Home Assistant + IoT Integration Deployment

**Date:** November 3, 2025
**Objective:** Deploy Home Assistant on Raspberry Pi with IP camera NVR integration
**Architecture Decision:** Raspberry Pi (vs Media Server)
**Status:** 🔄 IN PROGRESS

---

## Executive Summary

Deploying Home Assistant stack on Raspberry Pi to manage IoT devices and integrate IP NVR (192.168.0.193) for camera viewing. This establishes the foundation for home automation while maintaining security separation from development workloads on the media server.

---

## Architecture Decision: Why Raspberry Pi?

### Decision Matrix

| Factor | Raspberry Pi | Media Server |
|--------|-------------|--------------|
| **Availability** | ✅ 24/7 uptime required | ❌ Powers down when not in use |
| **Security Isolation** | ✅ IoT separated from dev | ❌ IoT near sensitive AI/data |
| **Resource Requirements** | ✅ HA is lightweight | ⚠️ Overkill for basic HA |
| **Network Positioning** | ✅ Already infrastructure hub | ⚠️ AI workload focus |
| **Future VLAN Segmentation** | ✅ Easy IoT isolation | ❌ Complicates network design |

**Decision:** Deploy on Raspberry Pi

**Rationale:**
1. **Always-On Reliability** - Home automation (lights, cameras, automations) requires 24/7 availability
2. **Security Segmentation** - IoT devices (cameras, smart bulbs) are notoriously vulnerable; keep isolated from AI models and development environment
3. **Resource Appropriate** - Pi handles Home Assistant workload efficiently; media server GPU reserved for AI tasks
4. **Infrastructure Hub** - Pi already manages critical services (Pi-hole DNS, Vaultwarden passwords, Grafana monitoring)
5. **Future-Proof** - Easier to implement IoT VLAN segmentation with HA on dedicated infrastructure device

---

## Current Infrastructure Context

### Raspberry Pi (sweetrpi-desktop)
**IP:** 192.168.0.X (LAN), 100.112.203.63 (Tailscale)
**Resources:**
- RAM: 7.6GB total, 5.9GB available ✅
- Storage: 229GB total, 193GB free ✅
- CPU: Sufficient for all current workloads

**Running Services:**
- Pi-hole (DNS + ad-blocking) - LAN-wide
- Vaultwarden (password manager) - Tailscale only
- Caddy (reverse proxy) - HTTPS termination
- Portainer (Docker management)
- Grafana + Prometheus + Loki (monitoring stack)
- SAML lab (Keycloak, Nextcloud, SimpleSAMLphp)

**Security Posture:**
- UFW firewall configured (70% attack surface reduction)
- fail2ban intrusion prevention active
- Tailscale mesh network for secure remote access
- Network segmentation: Tailscale (100.0.0.0/8) + LAN (192.168.0.0/24)

### Media Server
**IP:** 192.168.0.52
**Resources:**
- GPU: AMD Radeon RX 6800/6900 XT (16GB VRAM)
- RAM: 62.62GB
- Storage: High-capacity

**Running Services:**
- LocalAI (GPU-accelerated LLM inference)
- LiteLLM (multi-model proxy)
- Big-AGI (chat UI)
- Open-WebUI (RAG interface)
- Security lab containers (ZAP, CyberChef)

### IP NVR
**IP:** 192.168.0.193
**Purpose:** Network Video Recorder with IP cameras
**Integration:** ONVIF/RTSP streams → Home Assistant

---

## Deployment Architecture

### Container Stack

```
Raspberry Pi (192.168.0.X)
├── homeassistant:8123 (network_mode: host)
│   ├── Web UI for home automation
│   ├── Device discovery (mDNS, SSDP)
│   └── NVR integration (ONVIF/RTSP)
│
├── mosquitto:1883 (MQTT broker)
│   ├── IoT device communication
│   └── Websockets on port 9001
│
└── nodered:1880 (automation flows)
    ├── Visual programming for automations
    └── Advanced integrations
```

### Network Architecture (Current State)

```
Internet
    ↓
Router (192.168.0.1)
    ↓
Flat Network: 192.168.0.0/24
├── Raspberry Pi (.X) - Critical Services + Home Assistant
├── Media Server (.52) - AI/ML workloads
├── IP NVR (.193) - Camera system
├── Workstations (.1-.100)
└── IoT Devices (various)
```

### Firewall Rules (UFW on Raspberry Pi)

**Home Assistant:**
```bash
ufw allow from 192.168.0.0/24 to any port 8123  # LAN access
ufw allow from 100.0.0.0/8 to any port 8123     # Tailscale remote access
```

**MQTT:**
```bash
ufw allow from 192.168.0.0/24 to any port 1883  # IoT devices on LAN
```

**Node-RED:**
```bash
ufw allow from 100.0.0.0/8 to any port 1880     # Tailscale only
```

---

## Deployment Steps

### Phase 1: Preparation ✅

1. **Resource Validation**
```bash
ssh automation@100.112.203.63
free -h      # 5.9GB RAM available ✅
df -h        # 193GB storage free ✅
docker ps    # All services healthy ✅
```

2. **Directory Structure Creation**
```bash
mkdir -p ~/homeassistant/{config,mosquitto/{config,data,log}}
```

**Created:**
- `/home/automation/homeassistant/config/` - Home Assistant configuration
- `/home/automation/homeassistant/mosquitto/` - MQTT broker data

### Phase 2: Docker Compose Configuration ✅

Created `/home/automation/homeassistant/docker-compose.yml`:

```yaml
version: '3.8'

services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: unless-stopped
    privileged: true  # Required for USB devices
    network_mode: host  # Required for device discovery
    environment:
      - TZ=America/Chicago
    volumes:
      - /home/automation/homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro

  mosquitto:
    container_name: mosquitto
    image: eclipse-mosquitto:latest
    restart: unless-stopped
    ports:
      - "1883:1883"  # MQTT
      - "9001:9001"  # WebSockets
    volumes:
      - /home/automation/homeassistant/mosquitto/data:/mosquitto/data
      - /home/automation/homeassistant/mosquitto/config:/mosquitto/config
      - /home/automation/homeassistant/mosquitto/log:/mosquitto/log
    command: mosquitto -c /mosquitto-no-auth.conf
    networks:
      - homeassistant-network

  nodered:
    container_name: nodered
    image: nodered/node-red:latest
    restart: unless-stopped
    ports:
      - "1880:1880"
    volumes:
      - nodered_data:/data
    environment:
      - TZ=America/Chicago
    networks:
      - homeassistant-network

volumes:
  nodered_data:
    driver: local

networks:
  homeassistant-network:
    driver: bridge
```

**Key Configuration Decisions:**

**1. Home Assistant: `network_mode: host`**
- **Why:** Enables device discovery (mDNS, SSDP) and simplifies NVR integration
- **Trade-off:** Bypasses Docker network isolation
- **Mitigation:** UFW firewall rules provide host-level protection

**2. Home Assistant: `privileged: true`**
- **Why:** Required for USB devices (Zigbee/Z-Wave dongles if added later)
- **Current:** No USB devices, but prepared for future expansion
- **Security:** Acceptable risk on dedicated infrastructure device

**3. Mosquitto: No authentication (initial)**
- **Why:** Simplifies initial setup and testing
- **Plan:** Add authentication in Phase 2 after confirming functionality
- **Access:** LAN-only via UFW rules

### Phase 3: Firewall Configuration ✅

```bash
ssh automation@100.112.203.63

# Home Assistant access
sudo ufw allow from 192.168.0.0/24 to any port 8123 comment 'Home Assistant - LAN'
sudo ufw allow from 100.0.0.0/8 to any port 8123 comment 'Home Assistant - Tailscale'

# MQTT for IoT devices
sudo ufw allow from 192.168.0.0/24 to any port 1883 comment 'MQTT - LAN IoT devices'

# Node-RED admin interface
sudo ufw allow from 100.0.0.0/8 to any port 1880 comment 'Node-RED - Tailscale'

# Verify
sudo ufw status numbered
```

**Rules Added:**
- [12] 8123 from 192.168.0.0/24 ✅
- [13] 8123 from 100.0.0.0/8 ✅
- [14] 1883 from 192.168.0.0/24 ✅
- [15] 1880 from 100.0.0.0/8 ✅

### Phase 4: Container Deployment 🔄

```bash
cd ~/homeassistant
docker compose pull    # Downloading images (~1GB+ total)
docker compose up -d   # Pending image download completion
```

**Status:** Images downloading (Home Assistant, Mosquitto, Node-RED)

### Phase 5: Initial Configuration (PENDING)

Once containers start:

1. **Access Home Assistant:**
   - http://192.168.0.X:8123 (from LAN)
   - http://100.112.203.63:8123 (via Tailscale)

2. **Complete Onboarding:**
   - Create admin account
   - Set location/timezone
   - Enable device discovery

3. **Configure MQTT Integration:**
   - Navigate to Configuration → Integrations
   - Add MQTT integration
   - Host: `mosquitto`, Port: `1883`

4. **Test Node-RED:**
   - http://100.112.203.63:1880 (Tailscale only)
   - Install Home Assistant nodes
   - Create test automation flow

### Phase 6: NVR Integration (NEXT)

**IP NVR Details:**
- **IP Address:** 192.168.0.193
- **Protocols:** ONVIF, RTSP
- **Network:** Same LAN as Raspberry Pi

**Integration Methods:**

**Option A: ONVIF (Recommended)**
```yaml
# configuration.yaml
camera:
  - platform: onvif
    host: 192.168.0.193
    port: 80
    username: !secret nvr_username
    password: !secret nvr_password
    scan_interval: 10
```

**Option B: Generic Camera (RTSP Stream)**
```yaml
# configuration.yaml
camera:
  - platform: ffmpeg
    name: Front Door Camera
    input: rtsp://username:password@192.168.0.193:554/stream1
```

**Option C: MJPEG Snapshots**
```yaml
# configuration.yaml
camera:
  - platform: generic
    name: Garage Camera
    still_image_url: http://192.168.0.193/snapshot.jpg
    stream_source: rtsp://192.168.0.193:554/stream1
    username: !secret nvr_username
    password: !secret nvr_password
```

**Steps:**
1. Identify NVR type and supported protocols
2. Test RTSP stream URL with VLC: `rtsp://192.168.0.193:554/`
3. Add camera integration to Home Assistant configuration
4. Create dashboard with camera entities
5. Test motion detection triggers

---

## Security Considerations

### IoT Device Threat Model

**Risk Profile:**
- IP cameras: Outdated firmware, weak default passwords, known vulnerabilities
- Smart devices: Poor encryption, cloud dependencies, privacy concerns
- NVR: Potential backdoors, unpatched vulnerabilities

**Current Mitigations:**
- ✅ Firewall rules restricting access to HA ports
- ✅ Tailscale mesh for secure remote access
- ✅ Separate network segments (Tailscale vs LAN)
- ⚠️ IoT devices on same LAN as trusted devices (future improvement)

### Phase 2: Enhanced Security (Upcoming)

**1. VLAN Segmentation**
```
Router Configuration:
├── VLAN 10: Critical Services (192.168.10.0/24)
│   ├── Raspberry Pi
│   └── Media Server
│
├── VLAN 20: IoT Devices (192.168.20.0/24)
│   ├── IP NVR → 192.168.20.193
│   ├── Smart bulbs/switches
│   └── Sensors
│
└── VLAN 30: Trusted Devices (192.168.30.0/24)
    ├── Workstations
    └── Phones/tablets
```

**Firewall Rules (Inter-VLAN):**
```
IoT (VLAN 20) → Critical Services (VLAN 10): ALLOW (HA only)
IoT (VLAN 20) → Trusted Devices (VLAN 30): DENY
IoT (VLAN 20) → Internet: DENY (except approved services)
```

**2. MQTT Authentication**
```bash
# Generate mosquitto password file
docker exec mosquitto mosquitto_passwd -c /mosquitto/config/passwd homeassistant
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd iot_device <password>

# Update mosquitto.conf
allow_anonymous false
password_file /mosquitto/config/passwd
```

**3. Home Assistant Authentication**
- Enable MFA for admin account
- Create separate users for family members
- Configure trusted networks policy
- Enable "Failed Login Attempts" automation

**4. NVR Hardening**
- Change default credentials (if not already done)
- Disable UPnP
- Update firmware to latest version
- Disable cloud access (keep local-only)
- Store credentials in Vaultwarden

**5. Network Monitoring**
```yaml
# Grafana Dashboard: IoT Network Traffic
Metrics to monitor:
- Camera bandwidth usage (detect unauthorized streams)
- MQTT message rate (detect anomalies)
- Home Assistant API calls (detect brute force)
- Firewall denied connections (detect scanning)
```

---

## Future Enhancements

### Phase 2: Basic Automations (Week 1-2)
- [ ] Motion detection alerts (cameras → mobile)
- [ ] Lighting automations (presence-based)
- [ ] Environmental monitoring (temperature, humidity)
- [ ] MQTT integration for smart devices

### Phase 3: Advanced Features (Month 1)
- [ ] Frigate NVR (AI object detection) - Consider deploying on Media Server for GPU acceleration
- [ ] Voice assistant integration (optional)
- [ ] Energy monitoring dashboard
- [ ] Backup automation for HA config

### Phase 4: IoT VLAN Migration (Month 2-3)
- [ ] Research router VLAN capabilities
- [ ] Plan IP address migration (192.168.0.X → 192.168.20.X)
- [ ] Document all IoT device network requirements
- [ ] Test HA connectivity after VLAN segmentation
- [ ] Migrate NVR to IoT VLAN
- [ ] Implement inter-VLAN firewall rules

### Phase 5: AI-Powered Features (Future)
- [ ] Frigate NVR on Media Server (GPU object detection)
- [ ] AI-based anomaly detection in camera feeds
- [ ] Predictive automations using historical data
- [ ] Integration with LocalAI for natural language automations

---

## Frigate NVR Consideration

**Frigate:** Advanced NVR with AI-powered object detection (person, car, animal recognition)

**Deployment Decision:**

| Factor | Raspberry Pi | Media Server |
|--------|-------------|--------------|
| GPU Required | ❌ No dedicated GPU | ✅ AMD RX 6800/6900 XT |
| AI Performance | ⚠️ CPU-based (slow) | ✅ GPU-accelerated (fast) |
| Resource Impact | ❌ High CPU load | ✅ Underutilized GPU capacity |
| Always-On | ✅ Already 24/7 | ❌ Powers down |

**Recommended Approach:**
1. **Phase 1 (Current):** Basic Home Assistant + ONVIF camera viewing on Raspberry Pi
2. **Phase 2 (If AI needed):** Deploy Frigate on Media Server, configure it to send events to Home Assistant on Pi
3. **Architecture:** Pi handles automations, Media Server handles AI detection

**Hybrid Setup:**
```
Media Server (192.168.0.52)
└── Frigate NVR (port 5000)
    ├── Processes camera streams with GPU
    ├── AI object detection (person, vehicle)
    └── MQTT events → Raspberry Pi

Raspberry Pi (192.168.0.X)
└── Home Assistant (port 8123)
    ├── Receives Frigate MQTT events
    ├── Triggers automations
    └── Dashboard with Frigate camera entities
```

---

## Rollback Plan

**If Issues Arise:**

1. **Stop Containers:**
```bash
ssh automation@100.112.203.63
cd ~/homeassistant
docker compose down
```

2. **Remove Firewall Rules:**
```bash
sudo ufw status numbered  # Note rule numbers for HA ports
sudo ufw delete <rule_number>  # For each HA rule
```

3. **Preserve Configuration:**
```bash
# Config persisted in volumes, can restart anytime:
docker compose up -d
```

4. **Alternative: Deploy on Media Server:**
```bash
# Copy docker-compose.yml to media server
scp ~/homeassistant/docker-compose.yml ssjlox@192.168.0.52:~/homeassistant/
# Adjust firewall rules on media server
# Start containers there instead
```

---

## Access Information

Once deployed:

**Home Assistant:**
- LAN: http://192.168.0.X:8123
- Tailscale: http://100.112.203.63:8123

**Node-RED:**
- Tailscale only: http://100.112.203.63:1880

**MQTT Broker:**
- Host: 192.168.0.X
- Port: 1883
- Websockets: 9001
- Auth: None (initial setup)

**IP NVR:**
- Current: http://192.168.0.193
- Future (after VLAN): http://192.168.20.193

---

## Documentation & Portfolio Value

This deployment demonstrates:

1. **Architecture Decision-Making:** Evaluated Pi vs Media Server based on requirements
2. **Security-First Design:** Firewall rules, network segmentation planning, threat modeling
3. **Infrastructure-as-Code:** Docker Compose configuration management
4. **Scalability Planning:** VLAN segmentation roadmap for future growth
5. **Hybrid Deployment:** Leveraging multiple systems for optimal resource usage (Pi for HA, Media Server for AI)

**Session Documentation:**
- Architecture decision matrix
- Security threat model for IoT devices
- Network segmentation roadmap
- Deployment automation (Docker Compose)
- Integration guide for NVR

**Skills Demonstrated:**
- Home automation platform deployment
- IoT security considerations
- Network architecture design
- Container orchestration
- Firewall configuration
- Multi-service integration

---

## Current Status

**Completed:**
- ✅ Architecture decision (Pi vs Media Server)
- ✅ Resource validation on Raspberry Pi
- ✅ Directory structure creation
- ✅ Docker Compose configuration
- ✅ UFW firewall rules added
- 🔄 Container images downloading

**Next Steps:**
1. Complete image download (in progress)
2. Start containers: `docker compose up -d`
3. Access Home Assistant web UI
4. Complete initial onboarding
5. Integrate IP NVR at 192.168.0.193
6. Create camera dashboard
7. Test camera streams and motion detection
8. Document NVR integration method

**ETA:** Initial deployment complete within 30 minutes (pending download)

---

## Session Continuation

This session will continue with:
1. Container startup verification
2. Home Assistant initial configuration
3. NVR integration testing
4. Camera dashboard creation
5. Basic automation examples
6. Documentation of NVR integration method

Session documentation updated in real-time at:
`/run/media/ssjlox/gamer/homelab-security-hardening/sessions/SESSION-9-HOME-ASSISTANT-DEPLOYMENT.md`
