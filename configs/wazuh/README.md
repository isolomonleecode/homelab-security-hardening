# Wazuh SIEM Deployment Guide

**Author:** Latrent Childs
**Date:** November 19, 2025
**Purpose:** Enterprise-grade SIEM for security event detection and incident response
**Integration:** Complements existing Grafana/Loki/Prometheus monitoring stack

## Overview

This deployment adds **Wazuh SIEM** to the existing Home SOC infrastructure, providing:
- **File Integrity Monitoring (FIM)** - Detect unauthorized file changes
- **Vulnerability Detection** - Automated CVE scanning
- **Security Event Correlation** - Advanced threat detection rules
- **Compliance Monitoring** - PCI-DSS, GDPR, HIPAA compliance checks
- **Active Response** - Automated threat mitigation
- **Incident Management** - Centralized security event tracking

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Wazuh SIEM Stack                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Wazuh      │  │   Wazuh      │  │   Wazuh      │     │
│  │  Dashboard   │◄─┤   Indexer    │◄─┤   Manager    │     │
│  │  (Web UI)    │  │ (OpenSearch) │  │ (Analytics)  │     │
│  │  Port: 5601  │  │  Port: 9200  │  │  Port: 55000 │     │
│  └──────────────┘  └──────────────┘  └───────▲──────┘     │
│                                               │            │
└───────────────────────────────────────────────┼────────────┘
                                                │
                        ┌───────────────────────┴────────┐
                        │                                │
                   ┌────▼─────┐                   ┌──────▼───┐
                   │  Docker  │                   │  Docker  │
                   │Container │                   │Container │
                   │ + Agent  │                   │ + Agent  │
                   └──────────┘                   └──────────┘
```

## Quick Start (5 minutes)

### 1. Deploy Wazuh Stack

```bash
cd /path/to/homelab-security-hardening/configs/wazuh
docker-compose up -d
```

### 2. Verify Services

```bash
# Check all containers are running
docker-compose ps

# Check Wazuh Manager logs
docker logs wazuh-manager

# Check Dashboard logs
docker logs wazuh-dashboard
```

### 3. Access Dashboard

1. Open browser: `http://YOUR_SERVER_IP:5601`
2. Login credentials:
   - **Username:** `admin`
   - **Password:** `SecretPassword` (change this!)

### 4. Verify API Connection

The dashboard should automatically connect to the Wazuh Manager API. You should see:
- "Wazuh API" status: ✅ Connected
- Agent summary showing "0 active agents" (we'll add agents next)

## Security Configuration

### ⚠️ IMPORTANT: Change Default Passwords

Before deploying in production, update these passwords in `docker-compose.yml`:

1. **Indexer Password:**
   ```yaml
   INDEXER_PASSWORD=SecretPassword  # Change this line
   ```

2. **API Password:**
   ```yaml
   API_PASSWORD=MyS3cr37P450r.*-    # Change this line
   ```

3. **Dashboard Password:**
   ```yaml
   DASHBOARD_PASSWORD=kibanaserver  # Change this line
   ```

### Generate Strong Passwords

```bash
# Generate random passwords
openssl rand -base64 32
```

## Resource Requirements

**Minimum (Testing):**
- RAM: 4GB
- CPU: 2 cores
- Disk: 10GB

**Recommended (Production):**
- RAM: 8GB (adjust `OPENSEARCH_JAVA_OPTS` in docker-compose.yml)
- CPU: 4 cores
- Disk: 50GB+

### Adjust Memory Allocation

In `docker-compose.yml`, modify the indexer memory:

```yaml
environment:
  - "OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g"  # Change 1g to 2g for better performance
```

## Integration with Existing Monitoring

This Wazuh deployment **complements** your existing Grafana/Loki/Prometheus stack:

| Tool | Purpose | Overlap |
|------|---------|---------|
| **Grafana** | Metrics visualization, infrastructure health | General monitoring |
| **Loki** | Log aggregation | Application/container logs |
| **Prometheus** | Metrics collection | System metrics |
| **Wazuh** | **Security-focused SIEM**, threat detection, compliance | Security events, vulnerabilities |

**Key Differences:**
- Grafana/Loki/Prometheus: Infrastructure monitoring
- Wazuh: **Security monitoring** (intrusions, malware, compliance)

## Next Steps

Once Wazuh is running, proceed to:

1. **[Agent Deployment Guide](AGENT-DEPLOYMENT.md)** - Install agents on Docker containers
2. **[Security Rules Configuration](SECURITY-RULES.md)** - Configure custom detection rules
3. **[Dashboard Customization](DASHBOARD-SETUP.md)** - Create security dashboards

## Troubleshooting

### Container Won't Start

```bash
# Check container logs
docker logs wazuh-manager
docker logs wazuh-indexer
docker logs wazuh-dashboard

# Check resource usage
docker stats
```

### Dashboard Shows "Unable to connect to Wazuh API"

1. Check Wazuh Manager is running: `docker ps | grep wazuh-manager`
2. Check API credentials match in docker-compose.yml
3. Restart dashboard: `docker restart wazuh-dashboard`

### High Memory Usage

Reduce OpenSearch memory allocation:
```yaml
- "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m"  # Minimum viable
```

## Commands Reference

```bash
# Start Wazuh stack
docker-compose up -d

# Stop Wazuh stack
docker-compose down

# View logs
docker-compose logs -f

# Restart specific service
docker-compose restart wazuh.dashboard

# Remove all data (WARNING: destructive)
docker-compose down -v
```

## Documentation Links

- [Official Wazuh Docker Documentation](https://documentation.wazuh.com/current/deployment-options/docker/index.html)
- [Wazuh Ruleset Documentation](https://documentation.wazuh.com/current/user-manual/ruleset/index.html)
- [Agent Installation Guide](https://documentation.wazuh.com/current/installation-guide/wazuh-agent/index.html)

## Career Impact

**LinkedIn Updates After Deployment:**
- ✅ Add "Wazuh" to Skills section (position 18)
- ✅ Update Experience: "Currently implementing Wazuh" → "Deployed Wazuh SIEM"
- ✅ Add achievement: "Deployed Wazuh SIEM monitoring X containers with custom security rules"
- ✅ Screenshot Wazuh dashboard for LinkedIn Featured section

**Resume Talking Points:**
- "Deployed open-source Wazuh SIEM for enterprise-grade security monitoring"
- "Configured file integrity monitoring and vulnerability detection across 30+ containers"
- "Integrated Wazuh with existing Grafana/Prometheus infrastructure for comprehensive visibility"

---

**Status:** Ready for deployment
**Estimated Setup Time:** 30 minutes
**Next Session:** Agent deployment and rule configuration
