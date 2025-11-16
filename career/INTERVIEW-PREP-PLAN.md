# Cybersecurity Interview Preparation - Homelab Practice Plan

**Goal:** Use homelab to build demonstrable experience for cybersecurity interviews
**Duration:** Ongoing
**Focus:** Practical application of Security+/Network+ concepts in real scenarios

---

## Common Interview Topics & Homelab Practice Scenarios

### 1. Incident Response & Security Operations

**Interview Questions You'll Face:**
- "Walk me through how you'd respond to a security incident"
- "Tell me about a time you detected and responded to a security event"
- "How do you prioritize security alerts?"

**Homelab Practice Scenarios:**

#### Scenario A: Suspicious Authentication Activity Detection
**Setup:**
- Configure Grafana alerts for failed SSH attempts on Raspberry Pi
- Simulate brute-force attack detection
- Document response playbook

**Deliverable:** Incident response runbook with screenshots of alerts

#### Scenario B: Container Compromise Simulation
**Setup:**
- Intentionally deploy vulnerable container
- Use Trivy/Grype to detect vulnerabilities
- Practice containment (network isolation, container stop)
- Document remediation steps

**Deliverable:** Incident timeline showing detection → containment → eradication → recovery

#### Scenario C: Unauthorized Access Investigation
**Setup:**
- Review access logs in Loki/Grafana
- Identify suspicious patterns (unusual times, IPs, services)
- Practice log correlation across services

**Deliverable:** Investigation report with evidence trail

---

### 2. Vulnerability Management

**Interview Questions:**
- "How do you prioritize vulnerabilities?"
- "What's your process for patch management?"
- "Tell me about a critical vulnerability you've remediated"

**Homelab Practice Scenarios:**

#### Scenario A: Vulnerability Assessment Program
**What to Build:**
```bash
# Automated weekly vulnerability scan
#!/bin/bash
# /homelab-security-hardening/scripts/weekly-vuln-scan.sh

# Scan all containers
docker ps -q | xargs -I {} docker inspect {} --format '{{.Name}}' | while read container; do
  echo "Scanning $container..."
  trivy image $(docker inspect $container --format '{{.Config.Image}}') \
    --severity CRITICAL,HIGH \
    --format json \
    --output "/tmp/vuln-reports/$(date +%Y%m%d)-$container.json"
done

# Generate executive summary
# Track metrics: Total vulns, Critical count, remediation rate
```

**Deliverable:**
- Automated scanning script with cron job
- Vulnerability tracking spreadsheet
- Before/after metrics showing improvement

#### Scenario B: Patch Management Process
**What to Document:**
- Container update schedule (weekly? monthly?)
- Testing procedure before production updates
- Rollback plan if update breaks functionality
- Communication plan for service downtime

**Deliverable:** Patch management policy document

#### Scenario C: Risk-Based Prioritization
**Practice:**
- Create risk matrix (Likelihood × Impact)
- Assess each vulnerability's business impact
- Justify remediation timeline decisions

**Deliverable:** Risk register with 10-15 findings ranked by priority

---

### 3. Network Security & Architecture

**Interview Questions:**
- "How would you segment this network for security?"
- "Explain defense in depth"
- "What's your approach to network monitoring?"

**Homelab Practice Scenarios:**

#### Scenario A: Network Segmentation Implementation
**Project:** Create separate VLANs/subnets for:
- Management network (SSH, admin interfaces)
- Production services (databases, web apps)
- IoT/untrusted devices (Home Assistant if you add it back later)

**Deliverable:**
- Network diagram showing segmentation
- Firewall rules documentation
- Justification for each segment

#### Scenario B: Zero Trust Network Access (ZTNA) with Tailscale
**Current State:** You already have Tailscale VPN
**Enhancement:**
- Document Tailscale ACL (Access Control Lists)
- Implement least-privilege network access
- Disable public-facing services where possible
- Require Tailscale for admin access to all services

**Deliverable:**
- Tailscale ACL configuration
- Network access matrix (who can access what)
- Before/after attack surface comparison

#### Scenario C: DNS Security (Already Started with Pi-hole)
**Enhancements:**
- Enable DNSSEC validation
- Configure DNS-over-HTTPS (DoH) or DNS-over-TLS (DoT)
- Implement DNS query logging and analysis
- Create blocklists for malware/phishing domains

**Deliverable:**
- Pi-hole security configuration guide
- DNS query analysis showing blocked threats
- Custom blocklist rationale

---

### 4. Identity & Access Management (IAM)

**Interview Questions:**
- "How do you implement least privilege?"
- "Explain multi-factor authentication"
- "What's your approach to password security?"

**Homelab Practice Scenarios:**

