# Migration Strategy: Grafana Alloy vs Wazuh

**Date**: 2025-11-06
**Context**: Grafana Agent is deprecated (EOL November 1, 2025)
**Decision Required**: Migrate to Grafana Alloy or adopt Wazuh?

---

## Current Situation

### Grafana Agent Status
- ✅ **Currently working** on your Linux devices (Promtail + node_exporter)
- ⚠️ **Deprecated**: In Long-Term Support (LTS) until October 31, 2025
- ❌ **End of Life**: November 1, 2025
- 🔄 **Recommended**: Migrate to Grafana Alloy

### What You Have Now
- **Linux devices**: Promtail (logs) + node_exporter (metrics) via Docker ✅ **Still supported**
- **macOS/Windows plans**: Grafana Agent (deprecated) ❌ **Needs updating**

**Good news**: Your existing Linux setup (Promtail + node_exporter) is **NOT deprecated** and will continue to work!

---

## Option 1: Migrate to Grafana Alloy (Recommended ⭐)

### What is Grafana Alloy?

**Grafana Alloy** is the successor to Grafana Agent:
- ✅ **Free and open source**
- ✅ **Unified telemetry collector** (logs, metrics, traces, profiles)
- ✅ **Drop-in replacement** for Grafana Agent
- ✅ **Better performance** and simpler configuration
- ✅ **Active development** and long-term support

### Why Choose Alloy?

**Pros**:
1. ✅ **Minimal disruption** - Works with your existing Loki/Prometheus/Grafana stack
2. ✅ **Same functionality** - Does everything Grafana Agent did (and more)
3. ✅ **Easy migration** - Similar config format, clear migration path
4. ✅ **Future-proof** - Active development, not deprecated
5. ✅ **No cost** - Still 100% free and open source
6. ✅ **Better UI** - Includes built-in UI for debugging

**Cons**:
1. ❌ **Migration effort** - Need to update macOS/Windows scripts
2. ❌ **Learning curve** - Slightly different configuration syntax
3. ❌ **New project** - Less mature than Agent (but backed by Grafana)

### What Needs to Change?

**Linux (Promtail + node_exporter)**: ✅ **NO CHANGES NEEDED**
- Promtail is still supported
- node_exporter is still supported
- Your existing setup works as-is

**macOS/Windows**: 🔄 **Update scripts to use Alloy**
- Replace Grafana Agent downloads with Alloy
- Update configuration format (minor changes)
- Test on one device first

### Migration Complexity

**Effort**: **Low to Medium**
- **Time**: 2-4 hours
- **Risk**: Low (Alloy is designed as drop-in replacement)
- **Rollback**: Easy (keep old scripts as backup)

---

## Option 2: Migrate to Wazuh

### What is Wazuh?

**Wazuh** is a comprehensive cybersecurity platform:
- ✅ **Free and open source**
- ✅ **XDR + SIEM** in one solution
- ✅ **Security-focused** (threat detection, vulnerability scanning, compliance)
- ✅ **Active development** and large community

### Why Choose Wazuh?

**Pros**:
1. ✅ **Purpose-built for security** - Not just monitoring, but threat detection
2. ✅ **Comprehensive features**:
   - Log analysis with security rules
   - Vulnerability detection
   - File integrity monitoring
   - Intrusion detection
   - Compliance monitoring (PCI-DSS, GDPR, HIPAA)
   - Incident response automation
3. ✅ **Better for cybersecurity career** - SIEM/XDR experience is highly valuable
4. ✅ **Enterprise-grade** - Used by many organizations
5. ✅ **Rich alerting** - Built-in security rules and threat intelligence

**Cons**:
1. ❌ **Major migration** - Completely different architecture
2. ❌ **More complex** - Heavier resource usage (needs dedicated server)
3. ❌ **Steep learning curve** - More features = more to learn
4. ❌ **Time investment** - 20-40 hours to deploy and configure properly
5. ❌ **Lose Grafana dashboards** - Would need to recreate in Wazuh/Kibana
6. ❌ **Infrastructure metrics less focus** - Primarily security, not infrastructure health

### What Wazuh Provides That You Don't Have

