# Certification Concepts Applied

This document maps hands-on work in this project to **Security+** and **Network+** certification concepts, reinforcing learning through practical application.

---

## Security+ (SY0-701) Domain Mapping

### Domain 1: General Security Concepts (12%)

#### 1.1 Compare and contrast various types of security controls
**Applied in Project:**
- **Technical Controls:** Firewall rules, network segmentation, container isolation
- **Administrative Controls:** Documentation, security policies, asset inventory
- **Preventive Controls:** Authentication, access restrictions
- **Detective Controls:** Log monitoring, vulnerability scanning

**Real-world Example:**
- Pi-hole DNS filtering = Preventive + Technical control
- Container vulnerability scanning = Detective + Technical control
- Asset inventory documentation = Administrative control

#### 1.2 Summarize fundamental security concepts
**Applied in Project:**
- **CIA Triad:**
  - Confidentiality: Database access restrictions, VPN encryption
  - Integrity: Certificate validation, secure configurations
  - Availability: Service monitoring, resource management

- **Non-repudiation:** Audit logs tracking who accessed what
- **Authentication vs Authorization:**
  - Nginx auth_request (authentication)
  - Container network policies (authorization)

#### 1.4 Explain the importance of using appropriate cryptographic solutions
**Applied in Project:**
- **TLS/SSL:** Tailscale certificates for Nextcloud
- **VPN:** Tailscale encrypted mesh network
- **Certificate Management:** Generated, stored, and deployed certificates
- **PKI Concepts:** Certificate authority, certificate validation

---

### Domain 2: Threats, Vulnerabilities & Mitigations (22%)

#### 2.1 Compare and contrast common threat actors and motivations
**Learning Application:**
- **Script Kiddies:** Scanning exposed ports (3306, 5432) for default credentials
- **Insider Threats:** Why container isolation matters (lateral movement prevention)
- **Organized Crime:** Targeting media servers for ransomware

#### 2.3 Explain various types of vulnerabilities
**Applied in Project:**
- **Platform/OS:** Unraid server, Docker host, container base images
- **Configuration:** Database bound to 0.0.0.0, overly permissive network access
- **Application:** Vulnerable container images, outdated software
- **Zero-day:** Why keeping watchtower (auto-updater) running matters

**Real Findings:**
```
- PostgreSQL exposed on all interfaces (0.0.0.0:5432)
  Vulnerability Type: Misconfiguration
  Impact: Unauthorized database access
  Mitigation: Bind to localhost only
```

#### 2.4 Given a scenario, analyze indicators of malicious activity
**Future Application:**
- Unusual network traffic patterns
- Failed authentication attempts
- Unexpected container resource usage
- DNS queries to known malicious domains (Pi-hole blocking)

---

### Domain 3: Security Architecture (18%)

#### 3.1 Compare and contrast security implications of different architecture models
**Applied in Project:**
- **Monolithic vs Microservices:** Nextcloud AIO (7 containers) vs single container
- **Containerization:** Docker isolation, resource limits, security boundaries
- **Network Architecture:**
  - DMZ concept: Cloudflare tunnel as edge
  - Internal network: Docker bridge networks
  - Management network: Tailscale VPN

#### 3.2 Given a scenario, apply security principles to secure enterprise infrastructure
**Applied in Project:**
- **Defense in Depth:** Multiple security layers
  - Network: VPN, firewall rules
  - Host: Unraid security features
  - Container: Isolated networks
  - Application: Authentication requirements

- **Least Privilege:** Containers should run as non-root users
- **Separation of Duties:** Different networks for different service tiers
- **Network Segmentation:** Isolating databases from public-facing services

**Practical Example:**
```
Current: All containers on same 172.19.0.0/16 network
Problem: Database can be accessed by compromised web container
Solution: Create separate networks (dmz, internal, database)
```

#### 3.3 Compare and contrast concepts and strategies to protect data
**Applied in Project:**
- **Data States:**
  - At Rest: Database files, container volumes
  - In Transit: TLS encryption (Tailscale, HTTPS)
  - In Use: Application memory (container isolation)

- **Data Classification:**
  - Public: Media files (Jellyfin)
  - Private: Personal files (Nextcloud)
  - Sensitive: Database credentials, API keys

---

### Domain 4: Security Operations (28%)

#### 4.1 Given a scenario, apply common security techniques to computing resources
**Applied in Project:**
- **Secure Baselines:** Documenting current state before changes
- **Hardening Targets:**
  - Operating System: Unraid configuration
  - Applications: Container security settings
  - Network Devices: Pi-hole, nginx configurations

#### 4.2 Explain the security implications of proper hardware, software, and data asset management
**Applied in Project:**
- **Asset Inventory:** Complete documentation of all services (this project!)
- **Acquisition/Procurement:** Using verified container images
- **Assignment/Accounting:** Tracking what runs where
- **Monitoring/Asset Tracking:** Watchtower for update tracking
- **Disposal/Decommissioning:** Properly stopping and removing containers

#### 4.5 Explain the processes associated with third-party risk assessment and management
**Applied in Project:**
- **Vendor Assessment:** Evaluating Docker image sources
  - linuxserver.io = Trusted community
  - ghcr.io/binhex = Well-maintained images
  - Official images (postgres, adminer)