#### Scenario A: Centralized Authentication with SAML (You've Already Started!)
**Current State:** SimpleSAMLphp deployed
**Enhancement:**
- Configure SimpleSAML as identity provider (IdP)
- Integrate 2-3 services as service providers (SP)
- Implement SSO (Single Sign-On) for homelab

**Deliverable:**
- SAML authentication architecture diagram
- Integration guide for each service
- Demo video showing SSO login flow

#### Scenario B: Secrets Management
**Problem:** Passwords/API keys scattered across docker-compose files
**Solution:** Implement HashiCorp Vault or Docker Secrets
**Practice:**
- Audit current secret storage
- Migrate to centralized secrets management
- Document secret rotation procedure

**Deliverable:**
- Secrets audit report
- Vault deployment guide
- Secret rotation policy

#### Scenario C: Privileged Access Management (PAM)
**Practice:**
- Limit sudo access on Raspberry Pi
- Create service accounts for automation (you have `automation` user!)
- Document admin access procedures
- Implement session logging for privileged actions

**Deliverable:**
- PAM policy document
- Audit log showing who did what when

---

### 5. Security Monitoring & Detection

**Interview Questions:**
- "How do you detect anomalies in your environment?"
- "What metrics do you monitor for security?"
- "Tell me about your SIEM experience"

**Homelab Practice Scenarios:**

#### Scenario A: Security Dashboard in Grafana
**What to Build:**
- Failed authentication attempts (SSH, web logins)
- Unusual network connections
- Container resource usage spikes (potential crypto mining)
- Certificate expiration tracking
- Vulnerability count over time

**Deliverable:**
- Grafana dashboard JSON export
- Screenshots of each panel with explanation
- Alert rules for critical conditions

#### Scenario B: Log Analysis & Correlation
**Current State:** Loki + Promtail deployed
**Enhancement:**
- Create LogQL queries for common security events
- Correlate events across services (example: failed login → port scan)
- Build detection rules for suspicious patterns

**Deliverable:**
- LogQL query library
- Detection rule documentation
- Sample investigation using log correlation

#### Scenario C: File Integrity Monitoring (FIM)
**Tool:** AIDE (Advanced Intrusion Detection Environment)
**Implementation:**
- Deploy AIDE on Raspberry Pi
- Monitor critical files (/etc/passwd, /etc/shadow, nginx configs)
- Create baseline and detect changes
- Configure alerts for unauthorized modifications

**Deliverable:**
- AIDE configuration
- Baseline file hashes
- Change detection demo

---

### 6. Cloud Security & Container Security

**Interview Questions:**
- "How do you secure containers?"
- "What's your approach to container image scanning?"
- "Explain least privilege in containerized environments"

**Homelab Practice Scenarios:**

#### Scenario A: Container Security Hardening
**Current State:** 25+ Docker containers
**Enhancements:**
- Run containers as non-root user
- Implement read-only file systems where possible
- Drop unnecessary Linux capabilities
- Use Docker secrets instead of environment variables
- Enable AppArmor/SELinux profiles

**Deliverable:**
- Security hardening checklist
- Before/after docker-compose.yml comparison
- CIS Docker Benchmark compliance report

#### Scenario B: Container Image Supply Chain Security
**Practice:**
- Only use official or verified images
- Scan images before deployment (Trivy integration in CI/CD)
- Sign images with Docker Content Trust
- Document image provenance

**Deliverable:**
- Approved base image list
- Image scanning pipeline
- Supply chain security policy

#### Scenario C: Runtime Container Security Monitoring
**Tool:** Falco (CNCF project)
**Implementation:**
- Deploy Falco to detect suspicious container behavior
- Alert on: privilege escalation, unusual network activity, file access
- Create custom detection rules

**Deliverable:**
- Falco deployment guide
- Custom rule examples
- Security event examples

---

### 7. Compliance & Governance

**Interview Questions:**
- "How do you ensure compliance in your environment?"
- "What security standards are you familiar with?"
- "How do you document security controls?"

**Homelab Practice Scenarios:**

#### Scenario A: Security Control Mapping
**Framework:** NIST CSF or CIS Controls
**Practice:**
- Map homelab security controls to framework
- Identify gaps in coverage
- Create remediation plan for gaps

**Deliverable:**
- Control mapping matrix
- Gap analysis report
- Remediation roadmap

#### Scenario B: Security Policy Documentation
**Create Policies:**
- Acceptable Use Policy
- Password Policy
- Patch Management Policy
- Incident Response Policy
- Change Management Policy

**Deliverable:**
- Policy library (5-10 policies)
- Policy review/update schedule

#### Scenario C: Audit & Compliance Reporting
**Practice:**
- Create audit logging for all admin actions
- Generate compliance reports
- Document evidence of control effectiveness

**Deliverable:**
- Audit report template
- Sample compliance report
- Evidence collection procedure