- **Security event correlation** (detect multi-stage attacks)
- **Vulnerability management** (automatic CVE detection)
- **Compliance reporting** (regulatory frameworks)
- **Active response** (automatic threat mitigation)
- **Threat intelligence integration** (known malicious IPs, domains)
- **Cloud security** (AWS, Azure, GCP monitoring)

### Migration Complexity

**Effort**: **High**
- **Time**: 20-40 hours
- **Risk**: Medium (completely new system)
- **Rollback**: Difficult (would keep Grafana running in parallel initially)

---

## Option 3: Hybrid Approach (Best of Both Worlds)

### Keep Grafana Stack + Add Wazuh

**Strategy**:
- ✅ Keep Loki/Prometheus/Grafana for **infrastructure monitoring**
- ✅ Add Wazuh for **security monitoring**
- ✅ Ship logs to both systems (Loki for ops, Wazuh for security)

**Benefits**:
- ✅ **Best of both worlds** - Infrastructure health AND security monitoring
- ✅ **Career advancement** - Experience with both monitoring types
- ✅ **Don't lose work** - Keep all your Grafana dashboards
- ✅ **Enhanced security** - Real threat detection capabilities

**Cons**:
- ❌ **Most complex** - Running two monitoring stacks
- ❌ **More resources** - Wazuh needs dedicated resources
- ❌ **More maintenance** - Two systems to manage

---

## Recommendation

### For Your Situation ⭐

**Recommended: Grafana Alloy (Short-term) → Hybrid (Long-term)**

### Phase 1: Migrate to Grafana Alloy (Now - December 2024)

**Why**:
1. ✅ **Quick win** - 2-4 hours to update macOS/Windows scripts
2. ✅ **Low risk** - Drop-in replacement for Agent
3. ✅ **Keeps momentum** - Don't disrupt your current setup
4. ✅ **Before EOL** - Agent EOL is Nov 1, 2025

**Action items**:
- [x] ✅ Keep Linux setup as-is (Promtail works fine)
- [ ] Update macOS script to use Alloy
- [ ] Update Windows script to use Alloy
- [ ] Test on one device
- [ ] Roll out to remaining devices

**Timeline**: 1 week

### Phase 2: Add Wazuh (Q1 2025 - Optional)

**Why**:
1. ✅ **Career development** - SIEM/XDR experience is very valuable
2. ✅ **Better security** - Real threat detection, not just log collection
3. ✅ **Interview material** - "Deployed SIEM solution" sounds great
4. ✅ **Learning opportunity** - Understand security operations

**Action items**:
- [ ] Research Wazuh architecture
- [ ] Deploy Wazuh manager (could use Raspberry Pi or spare PC)
- [ ] Install Wazuh agents on critical systems
- [ ] Configure security rules
- [ ] Integrate with existing monitoring

**Timeline**: 4-6 weeks (when you have time)

---

## Comparison Matrix

| Feature | Grafana Stack (Current) | Grafana Alloy | Wazuh | Hybrid |
|---------|------------------------|---------------|-------|--------|
| **Free & Open Source** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Infrastructure Monitoring** | ✅ Excellent | ✅ Excellent | ⚠️ Basic | ✅ Excellent |
| **Security Monitoring** | ⚠️ Basic | ⚠️ Basic | ✅ Excellent | ✅ Excellent |
| **Threat Detection** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Vulnerability Scanning** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Compliance Reporting** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Migration Effort** | N/A | 🟢 Low | 🔴 High | 🟡 Medium |
| **Learning Curve** | N/A | 🟢 Low | 🔴 High | 🟡 Medium |
| **Resource Usage** | 🟢 Low | 🟢 Low | 🟡 Medium | 🔴 High |
| **Career Value** | 🟡 Medium | 🟡 Medium | 🟢 High | ✅ Very High |
| **Time to Deploy** | N/A | 🟢 4 hours | 🔴 40 hours | 🟡 50 hours |

---

## For Your Linux Devices (Good News!)

**You don't need to change anything!**

Your current setup uses:
- **Promtail** → Logs to Loki ✅ **Not deprecated**
- **node_exporter** → Metrics to Prometheus ✅ **Not deprecated**

Both are **standalone projects** that are actively maintained and not affected by Grafana Agent deprecation.

