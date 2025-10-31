# Session 3: Nextcloud Performance Troubleshooting & Optimization

**Date:** October 30, 2025
**Duration:** ~4 hours
**Focus:** Critical production issue resolution

---

## Session Overview

This session diverged from planned security hardening to address critical Nextcloud upload failures affecting production usage. The troubleshooting process revealed a complex three-layer performance bottleneck requiring systematic diagnosis and resolution.

**Initial Issue:** iOS Nextcloud app unable to upload photos/videos (Error -9996)

**Root Causes Identified:**
1. PHP-FPM worker exhaustion (5 → 100 → 200 workers needed)
2. Nginx timeout configuration (60s → 3600s needed)
3. **MariaDB database lock timeouts** (50s → 300s needed) ⭐ Primary bottleneck

---

## Problem Analysis

### Timeline of Discovery

1. **Initial Symptom:** Error -9996 on iOS app during bulk photo uploads
2. **First Layer:** PHP-FPM worker exhaustion (5 max_children)
3. **Second Layer:** Nginx FastCGI timeout (60s default, videos take 60-75s)
4. **Third Layer:** PHP-FPM crash at 100 workers (still insufficient)
5. **Fourth Layer:** MariaDB lock wait timeout (50s, root cause)

### Technical Investigation Process

**Methodology:**
- Log analysis (Nginx access/error, PHP-FPM, Nextcloud app, MariaDB)
- Real-time monitoring during upload attempts
- Systematic elimination of bottlenecks
- Performance testing after each fix

**Tools Used:**
- `docker logs` for container-level troubleshooting
- `docker exec` for in-container diagnostics
- Nginx access logs (HTTP status codes)
- MariaDB information_schema queries
- Nextcloud `occ` CLI commands

---

## Solutions Implemented

### 1. PHP-FPM Worker Pool Optimization

**Problem:** Only 5 worker processes, exhausted immediately with parallel uploads

**Evolution:**
```
Initial:  5 max_children  → Hit limit within seconds
Phase 1: 50 max_children  → Improved but still failing
Phase 2: 100 max_children → Hit limit during bulk upload
Final:   200 max_children → Sufficient capacity
```

**Final Configuration:**
```ini
pm = dynamic
pm.max_children = 200        # Maximum concurrent workers
pm.start_servers = 40        # Initial worker count
pm.min_spare_servers = 20    # Minimum idle workers
pm.max_spare_servers = 60    # Maximum idle workers
```

**Impact:** 40x increase in concurrent request handling (5 → 200)

---

### 2. Nginx Timeout Configuration

**Problem:** Default 60s FastCGI timeout, video EXIF/thumbnail generation takes 60-75s

**Error Pattern:**
```
upstream timed out (110: Operation timed out) while reading response header
request: "PUT .../video.mov HTTP/1.1"
upstream: "fastcgi://127.0.0.1:9000"
```

**Solution:**
```nginx
fastcgi_read_timeout 3600s;    # 1 hour (previously 60s)
fastcgi_send_timeout 3600s;    # 1 hour (previously 60s)
client_body_timeout 3600s;     # 1 hour (previously 300s)
```

**Impact:** 60x increase in timeout threshold, allows video processing to complete

---

### 3. MariaDB Lock Timeout & Performance Tuning

**Problem:** Database lock wait timeout during concurrent upload transactions

**Critical Error:**
```json
{
  "exception": "SQLSTATE[HY000]: General error: 1205",
  "message": "Lock wait timeout exceeded; try restarting transaction"
}
```

**Root Cause Analysis:**
- 50+ concurrent uploads = 50+ database transactions
- Each transaction locks rows during file metadata updates
- Default `innodb_lock_wait_timeout = 50s`
- Queue of transactions waiting for locks → timeout → HTTP 423 errors

**Solution:** `/etc/mysql/conf.d/nextcloud-tuning.cnf`
```ini
[mysqld]
# Critical: Lock timeout
innodb_lock_wait_timeout = 300          # 50s → 300s (5 minutes)

# Connection capacity
max_connections = 300                    # 151 → 300

# Performance optimizations
innodb_buffer_pool_size = 2G             # Query caching
innodb_log_file_size = 512M              # Transaction log size
innodb_flush_log_at_trx_commit = 2      # Balanced durability/performance
innodb_flush_method = O_DIRECT          # Reduce double buffering
```

**Impact:** 6x lock timeout increase, 2x connection capacity, significant query performance boost

---

## Persistence & Automation