---

## Interview Storytelling Framework (STAR Method)

For each scenario you implement, document using STAR:

**S - Situation:** "In my homelab environment running 25+ containers..."
**T - Task:** "I needed to implement centralized logging for security monitoring..."
**A - Action:** "I deployed Loki and Promtail, configured log shipping from all Docker containers, and created Grafana dashboards..."
**R - Result:** "This allowed me to detect a failed SSH brute-force attempt within 2 minutes and automatically block the IP..."

### Example Stories to Prepare

**Story 1: Critical Vulnerability Remediation**
- Situation: Adminer container with CRITICAL CVEs
- Task: Mitigate risk without breaking functionality
- Action: Bound to localhost, documented compensating controls
- Result: Reduced attack surface, maintained service availability

**Story 2: Security Monitoring Implementation**
- Situation: No visibility into container security events
- Task: Implement centralized logging and alerting
- Action: Deployed Loki/Promtail/Grafana stack
- Result: Can now detect anomalies within minutes

**Story 3: Access Control Improvement**
- Situation: Services exposed on public internet
- Task: Implement secure remote access
- Action: Configured Tailscale VPN with ACLs
- Result: Zero-trust network access, reduced attack surface

---

## Recommended Project Priority (Next 30 Days)

### Week 1: Security Monitoring Excellence
**Goal:** Demonstrate strong detection & response capabilities

**Projects:**
1. ✅ **Grafana Security Dashboard** - Failed logins, network anomalies, container stats
2. ✅ **SSH Brute-Force Detection** - Alert on 5+ failed attempts in 5 minutes
3. ✅ **Log Correlation Practice** - Document investigation of simulated incident

**Interview Value:** "I built a security monitoring system that detects..."

---

### Week 2: Vulnerability Management Maturity
**Goal:** Show systematic approach to vulnerability management

**Projects:**
1. ✅ **Automated Weekly Scans** - Cron job running Trivy against all containers
2. ✅ **Vulnerability Tracking** - Spreadsheet showing trends over time
3. ✅ **Remediation Metrics** - Document improvement (e.g., "Reduced CRITICAL vulns from 10 to 2")

**Interview Value:** "I implemented a vulnerability management program that..."

---

### Week 3: Network Security & Segmentation
**Goal:** Demonstrate defense-in-depth understanding

**Projects:**
1. ✅ **Network Diagram** - Visual representation of current architecture
2. ✅ **Segmentation Plan** - Design VLAN/subnet separation
3. ✅ **Firewall Rules Audit** - Document and justify each rule

**Interview Value:** "I designed and implemented network segmentation that..."

---

### Week 4: Identity & Access Management
**Goal:** Show IAM expertise with SAML/SSO

**Projects:**
1. ✅ **SAML SSO for 3 Services** - Integrate services with SimpleSAMLphp
2. ✅ **Secrets Management** - Migrate from plaintext to Vault/Docker Secrets
3. ✅ **Access Control Matrix** - Who can access what, and why

**Interview Value:** "I deployed an SSO solution using SAML that..."

---

## Technical Interview Preparation

### Scenario-Based Questions Practice

**Question:** "A user reports they can't access Nextcloud. How do you troubleshoot?"

**Your Answer Framework:**
1. **Gather Information:** Check if issue is isolated (one user vs all users)
2. **Check Logs:** Review Nextcloud container logs via Loki/Grafana
3. **Network Connectivity:** Verify DNS resolution (Pi-hole logs), ping/traceroute
4. **Service Status:** Check if container is running, review resource usage
5. **Recent Changes:** Check change log, recent updates that might have broken functionality
6. **Escalation:** If unresolved, document findings and engage next level

**Question:** "You detect unusual outbound traffic from a container. What do you do?"

**Your Answer Framework:**
1. **Immediate Containment:** Isolate container (network disconnect)
2. **Preserve Evidence:** Snapshot container, copy logs
3. **Investigation:** Analyze network traffic, process list, file system changes
4. **Root Cause:** Determine if vulnerability, misconfiguration, or compromise
5. **Remediation:** Patch vulnerability, rebuild container from clean image
6. **Post-Incident:** Update runbook, improve detection rules

---

## Skills to Highlight in Interviews

### Technical Skills (from your homelab)
- ✅ **Linux Administration:** Raspberry Pi management, systemd services
- ✅ **Container Security:** Docker hardening, vulnerability scanning
- ✅ **Network Security:** VPN (Tailscale), DNS security (Pi-hole), firewall rules
- ✅ **SIEM/Logging:** Loki, Promtail, Grafana for log analysis
- ✅ **Vulnerability Management:** Trivy scanning, risk-based prioritization
- ✅ **Identity Management:** SAML, SSO implementation
- ✅ **Scripting/Automation:** Bash scripts for security automation
- ✅ **Infrastructure as Code:** Docker Compose, configuration management