**Only affected**: macOS/Windows devices that would have used Grafana Agent.

---

## Migration Guide: Grafana Agent → Alloy

### For macOS

**Current** (deprecated):
```bash
# Downloads Grafana Agent v0.40.0
# Config: /usr/local/etc/grafana-agent/config.yml
```

**New** (Alloy):
```bash
# Download Alloy instead
ALLOY_VERSION="v1.0.0"  # Check latest at github.com/grafana/alloy/releases
DOWNLOAD_URL="https://github.com/grafana/alloy/releases/download/${ALLOY_VERSION}/alloy-darwin-arm64"

# Config format is very similar, minor syntax changes
```

**What changes**:
- ✅ Binary name: `grafana-agent` → `alloy`
- ✅ Config format: Mostly same, some field renames
- ✅ Service name: `grafana-agent` → `alloy`

### For Windows

Similar changes:
- Download Alloy installer instead of Agent
- Update config syntax (minor)
- Same functionality

---

## Action Plan

### Immediate (This Week)

1. **✅ DONE**: Continue using Promtail on Linux (no changes needed)
2. **✅ DONE**: Update macOS script to use Grafana Alloy (v1.11.3)
3. **✅ DONE**: Update Windows script to use Grafana Alloy (v1.11.3)
4. **TODO**: Test on macOS device (.21)

### Short-term (Next Month)

5. **TODO**: Deploy Alloy to Windows device (.245)
6. **TODO**: Verify all devices shipping logs/metrics
7. **TODO**: Update documentation with Alloy

### Long-term (Q1 2025 - Optional)

8. **TODO**: Research Wazuh deployment
9. **TODO**: Deploy Wazuh manager
10. **TODO**: Install Wazuh agents on critical systems
11. **TODO**: Configure security rules and alerts
12. **TODO**: Create Wazuh dashboards

---

## Interview Talking Points

### If You Choose Alloy

*"When Grafana Agent was deprecated, I evaluated migration options and chose Grafana Alloy as a unified telemetry collector. I updated my deployment scripts to use Alloy for macOS and Windows devices while maintaining Promtail on Linux systems. This demonstrated my ability to stay current with technology changes and migrate systems proactively before EOL."*

### If You Choose Hybrid (Alloy + Wazuh)

*"I deployed a hybrid monitoring solution combining infrastructure monitoring (Grafana Alloy/Loki/Prometheus) with security monitoring (Wazuh SIEM/XDR). The Grafana stack provides infrastructure health metrics and operational insights, while Wazuh provides threat detection, vulnerability management, and compliance monitoring. This defense-in-depth approach demonstrates understanding of both DevOps and Security Operations perspectives."*

---

## Resources

### Grafana Alloy
- **Documentation**: https://grafana.com/docs/alloy/latest/
- **GitHub**: https://github.com/grafana/alloy
- **Releases**: https://github.com/grafana/alloy/releases
- **Migration Guide**: https://grafana.com/docs/alloy/latest/set-up/migrate/

### Wazuh
- **Documentation**: https://documentation.wazuh.com/
- **GitHub**: https://github.com/wazuh/wazuh
- **Getting Started**: https://wazuh.com/install/
- **Use Cases**: https://wazuh.com/use-cases/

### Grafana Agent (Reference)
- **GitHub**: https://github.com/grafana/agent
- **EOL Notice**: In releases notes
- **Migration Path**: Documented in Alloy docs

---

## Summary

**Recommended Path**:

1. ✅ **Keep Promtail on Linux** (no changes needed)
2. 🔄 **Migrate to Alloy for macOS/Windows** (this week)
3. ⏳ **Consider adding Wazuh** (when you have time)

**Why This Makes Sense**:
- ✅ Minimal disruption now
- ✅ Future-proof (Alloy is actively developed)
- ✅ Option to add Wazuh later for enhanced security
- ✅ Best of both worlds (monitoring + security)

**Next Immediate Step**: Update macOS/Windows scripts to use Grafana Alloy instead of deprecated Agent.

---

**Created**: 2025-11-06
**Decision**: Migrate to Grafana Alloy (macOS/Windows only)
**Status**: Linux devices don't need changes

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
