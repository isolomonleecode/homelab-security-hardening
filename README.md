# Homelab Security Hardening Project

**Author:** isolomonleecode
**Status:** In Progress
**Certifications:** CompTIA Security+
**Focus Areas:** Security Engineering, Infrastructure Security, Container Security

## Project Overview

This repository documents the systematic security audit, hardening, and monitoring implementation for a production homelab environment running 25+ containerized services, VMs, and network infrastructure.

**Objectives:**
1. Conduct comprehensive security audit of existing infrastructure
2. Implement defense-in-depth security controls
3. Establish continuous monitoring and vulnerability management
4. Document processes for portfolio demonstration and knowledge retention
5. Apply Security+ and Network+ concepts in real-world scenarios

## Infrastructure Scope

### Environment Details
- **Platform:** Unraid 6.x server
- **Containerization:** Docker (25+ containers)
- **Virtualization:** KVM/QEMU VMs
- **Networking:** Tailscale VPN, Pi-hole DNS, Nginx reverse proxy
- **Services:** Media servers, databases, web applications, monitoring tools

### Key Services Under Audit
- Nextcloud AIO (file sync/share platform)
- Jellyfin (media streaming)
- Sonarr/Radarr/Lidarr (media automation)
- Pi-hole (network-wide ad blocking & DNS)
- PostgreSQL & MariaDB (databases)
- Nginx Proxy Manager (reverse proxy)
- Multiple *arr stack applications

## Security Domains Covered

### 1. Asset Management & Inventory
- Complete infrastructure documentation
- Service mapping and dependency analysis
- Attack surface identification

### 2. Vulnerability Assessment
- Container image scanning
- Configuration reviews
- Exposed service enumeration
- CVE tracking and remediation

### 3. Access Control & Authentication
- Privilege escalation prevention
- Network segmentation
- Certificate management
- DNS security configuration

### 4. Security Hardening
- Container security best practices
- Least privilege implementation
- Secure configuration baselines
- Secret management

### 5. Monitoring & Detection
- Log aggregation
- Security event monitoring
- Anomaly detection
- Incident response preparation

## Project Structure

```
homelab-security-hardening/
├── docs/                          # Technical documentation
│   ├── 01-infrastructure-inventory.md
│   ├── 03-pihole-dns-configuration.md
│   ├── 04-vulnerability-assessment.md
│   ├── 05-hardening-results.md
│   ├── 06-monitoring-logging.md
│   ├── certification-concepts.md
│   └── README.md
├── configs/                       # Configuration files
│   ├── pihole/                    # Pi-hole DNS configs
│   ├── docker/                    # Docker Compose files
│   ├── nginx/                     # Reverse proxy configs
│   ├── logging/                   # Loki/Promtail configs
│   └── README.md
├── scripts/                       # Automation & security tools
│   ├── test-dns.sh
│   ├── add-pihole-dns.sh
│   ├── scan-containers.sh
│   ├── scan-all-containers.sh
│   ├── hardening-audit.sh
│   └── README.md
├── findings/                      # Security assessment results
│   ├── EXECUTIVE-SUMMARY.md
│   ├── REMEDIATION-ADMINER.md
│   ├── ADMINER-ACCESS-GUIDE.md
│   ├── vulnerability-reports/
│   └── README.md
├── sessions/                      # Session logs & completion summaries
│   ├── SESSION-1-COMPLETE.md
│   └── README.md
├── PROGRESS.md                    # Detailed progress tracking
└── README.md                      # This file
```

## Methodology

This project follows industry-standard security assessment practices:

1. **Reconnaissance & Inventory** - Document current state
2. **Vulnerability Identification** - Automated & manual scanning
3. **Risk Analysis** - Prioritize findings by severity
4. **Remediation** - Implement security controls
5. **Validation** - Verify fixes & document baselines
6. **Continuous Monitoring** - Ongoing security posture tracking

## Skills Demonstrated

**Technical Skills:**
- Linux system administration & hardening
- Docker container security
- Network security architecture
- PKI & certificate management
- Vulnerability assessment & management
- Security automation & scripting
- Log analysis & SIEM concepts

**Security Frameworks & Standards:**
- NIST Cybersecurity Framework
- CIS Benchmarks (Docker, Linux)
- Defense in Depth
- Zero Trust principles
- Least Privilege Access Control