### Soft Skills (demonstrated through homelab)
- ✅ **Problem Solving:** Troubleshooting complex issues (Session 3 Nextcloud fix)
- ✅ **Documentation:** Comprehensive technical writing
- ✅ **Risk Management:** Balancing security with functionality
- ✅ **Continuous Learning:** Self-directed lab environment
- ✅ **Communication:** Explaining technical concepts clearly

---

## Portfolio Projects to Showcase

### Project 1: Vulnerability Management Program
**GitHub Repo Section:** `findings/vulnerability-reports/`
**Contents:**
- Weekly scan results
- Trend analysis graphs
- Remediation tracking
- Before/after metrics

### Project 2: Security Monitoring System
**GitHub Repo Section:** `configs/grafana/dashboards/`
**Contents:**
- Grafana dashboard JSON exports
- Alert rule configurations
- Investigation playbooks
- Sample alerts with screenshots

### Project 3: Network Security Architecture
**GitHub Repo Section:** `docs/network-security/`
**Contents:**
- Network diagrams (current & future state)
- Segmentation plan
- Firewall rule documentation
- Zero-trust implementation guide

### Project 4: Identity & Access Management
**GitHub Repo Section:** `docs/iam/`
**Contents:**
- SAML architecture diagram
- SSO integration guides
- Access control policies
- Secrets management implementation

---

## Interview Questions You Can Answer with Homelab Experience

### Beginner/Intermediate Questions

**Q:** "What's the difference between encryption at rest and in transit?"
**A:** "In my homelab, I use Tailscale which encrypts data in transit using WireGuard. For encryption at rest, I've configured encrypted volumes for my databases..."

**Q:** "How do you secure Docker containers?"
**A:** "I implement several controls: non-root users, read-only file systems, dropped capabilities, network segmentation, and regular vulnerability scanning with Trivy..."

**Q:** "Explain defense in depth"
**A:** "In my homelab, I layer multiple controls: perimeter security with firewall, network segmentation, application-level authentication, logging/monitoring, and regular patching..."

### Advanced Questions

**Q:** "How would you detect a container escape?"
**A:** "I use Falco for runtime detection of suspicious syscalls and privilege escalations. I also monitor for: unexpected processes, file access outside expected paths, network connections to unusual destinations..."

**Q:** "Walk me through your incident response process"
**A:** "I follow NIST's Preparation → Detection → Containment → Eradication → Recovery → Lessons Learned. In my homelab, I've documented this with specific playbooks for common scenarios..."

**Q:** "How do you prioritize security work?"
**A:** "I use a risk-based approach: severity × exploitability × business impact. For example, I prioritized fixing Adminer's CRITICAL CVEs over MEDIUM findings in less-exposed containers..."

---

## Resources for Continued Learning

### Homelab-Specific
- [ ] Deploy Wazuh (open-source SIEM/XDR)
- [ ] Implement OpenVAS (vulnerability scanner)
- [ ] Set up Security Onion (network security monitoring)
- [ ] Deploy CrowdSec (collaborative IDS/IPS)

### Certifications to Consider
- [ ] **CEH (Certified Ethical Hacker)** - Offensive security perspective
- [ ] **GIAC GSEC** - Security Essentials
- [ ] **CompTIA CySA+** - Cybersecurity Analyst
- [ ] **CISSP** - After 5 years experience

### Online Practice
- [ ] TryHackMe defensive security path
- [ ] HackTheBox defensive labs
- [ ] SANS Cyber Aces tutorials
- [ ] CyberDefenders blue team challenges

---

## Next Session Goals

**What to Focus On:**
1. Build one complete incident response scenario
2. Create Grafana security dashboard
3. Document vulnerability management metrics
4. Practice explaining homelab projects using STAR method

**Deliverables:**
- Incident response playbook
- Grafana dashboard screenshots
- 5 STAR-method stories prepared

**Interview Readiness:**
- Practice answering: "Tell me about your homelab"
- Prepare 3-minute elevator pitch on each major project
- Document specific metrics (reduced vulns by X%, detected Y incidents, etc.)

---

## Success Metrics

**You're interview-ready when you can:**
- ✅ Explain every component of your homelab architecture
- ✅ Walk through 5+ security projects with STAR method
- ✅ Demonstrate active monitoring/alerting capabilities
- ✅ Show measurable security improvements with data
- ✅ Discuss lessons learned and how you'd do things differently
- ✅ Answer "Why this technology?" for each tool you chose

**Remember:** The homelab itself is impressive, but the ability to articulate WHY you made certain decisions and WHAT you learned is what separates good candidates from great ones.
