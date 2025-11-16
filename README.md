# Homelab Security Hardening Project

**Author:** isolomonleecode
**Status:** In Progress
**Certifications:** CompTIA Security+
**Focus Areas:** Security Engineering, Infrastructure Security, Container Security

## Project Overview

This repository documents **13 comprehensive security projects** spanning infrastructure hardening, SIEM deployment, vulnerability management, and application security. Demonstrates production-ready cybersecurity skills through hands-on implementation across **7 monitored Linux devices**, **30+ containerized services**, and full-stack application development.

**📊 Portfolio Quick Stats:**
- **70% attack surface reduction** across production infrastructure
- **7/9 devices** hardened and monitored (Home SOC deployment)
- **30+ containers** secured with vulnerability management
- **~10,000 lines** of technical security documentation
- **15+ automation scripts** for deployment and security operations
- **2 production dashboards** (18 panels total) for security monitoring

**🎯 See [PORTFOLIO-SUMMARY.md](PORTFOLIO-SUMMARY.md) for complete executive summary and interview-ready demonstrations**

**Objectives:**
1. ✅ Conduct comprehensive security audit of existing infrastructure
2. ✅ Implement defense-in-depth security controls (firewalls, IPS, network segmentation)
3. ✅ Establish continuous monitoring and vulnerability management (Home SOC)
4. ✅ Document processes for portfolio demonstration and knowledge retention
5. ✅ Apply Security+ and Network+ concepts in real-world scenarios
6. ✅ Develop secure applications with AI/LLM security controls

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

## Featured Projects

### 🏆 1. Home Security Operations Center (SOC)
**Status:** ✅ Production-Ready | **Duration:** Sessions 10-11

Enterprise-grade SIEM deployment monitoring 7 Linux devices with centralized log aggregation (Loki), metrics collection (Prometheus), and security visualization (Grafana). Achieved **sub-minute security event detection** across **30+ containers**.

**Key Results:**
- 7/9 devices monitored (78% coverage)
- 70% attack surface reduction per device
- 5-minute automated deployment per device
- 2 dashboards (18 panels): Security Monitoring + Infrastructure Health

[📖 Home SOC Complete Summary](HOME-SOC-COMPLETE-SUMMARY.md) | [📋 Session 10-11 Details](sessions/)

### 🛡️ 2. Raspberry Pi Infrastructure Hardening
**Status:** ✅ Complete | **Duration:** Session 4

Systematic security hardening of production Raspberry Pi hosting critical services (Vaultwarden password vault, Pi-hole DNS, Caddy reverse proxy). Implemented **UFW firewall, fail2ban IPS, and network segmentation** achieving 70% attack surface reduction.

**Key Results:**
- Secured password vault (50+ credentials) - Tailscale-only access
- Deployed fail2ban intrusion prevention (3 attempts = 1hr ban)
- Network segmentation (Tailscale mesh + LAN isolation)
- Zero downtime during hardening

[📖 Raspberry Pi Assessment](docs/07-raspberry-pi-security-assessment.md) | [📋 Session 4 Summary](sessions/SESSION-4-RASPBERRY-PI-HARDENING.md)

### 💻 3. ResumeWonder Application Security
**Status:** ✅ Production-Ready | **Duration:** Session 13

Full-stack AI-powered job application assistant with comprehensive security controls. Implemented **VRAM exhaustion prevention, API security hardening, AI output sanitization**, and frontend security features.

**Key Results:**
- 70% VRAM reduction (17GB → 5GB) preventing DoS attacks
- 30x API performance improvement (30s+ → 1s)
- 8 security controls implemented (resource management, input validation, PII protection)
- 3,000+ lines security documentation

**Tech Stack:** FastAPI (Python) + React (TypeScript) + LocalAI

[📖 ResumeWonder Security Guide](docs/08-resumewonder-application-security.md)

### 🔍 4. Container Vulnerability Management
**Status:** ✅ Ongoing | **Duration:** Sessions 3, 5, 12

Systematic vulnerability scanning, risk assessment, and remediation using Trivy. **Remediated 15+ CRITICAL/HIGH vulnerabilities** across 30+ containers with risk-based prioritization.

**Key Results:**
- Adminer CRITICAL vulnerabilities remediated (compensating controls)
- Nextcloud 3-layer performance issue resolved (incident response)
- Automated container update monitoring deployed
- Comprehensive vulnerability documentation

[📖 Consolidated Vulnerability Report](findings/CONSOLIDATED-VULNERABILITY-REPORT.md) | [📋 Session 5 Summary](sessions/SESSION-5-VULNERABILITY-REMEDIATION.md)