**Tools & Technologies:**
- Docker & container security tools
- Network security appliances (Pi-hole, nginx)
- Vulnerability scanners (Trivy, Grype)
- Git version control
- Bash/Python scripting
- Tailscale VPN mesh networking

## Learning Objectives

As part of my cybersecurity career development, this project reinforces:

**Security+ Concepts:**
- Domain 1: Attacks, Threats & Vulnerabilities
- Domain 2: Architecture & Design
- Domain 3: Implementation
- Domain 4: Operations & Incident Response
- Domain 5: Governance, Risk & Compliance

**Network+ Concepts:**
- Network segmentation & VLANs
- DNS architecture & security
- VPN technologies
- Network monitoring & troubleshooting
- OSI model application

## Progress Tracking

- [x] Project initialization & repository setup
- [x] **Phase 1:** Infrastructure inventory & baseline - [Documentation](docs/01-infrastructure-inventory.md)
- [x] **Phase 2:** Pi-hole DNS configuration for local services - [Documentation](docs/03-pihole-dns-configuration.md)
- [x] **Phase 3:** Container vulnerability scanning (4 of 18 containers) - [Findings](findings/EXECUTIVE-SUMMARY.md)
  - [x] Critical vulnerability mitigation (Adminer) - [Remediation](findings/REMEDIATION-ADMINER.md)
- [ ] **Phase 4:** Security hardening implementation
  - [ ] Database binding to localhost
  - [ ] Docker network segmentation
  - [ ] Container privilege reduction
- [x] **Phase 5:** Monitoring & logging deployment - [Documentation](docs/06-monitoring-logging.md)
  - [x] Loki deployment on Grafana host (192.168.0.52:3100)
  - [x] Promtail on Pi4 shipping Docker logs
  - [ ] Grafana dashboards for security monitoring
- [ ] **Phase 6:** Documentation & portfolio completion
  - [x] Repository published to GitHub
  - [x] Professional README and documentation structure
  - [ ] Comprehensive vulnerability assessment (15 containers remaining)
  - [ ] Final hardening validation

## Key Achievements

### Security Improvements Implemented
- ✅ **Critical Vulnerability Mitigation:** Secured Adminer with 2 CRITICAL + 2 HIGH CVEs using compensating controls (localhost-only binding)
- ✅ **Complete Infrastructure Baseline:** Documented 18 active containers, network architecture, and attack surface
- ✅ **Local DNS Implementation:** Configured 14 service DNS records for improved usability and security
- ✅ **Centralized Logging:** Deployed Loki + Promtail for container log aggregation and monitoring
- ✅ **Vulnerability Scanning:** Established Trivy scanning workflow for ongoing vulnerability management

### Portfolio Highlights
- **Risk Management:** Demonstrated risk-based decision making with Adminer remediation
- **Incident Response:** 24-hour critical vulnerability mitigation
- **Security Automation:** 7 custom scripts for scanning, DNS management, and auditing
- **Professional Documentation:** 3,000+ lines of technical documentation
- **Real-World Application:** Security+ and Network+ concepts applied to production environment

## Key Takeaways & Lessons Learned

### Technical Insights
- **Container Security:** Compensating controls are effective when vendor patches unavailable
- **DNS Architecture:** Pi-hole dnsmasq configuration requires understanding of file hierarchy and restart procedures
- **Network Isolation:** Docker network boundaries affect DNS forwarding and service discovery
- **Log Aggregation:** Loki/Promtail provides lightweight, effective centralized logging for containers

### Methodology
- **Document First:** Baseline documentation critical before making changes
- **Automate Repetitive Tasks:** Scripts reduce errors and save time
- **Risk-Based Prioritization:** Focus on CRITICAL/HIGH severity findings first
- **Defense in Depth:** Multiple layers of security (SSH auth + localhost binding) reduce risk effectively

### Career Development
- **Practical Experience:** Hands-on application of certification concepts builds deeper understanding
- **Portfolio Value:** Real vulnerability remediation more impressive than theoretical knowledge
- **Documentation Skills:** Clear technical writing essential for security roles
- **Problem Solving:** Troubleshooting experience valuable for interviews and daily work

## Contact

For questions about this project or to discuss security engineering opportunities:
- GitHub: [@ssjlox](https://github.com/isolomonleecode)

---

**Note:** This is a personal homelab environment. All security testing is conducted on systems I own and operate. No production systems or unauthorized access is involved.
