# Nextcloud Database Lock Timeout Fix

**Date**: October 30, 2025
**Issue**: MariaDB lock wait timeout causing upload failures (HTTP 423 errors)
**Solution**: Increased database lock timeout and optimized MariaDB settings

---

## Problem Statement

Even after increasing PHP-FPM workers to 200, uploads were still failing with HTTP 423 (Locked) errors. The root cause was MariaDB database lock timeouts during bulk uploads.

### Error in Logs
```json
{
  "message": "SQLSTATE[HY000]: General error: 1205 Lock wait timeout exceeded; try restarting transaction",
  "exception": "OC\\DB\\Exceptions\\DbalException"
}
```

---

## Root Cause

When the iOS app uploads 50+ files in parallel:
1. Each upload creates database transactions (file metadata, locks, activity updates)
2. MariaDB's default `innodb_lock_wait_timeout` is only **50 seconds**
3. With 50+ concurrent operations, transactions queue up waiting for locks
4. After 50 seconds, transactions timeout → Upload fails with HTTP 423

The issue was **database contention**, not PHP-FPM or Nginx capacity.

---

## Solution Implemented

### MariaDB Performance Tuning

Created `/etc/mysql/conf.d/nextcloud-tuning.cnf`:

```ini
[mysqld]
# Lock timeout (critical fix)
innodb_lock_wait_timeout = 300        # 50s → 300s (5 minutes)

# Connection capacity
max_connections = 300                  # 151 → 300

# Performance optimizations
innodb_buffer_pool_size = 2G           # Query caching
innodb_log_file_size = 512M            # Larger transaction log
innodb_flush_log_at_trx_commit = 2    # Better write performance
innodb_flush_method = O_DIRECT        # Reduce double buffering
```

### Configuration Details

**Lock Wait Timeout**: `300 seconds`
- Allows long-running transactions during bulk operations
- Prevents premature timeout on video processing/thumbnail generation

**Max Connections**: `300`
- Handles 200 PHP-FPM workers + background jobs
- Each worker may open multiple DB connections

**Buffer Pool**: `2GB`
- Caches frequently accessed data in memory
- Reduces disk I/O for metadata queries

**Flush Settings**: Optimized for performance
- `flush_log_at_trx_commit = 2`: Flush to OS every second (not every transaction)
- `flush_method = O_DIRECT`: Bypass OS cache, reduce double buffering

---

## Persistence Solution

### User Scripts Automation

Updated [scripts/nextcloud-tuning-unraid.sh](../scripts/nextcloud-tuning-unraid.sh) to include:
1. PHP-FPM worker tuning (200 workers)
2. Nginx timeout configuration (3600s)
3. **MariaDB configuration** (lock timeout 300s)

The script runs "At Startup of Array" via Unraid User Scripts plugin.

### MariaDB Container Restart Required

The script:
1. Creates config file in MariaDB container
2. Restarts `nextcloud-db` container to apply settings
3. Waits 15 seconds for MariaDB to fully restart
4. Nextcloud automatically reconnects

---

## Complete Settings Summary

### PHP-FPM (Nextcloud Container)
```ini
pm.max_children = 200
pm.start_servers = 40
pm.min_spare_servers = 20
pm.max_spare_servers = 60
```

### Nginx (Nextcloud Container)
```nginx
fastcgi_read_timeout 3600s;
fastcgi_send_timeout 3600s;
client_body_timeout 3600s;
```

### MariaDB (nextcloud-db Container)
```ini
innodb_lock_wait_timeout = 300
max_connections = 300
innodb_buffer_pool_size = 2G
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
```

---

## Verification

### Check MariaDB Settings
```bash
docker exec nextcloud-db mariadb -uroot -p'NextcloudDB2025Root!' \
  -e 'SHOW VARIABLES LIKE "innodb_lock_wait_timeout"; SHOW VARIABLES LIKE "max_connections";'
```

Expected output:
```
innodb_lock_wait_timeout    300
max_connections             300
```

### Check Active Database Locks
```bash
docker exec nextcloud-db mariadb -uroot -p'NextcloudDB2025Root!' nextcloud \
  -e 'SELECT * FROM INFORMATION_SCHEMA.INNODB_TRX;'
```

Should be empty when no uploads are active.

### Monitor During Uploads
```bash
# Watch database connections
watch -n 2 'docker exec nextcloud-db mariadb -uroot -p"NextcloudDB2025Root!" \
  -e "SHOW STATUS LIKE \"Threads_connected\";"'

# Check for lock timeouts in Nextcloud logs
docker exec nextcloud tail -f /data/nextcloud.log | grep -i "lock wait timeout"
```

---

## Testing Results

**Before Fix**:
- HTTP 423 (Locked) errors on every upload
- Database lock timeout errors in nextcloud.log
- iOS app unable to upload after repeated failures
- Web interface notes editor crashing