### Challenge
Container restarts reset all tuning (LinuxServer.io containers don't persist `/etc` changes)

### Solution: Unraid User Scripts
Created automated tuning script: `scripts/nextcloud-tuning-unraid.sh`

**Automation Features:**
- Runs at Unraid array startup (User Scripts plugin)
- Detects container readiness before applying settings
- Applies all three layers: PHP-FPM, Nginx, MariaDB
- Restarts MariaDB to apply database config
- Verification and detailed logging

**Script Execution:**
```bash
[2025-10-30 16:30:50] === Starting Nextcloud Performance Tuning ===
[2025-10-30 16:30:55] Container running, waiting for services...
[2025-10-30 16:31:10] Applying PHP-FPM worker pool tuning...
[2025-10-30 16:31:11] PHP-FPM settings: max_children=200, start=40, min_spare=20, max_spare=60
[2025-10-30 16:31:11] Applying Nginx timeout configuration...
[2025-10-30 16:31:12] Set client_body_timeout to 3600s
[2025-10-30 16:31:13] Applying MariaDB performance tuning...
[2025-10-30 16:31:28] MariaDB settings: lock_timeout=300s, max_connections=300, buffer_pool=2G
[2025-10-30 16:31:29] Verified: pm.max_children = 200
[2025-10-30 16:31:30] Verified: fastcgi_read_timeout = 3600s
[2025-10-30 16:31:30] === Nextcloud Performance Tuning Complete ===
```

---

## Documentation Created

### Findings Directory (6 Documents)

1. **[NEXTCLOUD-TAILSCALE-RESOLUTION.md](../findings/NEXTCLOUD-TAILSCALE-RESOLUTION.md)**
   - Tailscale connectivity issue (trusted_domains)
   - Network topology analysis
   - HTTP 400 → HTTP 302 resolution

2. **[NEXTCLOUD-UPLOAD-ERRORS-FIX.md](../findings/NEXTCLOUD-UPLOAD-ERRORS-FIX.md)**
   - Initial PHP-FPM worker exhaustion (5 → 50)
   - Error -9996 root cause analysis
   - File locking during folder organization

3. **[NEXTCLOUD-VIDEO-UPLOAD-FIX.md](../findings/NEXTCLOUD-VIDEO-UPLOAD-FIX.md)**
   - Nginx FastCGI timeout issue
   - Video processing time analysis (EXIF + thumbnails)
   - Workers increased to 100

4. **[NEXTCLOUD-PHP-FPM-CRASH-FIX.md](../findings/NEXTCLOUD-PHP-FPM-CRASH-FIX.md)**
   - PHP-FPM termination at 100 worker limit
   - HTTP 499 (client closed) analysis
   - HTTP 423 (locked) from crash
   - Workers increased to 200

5. **[NEXTCLOUD-PERSISTENCE-SOLUTION.md](../findings/NEXTCLOUD-PERSISTENCE-SOLUTION.md)**
   - User Scripts automation strategy
   - LinuxServer.io container architecture
   - Comprehensive testing & verification guide

6. **[NEXTCLOUD-DATABASE-LOCK-FIX.md](../findings/NEXTCLOUD-DATABASE-LOCK-FIX.md)**
   - MariaDB lock wait timeout analysis
   - Database contention patterns
   - InnoDB performance tuning
   - Final resolution

### Scripts Created

- **[nextcloud-tuning-unraid.sh](../scripts/nextcloud-tuning-unraid.sh)** - Automated persistence (runs at array startup)
- **[diagnose-nextcloud-tailscale.sh](../scripts/diagnose-nextcloud-tailscale.sh)** - Diagnostic tool for connectivity issues

---

## Technical Skills Demonstrated

### Performance Analysis
- Multi-layer troubleshooting (application, web server, database)
- Log correlation across multiple services
- Real-time monitoring during problem reproduction
- HTTP status code interpretation (423, 499, 302)
- Database query analysis

### System Administration
- Docker container management (exec, logs, restart)
- PHP-FPM process management (USR2 signal for graceful reload)
- Nginx configuration and reload
- MariaDB configuration and tuning
- Unraid User Scripts automation

### Problem Solving
- Systematic elimination of causes
- Root cause analysis (5 Whys approach)
- Performance bottleneck identification
- Capacity planning (worker/connection calculations)
- Persistence strategy development

### Documentation
- Comprehensive technical writing
- Step-by-step reproduction guides
- Verification procedures
- Troubleshooting runbooks
- Git commit best practices

---

## Security Considerations

### Evaluated During Troubleshooting

**Database Credentials:**
- MariaDB root password in tuning script (acceptable for local automation)
- Alternative considered: Docker secrets (added complexity)

**Performance vs. Durability Trade-off:**
- `innodb_flush_log_at_trx_commit = 2` reduces durability slightly
- Acceptable risk for homelab (non-financial data)
- 1-second potential data loss window

**Resource Limits:**
- 200 PHP workers × 75MB avg = ~15GB potential memory usage
- 2GB InnoDB buffer pool
- Total: ~17GB memory allocation for Nextcloud stack
- Requires 32GB+ system RAM for safe operation

---

## Performance Metrics

### Before Optimization
- **PHP-FPM Workers:** 5 max
- **Nginx Timeout:** 60s
- **MariaDB Lock Timeout:** 50s
- **Upload Success Rate:** 0% (bulk uploads failed completely)
- **Error -9996:** Frequent
- **HTTP 423 Errors:** Common
- **Video Upload Time:** Failed (timeout before completion)

### After Optimization
- **PHP-FPM Workers:** 200 max (40 start)
- **Nginx Timeout:** 3600s (1 hour)
- **MariaDB Lock Timeout:** 300s (5 minutes)
- **Upload Success Rate:** 100% (tested with bulk uploads)
- **Error -9996:** Eliminated
- **HTTP 423 Errors:** Eliminated
- **Video Upload Time:** 60-90s (completes successfully)

### Capacity Analysis
- **Concurrent Uploads:** 200 (40x improvement)
- **Timeout Threshold:** 60x increase (60s → 3600s)
- **Database Lock Capacity:** 6x increase (50s → 300s)
- **Database Connections:** 2x increase (151 → 300)

---

## Lessons Learned

### Technical Insights

1. **Multi-Layer Bottlenecks:**
   - Production issues rarely have single root cause
   - Each layer must be tuned appropriately
   - Database often the hidden bottleneck

2. **Container Persistence Challenges:**
   - LinuxServer.io containers don't persist `/etc` changes
   - Automation required for reliable configuration
   - User Scripts effective for Unraid deployments

3. **iOS App Behavior:**
   - Nextcloud iOS app uploads 50+ files in parallel
   - No client-side throttling based on server capacity
   - Aggressive retry behavior can worsen contention

4. **Database Lock Patterns:**
   - File sync creates heavy database transaction load
   - Lock timeouts manifest as HTTP 423 (Locked)
   - Buffer pool sizing critical for metadata-heavy workloads

### Troubleshooting Methodology

1. **Start with Symptoms:**
   - Error codes (HTTP 423, 499, -9996)
   - User-reported behavior (hangs, timeouts)

2. **Follow the Request Path:**
   - Client → Nginx → PHP-FPM → Application → Database
   - Check logs at each layer
   - Identify where request fails

3. **Measure Before/After:**
   - Verify current settings before changes
   - Test incrementally
   - Validate each fix independently

4. **Automate Persistence:**
   - Manual fixes don't scale
   - Containers reset configuration
   - Scripts ensure consistency

### Career Development

**Incident Response:**
- Demonstrated production issue triage
- Prioritization of user-impacting problems
- Rapid diagnosis and resolution

**Systems Thinking:**
- Understanding component interactions
- Capacity planning across stack
- Performance vs. reliability trade-offs

**Professional Documentation:**
- Real-world troubleshooting examples
- Portfolio-quality technical writing
- Reusable runbooks for future issues

---

## Git Activity

### Commits Created

1. `NEXTCLOUD FIX: Complete persistence solution for performance tuning`
2. `FIX: PHP-FPM crash during bulk uploads - Increase to 200 workers`
3. `FINAL FIX: MariaDB database lock timeout - Uploads now working`

### Files Modified/Created

**Findings:**
- 6 new markdown documents (~1,500 lines total)

**Scripts:**
- 2 automation/diagnostic scripts

**Total Lines of Code/Docs:** ~2,000+

---

## Outcome & Status

### Resolution
✅ **COMPLETE** - Nextcloud uploads working error-free

### Persistence
✅ **AUTOMATED** - User Scripts ensures settings survive reboots

### Documentation
✅ **COMPREHENSIVE** - All findings documented with reproduction steps

### Testing
✅ **VERIFIED** - Bulk photo/video uploads successful

---

## Return to Security Hardening

With Nextcloud stabilized and documented, the project can return to the planned security hardening phases:

**Next Steps:**
- [ ] Complete Phase 3: Vulnerability scanning for remaining 15 containers
- [ ] Begin Phase 4: Security hardening (database binding, network segmentation)
- [ ] Expand Phase 5: Grafana security monitoring dashboards

**Time Investment:**
- Session Duration: ~4 hours
- Documentation: ~2 hours
- Total: ~6 hours

**Value Delivered:**
- Production system stabilized
- Comprehensive troubleshooting portfolio piece
- Reusable automation for Unraid deployments
- Real-world performance tuning experience

---

## Appendix: HTTP Status Codes Encountered

| Code | Meaning | Cause in This Context |
|------|---------|----------------------|
| **423** | Locked (WebDAV) | File locked by crashed transaction |
| **499** | Client Closed Connection (Nginx) | Client gave up waiting (timeout) |
| **302** | Found (Redirect) | Successful authentication/redirect |
| **400** | Bad Request | Missing Tailscale IP in trusted_domains |
| **201** | Created | Successful file upload |
| **204** | No Content | Successful operation (no body) |

---

**Session Complete:** Nextcloud optimization successful, security hardening resuming.
