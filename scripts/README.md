# Automation Scripts

This directory contains security automation and operational scripts for the homelab security hardening project.

## Available Scripts

### DNS Management

#### `test-dns.sh`
Tests DNS resolution for all configured `.homelab` services.

**Usage:**
```bash
./scripts/test-dns.sh
```

**Purpose:**
- Validates Pi-hole DNS configuration
- Checks all 14 service hostnames resolve correctly
- Useful after DNS changes or Pi-hole restarts

---

#### `add-pihole-dns.sh`
Adds new DNS A records to Pi-hole configuration.

**Usage:**
```bash
./scripts/add-pihole-dns.sh <hostname> <ip-address>
```

**Example:**
```bash
./scripts/add-pihole-dns.sh grafana.homelab 192.168.0.52
```

**Purpose:**
- Automates adding new services to local DNS
- Ensures consistent configuration format
- Backs up existing configuration before changes

---

### Vulnerability Scanning

#### `scan-containers.sh`
Scans a single Docker container for vulnerabilities using Trivy.

**Usage:**
```bash
./scripts/scan-containers.sh <container-name>
```

**Example:**
```bash
./scripts/scan-containers.sh jellyfin
```

**Purpose:**
- Quick vulnerability check for individual containers
- Outputs CRITICAL and HIGH severity CVEs
- Saves full report to findings/vulnerability-reports/

---

#### `scan-all-containers.sh`
Comprehensive vulnerability scan of all running containers.

**Usage:**
```bash
./scripts/scan-all-containers.sh
```

**Purpose:**
- Scans all active Docker containers
- Generates individual reports per container
- Creates consolidated summary report
- Automatically creates findings directory structure

**Output:**
- Individual reports: `findings/vulnerability-reports/<container>-scan.txt`
- Summary: Console output with count of findings per container

---

#### `quick-scan.sh`
Fast vulnerability scan showing only CRITICAL and HIGH severity issues.

**Usage:**
```bash
./scripts/quick-scan.sh <container-name>
```

**Purpose:**
- Rapid assessment during incident response
- Focuses on actionable high-priority vulnerabilities
- Minimal output for quick review

---

#### `full-scan-simple.sh`
Detailed vulnerability scan with all severity levels.

**Usage:**
```bash
./scripts/full-scan-simple.sh <container-name>
```

**Purpose:**
- Complete vulnerability assessment
- Includes MEDIUM and LOW severity findings
- Useful for compliance reporting and comprehensive audits

---

### Security Hardening

#### `hardening-audit.sh`
Performs comprehensive security audit of Docker container configurations.

**Usage:**
```bash
./scripts/hardening-audit.sh
```

**Purpose:**
- Identifies containers running as root
- Checks for privileged containers
- Audits network exposure (ports, bindings)
- Reviews volume mounts and capabilities
- Checks read-only filesystem status

**Output:**
- Console report with security findings
- Recommendations for hardening
- Prioritized action items

**Checks Performed:**
- ✅ Privileged containers (--privileged flag)
- ✅ Root user execution
- ✅ Exposed ports and bindings (0.0.0.0 vs localhost)
- ✅ Volume mounts (writable vs read-only)
- ✅ Capabilities (CAP_SYS_ADMIN, etc.)
- ✅ Network mode (host vs bridge)
- ✅ Read-only root filesystem

---

## Script Maintenance

### Adding New Scripts

1. Create script in `scripts/` directory
2. Add executable permissions: `chmod +x scripts/<script-name>.sh`
3. Include shebang: `#!/bin/bash`
4. Add usage documentation in script header
5. Update this README with script description

### Best Practices

- **Error handling:** All scripts should check for command failures
- **Usage messages:** Include help text for incorrect usage
- **Idempotency:** Scripts should be safe to run multiple times
- **Documentation:** Comment complex logic inline
- **Logging:** Output meaningful progress and error messages

### Dependencies

All scripts require:
- Bash 4.0+
- Docker CLI (for container operations)
- Trivy (for vulnerability scanning)
- SSH access to target hosts (where applicable)

Optional:
- jq (for JSON parsing in advanced scripts)
- curl (for API interactions)

## Common Workflows

### Weekly Security Scan
```bash
# Run comprehensive scan
./scripts/scan-all-containers.sh

# Review findings
cat findings/EXECUTIVE-SUMMARY.md

# Run hardening audit
./scripts/hardening-audit.sh
```

### Adding New Service
```bash
# Add DNS record
./scripts/add-pihole-dns.sh myapp.homelab 192.168.0.51

# Test DNS resolution
./scripts/test-dns.sh

# Scan for vulnerabilities
./scripts/scan-containers.sh myapp
```

### Incident Response
```bash
# Quick vulnerability check
./scripts/quick-scan.sh <affected-container>

# Full security audit
./scripts/hardening-audit.sh

# Review network exposure
docker inspect <container> | grep -A 10 "NetworkSettings"
```

## Troubleshooting

### "Permission denied" errors
```bash
chmod +x scripts/*.sh
```

### "Trivy: command not found"
```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
```

### "Docker: command not found"
Ensure Docker CLI is installed and accessible in PATH.

## Future Enhancements

Planned scripts for future phases:
- `setup-network-segmentation.sh` - Automate Docker network isolation
- `backup-configs.sh` - Backup all container configurations
- `restore-from-backup.sh` - Restore container configurations
- `generate-compliance-report.sh` - CIS Benchmark compliance report
- `monitor-cve-feed.sh` - Monitor NVD for new CVEs affecting installed packages

## References

- [Trivy CLI Documentation](https://aquasecurity.github.io/trivy/latest/docs/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