- **Supply Chain Risk:**
  - Container images could contain malware
  - Mitigation: Image scanning, using official sources
  - Verification: Check image signatures, review Dockerfiles

#### 4.8 Explain appropriate incident response activities
**Future Application:**
- **Preparation:** Documentation, runbooks, backups
- **Detection:** Log monitoring, alerts
- **Analysis:** Reviewing logs for root cause
- **Containment:** Stopping compromised containers
- **Eradication:** Removing malware, patching vulnerabilities
- **Recovery:** Restoring from known-good state
- **Lessons Learned:** Documentation updates

---

### Domain 5: Security Program Management & Oversight (20%)

#### 5.1 Summarize elements of effective security governance
**Applied in Project:**
- **Policies:** Security baseline requirements
- **Standards:** CIS Benchmarks for Docker and Linux
- **Procedures:** This documentation!
- **Guidelines:** Best practices for container security

#### 5.2 Explain elements of the risk management process
**Applied in Project:**
- **Risk Identification:** Finding exposed services, misconfigurations
- **Risk Assessment:**
  - Likelihood: High (services exposed to internet)
  - Impact: High (database compromise, data loss)
  - Risk Level: Critical, High, Medium, Low (our prioritization)

**Risk Register Example:**
| Risk | Likelihood | Impact | Level | Mitigation |
|------|------------|--------|-------|------------|
| Database breach via exposed port | High | High | **Critical** | Bind to localhost |
| Cloudflare tunnel misconfiguration | Medium | High | **High** | Access audit |
| Outdated container image | Medium | Medium | Medium | Auto-updates |

#### 5.4 Summarize elements of effective security compliance
**Applied in Project:**
- **Compliance Reporting:** This documentation serves as evidence
- **Due Diligence/Care:** Regular security reviews
- **Attestation and Acknowledgement:** Signed audit reports
- **Internal/External Audits:** This security assessment

---

## Network+ (N10-009) Domain Mapping

### Domain 1: Networking Fundamentals (20%)

#### 1.1 Explain concepts related to the OSI model
**Applied in Project:**

| OSI Layer | Technology in Use | Example |
|-----------|-------------------|---------|
| Layer 7 (Application) | HTTP/HTTPS, DNS | Nginx reverse proxy, Pi-hole |
| Layer 6 (Presentation) | TLS/SSL | Tailscale certificates |
| Layer 5 (Session) | TCP sessions | Database connections |
| Layer 4 (Transport) | TCP, UDP | Port 5432 (TCP), Port 53 (UDP) |
| Layer 3 (Network) | IP routing, VPN | Tailscale overlay, Docker networks |
| Layer 2 (Data Link) | Bridging | br0, docker0 bridges |
| Layer 1 (Physical) | Ethernet | eth0 interface |

**Troubleshooting Example:**
```
Pi-hole can't reach Tailscale DNS (100.100.100.100)
- Layer 3 issue: Docker bridge network != host network
- Routing problem: No route between container and host VPN interface
- Solution: Configure DNS records locally (Layer 7) instead of forwarding
```

#### 1.2 Compare and contrast networking appliances, applications, and functions
**Applied in Project:**
- **VPN:** Tailscale (mesh VPN, WireGuard-based)
- **Firewall:** Implicit Docker bridge filtering
- **Proxy:** Nginx (reverse proxy), Nginx Proxy Manager
- **Load Balancer:** Could use for multiple containers
- **DNS:** Pi-hole (filtering + caching)

#### 1.4 Given a scenario, configure a subnet and use appropriate IP addressing schemes
**Applied in Project:**

**Networks Configured:**
```
LAN:           192.168.0.0/24    (254 hosts)
Docker 1:      172.17.0.0/16     (65,534 hosts)
Docker 2:      172.19.0.0/16     (65,534 hosts)
Docker 3:      172.18.0.0/16     (65,534 hosts)
VM Network:    192.168.122.0/24  (254 hosts)
Tailscale:     100.69.191.4/32   (Point-to-point)
```

**Subnetting Calculation Practice:**
- /24 = 256 addresses - 2 (network + broadcast) = 254 usable
- /16 = 65,536 addresses - 2 = 65,534 usable
- /32 = Single host address (Tailscale)

---

### Domain 2: Network Implementations (19%)

#### 2.1 Explain characteristics of routing technologies and network topologies
**Applied in Project:**
- **Routing:**
  - Default gateway: 192.168.0.1 (LAN router)
  - Docker NAT: Containers access internet through host
  - Tailscale mesh: Dynamic routing between peers

- **Network Topology:**
  - Star: All containers → Docker bridge → host
  - Mesh: Tailscale VPN network
  - Hybrid: LAN + VPN + Container networks

#### 2.2 Given a scenario, configure and deploy common wired/wireless network devices
**Applied in Project:**
- **VPN Concentrator:** Tailscale coordinating server
- **Router:** Docker bridge routing
- **Switch (Virtual):** Docker bridge switching

---

### Domain 3: Network Operations (16%)