---

## Security Domains Covered

### 1. Asset Management & Inventory
- Complete infrastructure documentation (9 devices, 30+ containers)
- Service mapping and dependency analysis
- Attack surface identification and reduction

### 2. Vulnerability Assessment
- Container image scanning (Trivy, Grype)
- Configuration reviews and hardening
- Exposed service enumeration
- CVE tracking and risk-based remediation

### 3. Access Control & Authentication
- Privilege escalation prevention
- Network segmentation (Tailscale VPN + LAN)
- SSH hardening (key-based auth, no root login)
- Certificate management
- DNS security configuration

### 4. Security Hardening
- Container security best practices
- Least privilege implementation
- Secure configuration baselines
- Secret management
- Firewall deployment (UFW, firewalld)
- Intrusion prevention (fail2ban)

### 5. Monitoring & Detection
- Log aggregation (Loki)
- Metrics collection (Prometheus)
- Security event monitoring
- Anomaly detection
- Incident response workflows
- Dashboard design (Grafana)

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
- [x] **Phase 3:** Container vulnerability scanning & remediation - [Findings](findings/CONSOLIDATED-VULNERABILITY-REPORT.md)
  - [x] Critical vulnerability mitigation (Adminer) - [Remediation](findings/REMEDIATION-ADMINER.md)
  - [x] 30+ containers scanned with Trivy
  - [x] 15+ CRITICAL/HIGH vulnerabilities remediated
- [x] **Phase 4:** Security hardening implementation
  - [x] Raspberry Pi hardening (UFW + fail2ban + network segmentation)
  - [x] 7 Linux devices hardened (firewalls + SSH)
  - [x] 70% attack surface reduction achieved
  - [x] Vaultwarden password vault secured (CRITICAL)
- [x] **Phase 5:** Monitoring & logging deployment - [Documentation](docs/06-monitoring-logging.md)
  - [x] Home SOC deployed (Grafana + Loki + Prometheus)
  - [x] 7/9 devices monitored (78% coverage)
  - [x] 2 production dashboards created (18 panels total)
  - [x] Automated deployment scripts (5-minute per-device)
- [x] **Phase 6:** Application Security
  - [x] ResumeWonder full-stack development with security controls
  - [x] VRAM exhaustion prevention (DoS mitigation)
  - [x] API security hardening (timeout enforcement)
  - [x] AI output sanitization (prompt injection defense)
- [x] **Phase 7:** Documentation & portfolio completion
  - [x] Repository published to GitHub
  - [x] 13 sessions fully documented (~10,000 lines)
  - [x] Portfolio summary for interviews
  - [x] Comprehensive vulnerability assessment
  - [x] Career materials (resume, talking points, interview prep)

## Key Achievements

### Security Improvements Implemented
- ✅ **Home SOC Deployment:** Enterprise-grade SIEM monitoring 7 devices with sub-minute security event detection
- ✅ **70% Attack Surface Reduction:** Systematic hardening across all production infrastructure
- ✅ **Critical Vulnerability Mitigation:** Remediated 15+ CRITICAL/HIGH CVEs with compensating controls
- ✅ **Password Vault Security:** Secured Vaultwarden protecting 50+ credentials (Tailscale-only access)
- ✅ **Intrusion Prevention:** Deployed fail2ban on production systems (3 attempts = 1hr ban)
- ✅ **Centralized Logging:** Loki + Promtail aggregating ~1000 log lines/minute
- ✅ **Metrics Collection:** Prometheus scraping 70+ metrics per device every 15 seconds
- ✅ **Application Security:** ResumeWonder with VRAM exhaustion prevention and API hardening
- ✅ **Network Segmentation:** Tailscale mesh VPN + firewall policies (default deny)
- ✅ **Automated Deployment:** 5-minute device onboarding with idempotent scripts

### Portfolio Highlights
- **SIEM Architecture:** Built production-grade SOC with Grafana + Loki + Prometheus
- **Risk Management:** Risk-based vulnerability prioritization and remediation
- **Incident Response:** Multiple documented troubleshooting sessions (Nextcloud, service recovery)
- **Security Automation:** 15+ scripts (deployment, scanning, hardening, auditing)
- **Multi-OS Expertise:** Arch, Debian, Ubuntu, Raspberry Pi OS, macOS, Windows guides
- **Professional Documentation:** 10,000+ lines across 30+ technical documents
- **Full-Stack Security:** Infrastructure hardening + secure application development
- **Real-World Application:** Security+ and Network+ concepts applied to production environment
- **Quantified Results:** All achievements backed by metrics (70% reduction, 7 devices, 30+ containers)

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
