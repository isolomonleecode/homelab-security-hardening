# Configuration Files

This directory contains infrastructure and service configuration files used in the homelab security hardening project.

## Directory Structure

```
configs/
├── README.md           # This file
├── pihole/             # Pi-hole DNS server configurations
├── docker/             # Docker Compose and container configs
├── nginx/              # Nginx Proxy Manager configurations
└── logging/            # Logging and monitoring configurations
```

## Configuration Categories

### pihole/
Pi-hole DNS server configuration files for local service resolution.

**Files:**
- `04-local-dns.conf` - Custom DNS A records for `.homelab` domain

**Purpose:**
- Maps service hostnames to IP addresses
- Enables friendly DNS names (e.g., `jellyfin.homelab`)
- Persisted in Pi-hole container at `/etc/dnsmasq.d/`

**Usage:**
```bash
# Copy to Pi-hole container
docker cp configs/pihole/04-local-dns.conf pihole:/etc/dnsmasq.d/

# Restart Pi-hole DNS
docker exec pihole pihole restartdns
```

---

### docker/
Docker Compose files and container configuration templates.

**Planned Contents:**
- `docker-compose.yml` - Multi-container orchestration
- `hardened-*.yml` - Hardened container configurations
- `.env.example` - Environment variable templates

**Purpose:**
- Infrastructure as Code (IaC)
- Reproducible deployments
- Security-hardened configurations
- Version control for container definitions

---

### nginx/
Nginx Proxy Manager configuration files.

**Planned Contents:**
- Reverse proxy configurations
- SSL/TLS certificate settings
- Access control lists
- Rate limiting rules

**Purpose:**
- Centralized reverse proxy management
- HTTPS termination
- Access control and authentication
- Security headers and policies

---

### logging/
Centralized logging and monitoring configurations.

**Files:**
- `promtail-pi4-config.yml` - Promtail agent configuration for Pi4

**Purpose:**
- Log aggregation with Loki
- Container log shipping
- Structured logging with labels
- Security event monitoring

**Current Setup:**
- **Loki:** Running on Grafana host (192.168.0.52:3100)
- **Promtail:** Running on Pi4, shipping Docker logs
- **Grafana:** Visualization at http://grafana.homelab.local:8083

---

## Configuration Management Best Practices

### Version Control
- ✅ All configurations stored in Git
- ✅ Sensitive data excluded via .gitignore
- ✅ Use `.example` files for templates with secrets

### Security
- 🔒 Never commit credentials, API keys, or certificates
- 🔒 Use environment variables for secrets
- 🔒 Restrict file permissions (600 for sensitive configs)
- 🔒 Document required secrets in README or `.example` files

### Documentation
- 📝 Comment complex configurations inline
- 📝 Include usage examples
- 📝 Document dependencies and prerequisites
- 📝 Maintain this README with new additions

### Testing
- ✅ Test configurations in isolated environment first
- ✅ Validate syntax before deployment
- ✅ Keep backups of working configurations
- ✅ Document rollback procedures

## How to Use Configurations

### Deploying a Configuration

1. **Review the configuration file:**
   ```bash
   cat configs/<category>/<file>
   ```

2. **Validate syntax** (if applicable):
   ```bash
   # Docker Compose
   docker-compose -f configs/docker/<file> config

   # Nginx
   nginx -t -c configs/nginx/<file>
   ```

3. **Deploy to target system:**
   ```bash
   # Copy to container
   docker cp configs/<file> <container>:<path>

   # Or mount as volume
   docker run -v $(pwd)/configs/<file>:<path>:ro ...
   ```

4. **Restart service to apply:**
   ```bash
   docker restart <container>
   ```

### Creating New Configurations

1. Create file in appropriate subdirectory
2. Add documentation header with:
   - Purpose
   - Dependencies
   - Usage instructions
3. Test thoroughly before committing
4. Update this README
5. Create `.example` version if it contains secrets

## Configuration Templates

### Docker Compose Template
```yaml
version: '3.8'

services:
  service-name:
    image: image:tag
    container_name: service-name
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    read_only: true
    user: "1000:1000"
    networks:
      - internal
    environment:
      - ENV_VAR=${ENV_VAR}
    volumes:
      - ./data:/data:ro

networks:
  internal:
    driver: bridge
```

### Pi-hole DNS Record Template
```conf
# Service: <service-name>
# Description: <purpose>
address=/<hostname>.homelab/<ip-address>
```

### Promtail Configuration Template
```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://<loki-host>:3100/loki/api/v1/push

scrape_configs:
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*.log
```

## Deployment Checklist

Before deploying any configuration:

- [ ] Configuration reviewed and understood
- [ ] Syntax validated
- [ ] Secrets replaced with environment variables
- [ ] Backup of existing configuration created
- [ ] Testing plan defined
- [ ] Rollback procedure documented
- [ ] Change logged in PROGRESS.md

## Troubleshooting

### Configuration not applying
1. Check file permissions
2. Verify correct path in container
3. Restart service/container
4. Check logs: `docker logs <container>`

### Syntax errors
1. Use validation tools specific to config type
2. Check for typos and formatting
3. Compare with working examples
4. Review documentation for config file format

### Secrets exposed
1. Remove from Git history: `git filter-branch` or BFG Repo-Cleaner
2. Rotate compromised credentials immediately
3. Add to .gitignore
4. Use environment variables or secrets management

## Related Documentation

- [Pi-hole DNS Configuration Guide](../docs/03-pihole-dns-configuration.md)
- [Monitoring & Logging Setup](../docs/06-monitoring-logging.md)
- [Security Hardening Results](../docs/05-hardening-results.md)

## Future Configurations

Planned additions:
- Docker Compose orchestration files
- Network segmentation configurations
- Backup and restore configurations
- Monitoring alert rules
- Security policy templates