#### 3.1 Explain the purpose of organizational processes and procedures
**Applied in Project:**
- **Change Management:** Documenting configuration changes (Git commits)
- **Incident Response:** Handling the I/O bottleneck issue
- **Disaster Recovery:** Backup procedures, known-good configurations
- **Business Continuity:** Service availability monitoring

#### 3.3 Explain common scanning, monitoring, and patching processes
**Applied in Project:**
- **Vulnerability Scanning:** Container image scanning (upcoming)
- **Log Reviewing:** Nginx error logs, container logs
- **Port Scanning:** Identifying exposed services
- **Patch Management:** Watchtower auto-updates, manual patching

---

### Domain 4: Network Security (19%)

#### 4.1 Explain the importance of basic network security concepts
**Applied in Project:**
- **Confidentiality:** VPN encryption, TLS certificates
- **Integrity:** Certificate validation, secure configs
- **Availability:** Monitoring, redundancy
- **Non-repudiation:** Audit logs

#### 4.3 Compare and contrast network access and management methods
**Applied in Project:**
- **In-band Management:** SSH to Unraid server
- **Out-of-band Management:** Unraid physical console (if needed)
- **VPN:** Tailscale for remote access
- **Jump Box/Bastion:** Unraid server acts as entry point

#### 4.4 Explain authentication and access control concepts
**Applied in Project:**
- **Authentication Methods:**
  - SSH key-based (Unraid access)
  - Password-based (container web UIs)
  - Certificate-based (Tailscale)

- **Authorization:**
  - Nginx auth_request (we disabled for Nextcloud)
  - Container network ACLs
  - File permissions

---

### Domain 5: Network Troubleshooting (26%)

#### 5.2 Given a scenario, troubleshoot common cable and physical interface issues
**Not Directly Applied** (Virtual environment)

#### 5.3 Given a scenario, troubleshoot common issues with network services
**Applied in Project:**

**Real Troubleshooting Examples:**

1. **DNS Resolution Issue:**
   ```
   Problem: Can't access capcorplee.tailc12764.ts.net locally
   Symptoms: DNS queries failing, using IP works
   Tools: nslookup, dig, systemd-resolve
   Root Cause: Pi-hole can't reach Tailscale DNS
   Solution: Configure local DNS records
   ```

2. **Service Connectivity:**
   ```
   Problem: Nginx returning HTTP 500 errors
   Symptoms: Direct access works, proxy fails
   Tools: curl, nginx error logs
   Root Cause: auth_request directive blocking requests
   Solution: Disabled auth for specific server block
   ```

3. **Performance Issue:**
   ```
   Problem: Unraid WebGUI unresponsive
   Symptoms: High load average (25+), I/O wait 25%
   Tools: top, iotop, ps aux, uptime
   Root Cause: VM + containers causing I/O bottleneck
   Solution: Stopped non-critical services
   ```

#### 5.5 Given a scenario, troubleshoot general networking issues
**Applied Concepts:**
- **Considerations:**
  - Device configuration: Docker, nginx, Pi-hole configs
  - Routing tables: Tailscale routes, Docker NAT
  - Interface status: `ip addr show`, interface up/down
  - Network performance: Load average, I/O wait
  - DNS issues: Pi-hole forwarding, MagicDNS
  - Firewall settings: Docker bridge rules

**Troubleshooting Methodology:**
1. Identify the problem (symptoms, scope)
2. Establish theory of probable cause
3. Test the theory
4. Establish plan of action
5. Implement solution
6. Verify functionality
7. Document findings

---

## Practical Skills Cross-Reference

| Task | Security+ Domain | Network+ Domain | Skill Demonstrated |
|------|------------------|-----------------|-------------------|
| Asset inventory | 4.2, 5.1 | 3.1 | Asset management, documentation |
| Network diagram | 2.1 | 1.1, 2.1 | Topology mapping, OSI model |
| Port scanning | 2.3, 4.1 | 3.3 | Vulnerability assessment |
| Container hardening | 3.2, 4.1 | 4.1 | Secure configuration |
| DNS configuration | 3.3 | 1.2, 5.3 | Network services, troubleshooting |
| VPN setup | 3.1, 3.3 | 4.3 | Secure remote access |
| Log analysis | 4.8 | 3.3, 5.3 | Incident response, troubleshooting |
| Risk assessment | 5.2 | 4.1 | Risk management |

---

## Study Tips & Retention

**Active Learning Techniques:**
1. **Explain it out loud:** Describe what you did and why to an imaginary interviewer
2. **Write it down:** This documentation = study guide
3. **Teach someone:** Explain Pi-hole DNS to a friend
4. **Practice:** Break things and fix them (in your homelab!)

**Interview Preparation:**
```
Question: "Tell me about a time you secured a network infrastructure."

Answer: "I conducted a security audit of my homelab running 25+ services.
I documented the attack surface, identified critical vulnerabilities like
exposed database ports, implemented network segmentation, and deployed
continuous monitoring. This reduced risk from critical to low while
maintaining service availability."

Supporting Evidence: [Link to this GitHub repo]
```

---

**Last Updated:** October 23, 2025
**Next Addition:** Container vulnerability scanning results