**After Fix**:
- ✅ Uploads working successfully
- ✅ No HTTP 423 errors
- ✅ No database lock timeout errors
- ✅ iOS app uploading multiple files concurrently
- ✅ Stable operation

---

## Troubleshooting

### Uploads Still Failing

1. **Check if MariaDB config was applied**:
   ```bash
   docker exec nextcloud-db cat /etc/mysql/conf.d/nextcloud-tuning.cnf
   ```

2. **Restart MariaDB manually**:
   ```bash
   docker restart nextcloud-db
   sleep 15
   docker exec nextcloud /usr/bin/occ status
   ```

3. **Clear file locks**:
   ```bash
   docker exec nextcloud /usr/bin/occ maintenance:mode --on
   docker exec nextcloud-db mariadb -uroot -p'NextcloudDB2025Root!' nextcloud \
     -e 'DELETE FROM oc_file_locks;'
   docker exec nextcloud /usr/bin/occ maintenance:mode --off
   docker exec nextcloud /usr/bin/occ files:scan --all
   ```

### High Memory Usage

The 2GB buffer pool may be too large for systems with limited RAM.

**Adjust buffer pool size**:
```bash
# For 16GB RAM system, use 1G
innodb_buffer_pool_size = 1G

# For 8GB RAM system, use 512M
innodb_buffer_pool_size = 512M
```

**Rule of thumb**: Buffer pool should be 50-70% of available RAM for dedicated database server, or 10-20% for shared server.

---

## Related Documentation

- [NEXTCLOUD-PERSISTENCE-SOLUTION.md](./NEXTCLOUD-PERSISTENCE-SOLUTION.md) - User Scripts automation
- [NEXTCLOUD-PHP-FPM-CRASH-FIX.md](./NEXTCLOUD-PHP-FPM-CRASH-FIX.md) - PHP-FPM worker increase to 200
- [NEXTCLOUD-VIDEO-UPLOAD-FIX.md](./NEXTCLOUD-VIDEO-UPLOAD-FIX.md) - Nginx timeout configuration
- [NEXTCLOUD-UPLOAD-ERRORS-FIX.md](./NEXTCLOUD-UPLOAD-ERRORS-FIX.md) - Initial PHP-FPM tuning

---

## Security Considerations

### Database Password in Script

The User Scripts automation contains the MariaDB root password in plaintext. This is acceptable for:
- Unraid User Scripts (protected by Unraid UI authentication)
- Script runs as root on local system only
- No external network access

**Alternative**: Use Docker secrets or environment variables (requires more complex setup).

### Reduced Durability Settings

`innodb_flush_log_at_trx_commit = 2` trades some durability for performance:
- **Risk**: Potential loss of last 1 second of transactions on crash
- **Benefit**: Significant performance improvement
- **Acceptable for**: Home lab, non-critical data
- **Not recommended for**: Production financial systems, critical databases

For maximum durability, set to `1` (default), but expect slower uploads.

---

## Performance Impact

### Resource Usage

**CPU**: Minimal change (database operations already CPU-light)

**Memory**: +2GB for InnoDB buffer pool
- Monitor: `docker stats nextcloud-db`
- Adjust `innodb_buffer_pool_size` if memory constrained

**Disk I/O**: Reduced (better caching from larger buffer pool)

**Network**: No change

### Upload Performance

**Bulk Upload (50+ photos)**:
- Before: Failed after 50 seconds (HTTP 423)
- After: Completes successfully, no timeouts

**Video Upload (large files)**:
- Before: Database timeout during thumbnail generation
- After: Completes within 300s limit

**Concurrent Operations**:
- Supports 300 simultaneous database connections
- Handles 200 PHP-FPM workers + background jobs

---

## Future Improvements

### Monitoring

Add monitoring for:
- Database lock wait events
- Connection pool usage
- Buffer pool hit ratio
- Transaction rollback rate

### Optimization

Consider:
- Redis session handling (already in use)
- APCu for local PHP caching
- Memcached for distributed caching
- Read-only replicas for scaling

### Alternative Solutions

1. **Object Storage**: S3-compatible backend (MinIO, Wasabi)
2. **External Database**: Dedicated database server
3. **Load Balancing**: Multiple Nextcloud instances
4. **Asynchronous Uploads**: Queue-based processing

---

## Conclusion

The database lock timeout was the final bottleneck preventing successful bulk uploads. Combined with PHP-FPM and Nginx tuning, the Nextcloud instance now supports aggressive parallel uploads from mobile apps.

**Key Learnings**:
1. Multiple layers need tuning: PHP-FPM, Nginx, **and MariaDB**
2. Database contention is often the hidden bottleneck
3. Lock timeouts manifest as HTTP 423 errors
4. Maintenance mode is required to clear persistent locks

**Status**: ✅ **RESOLVED - UPLOADS WORKING**

**Persistence**: ✅ **Automated via User Scripts** (runs at array startup)
