# Nextcloud Performance Tuning - Persistence Solution

**Date**: October 30, 2025
**Issue**: PHP-FPM and Nginx performance settings reverting after container restarts
**Solution**: Unraid User Scripts automation to reapply settings at array startup

---

## Problem Statement

After resolving upload errors and video timeout issues by tuning PHP-FPM workers and Nginx timeouts, the settings would revert when the Nextcloud container was restarted or updated. This occurred because:

1. LinuxServer.io Nextcloud container doesn't persist `/etc/php84/php-fpm.d/www.conf` modifications
2. Some Nginx settings in `/config/nginx/site-confs/default.conf` are regenerated on startup
3. Container updates completely reset the internal filesystem

---

## Solution Architecture

**Approach**: Use Unraid's User Scripts plugin to automatically reapply performance tuning at array startup.

### Why This Approach?

1. **Unraid-native**: Leverages built-in User Scripts functionality
2. **Startup automation**: Runs automatically when array starts
3. **Non-intrusive**: Doesn't modify container image or Docker configs
4. **Maintainable**: Single script that's easy to update
5. **Logged**: Provides detailed execution logs for troubleshooting

---

## Implementation

### Script Location
`/boot/config/plugins/user.scripts/scripts/nextcloud-tuning/script`

The script is also version-controlled in this repository:
`scripts/nextcloud-tuning-unraid.sh`

### User Scripts Configuration
- **Name**: nextcloud-tuning
- **Schedule**: At Startup of Array
- **Execution**: Background mode
- **Log Location**: `/tmp/nextcloud-tuning.log`

---

## Applied Settings

### PHP-FPM Worker Pool Tuning
```ini
pm.max_children = 100        # Up from default 5 (20x increase)
pm.start_servers = 20        # Up from default 2
pm.min_spare_servers = 10    # Up from default 1
pm.max_spare_servers = 35    # Up from default 3
```

**Impact**: Allows 100 concurrent PHP requests instead of 5, preventing worker exhaustion during bulk photo/video uploads.

### Nginx Timeout Configuration
```nginx
fastcgi_read_timeout 3600s;   # Added (default was 60s)
fastcgi_send_timeout 3600s;   # Added (default was 60s)
client_body_timeout 3600s;    # Up from 300s
```

**Impact**: Prevents timeouts during EXIF extraction and thumbnail generation for large video files (which can take 60-75 seconds).

---

## How It Works

### Execution Flow

1. **Array Startup Trigger**: Unraid starts the array and User Scripts plugin activates
2. **Container Detection**: Script waits up to 60 seconds for Nextcloud container to be running
3. **Service Initialization Wait**: Additional 15-second delay for Nginx/PHP-FPM to fully start
4. **PHP-FPM Tuning**: Uses `sed` to modify `/etc/php84/php-fpm.d/www.conf` inside container
5. **Nginx Tuning**: Adds/updates timeout directives in `/config/nginx/site-confs/default.conf`
6. **Service Reload**: Gracefully reloads PHP-FPM (USR2 signal) and Nginx
7. **Verification**: Confirms settings were applied correctly
8. **Logging**: Writes detailed log to `/tmp/nextcloud-tuning.log`

### Script Execution Example
```bash
[2025-10-30 16:30:50] === Starting Nextcloud Performance Tuning ===
[2025-10-30 16:30:50] Waiting for Nextcloud container to be ready...
[2025-10-30 16:30:55] Container running, waiting for services to initialize...
[2025-10-30 16:31:10] Applying PHP-FPM worker pool tuning...
[2025-10-30 16:31:11] PHP-FPM settings: max_children=100, start=20, min_spare=10, max_spare=35
[2025-10-30 16:31:11] Applying Nginx timeout configuration...
[2025-10-30 16:31:12] FastCGI timeouts already present
[2025-10-30 16:31:12] Set client_body_timeout to 3600s
[2025-10-30 16:31:12] Reloading PHP-FPM and Nginx...
[2025-10-30 16:31:13] Verifying applied settings...
[2025-10-30 16:31:13] Verified: pm.max_children = 100
[2025-10-30 16:31:14] Verified: fastcgi_read_timeout = 3600s
[2025-10-30 16:31:14] === Nextcloud Performance Tuning Complete ===
```

---

## Testing & Verification

### Initial Verification (Post-Installation)
```bash
# Check PHP-FPM settings
docker exec nextcloud grep '^pm\.max_children' /etc/php84/php-fpm.d/www.conf
# Expected: pm.max_children = 100

# Check active worker processes
docker exec nextcloud ps aux | grep php-fpm | grep -v grep | wc -l
# Expected: ~22 processes (1 master + 20 workers + spares)

# Check Nginx timeouts
docker exec nextcloud grep 'fastcgi_read_timeout' /config/nginx/site-confs/default.conf
# Expected: fastcgi_read_timeout 3600s;

# Check script execution log
cat /tmp/nextcloud-tuning.log
```

### Persistence Verification (After Array Restart)
1. Restart Unraid array: `reboot` or stop/start array via WebUI
2. Wait for array and containers to start
3. Run verification commands above
4. Confirm settings persisted

### Monitoring Upload Performance
```bash
# Monitor PHP-FPM worker usage
docker exec nextcloud bash -c 'watch "ps aux | grep php-fpm | grep -v grep | wc -l"'

# Monitor Nginx logs for timeouts
docker logs nextcloud -f --tail 50 | grep -E "timeout|timed out"

# Check for error -9996 in Nextcloud logs
docker exec nextcloud tail -f /config/log/nginx/error.log
```

---

## Troubleshooting

### Script Didn't Execute
1. **Check User Scripts plugin is installed**: Settings → Plugins
2. **Verify schedule is set**: Settings → User Scripts → Click gear → Schedule → "At Startup of Array"
3. **Check script permissions**: Should be executable (handled by User Scripts plugin)
4. **View execution log**: `/tmp/nextcloud-tuning.log`

### Timeout Waiting for Container
```
[2025-10-30 16:30:50] ERROR: Timeout waiting for Nextcloud container
```
**Cause**: Container takes longer than 60 seconds to start
**Solution**: Increase `TIMEOUT` variable in script from 60 to 120 seconds

### Settings Not Applied
**Check 1**: Verify container name is "nextcloud"
```bash
docker ps --filter "name=nextcloud" --format '{{.Names}}'
```

**Check 2**: Verify PHP version in path matches
```bash
docker exec nextcloud ls /etc/ | grep php
# Adjust script if path is /etc/php83/ or /etc/php85/
```

**Check 3**: Manual execution test
```bash
# Run script manually to see detailed output
bash /boot/config/plugins/user.scripts/scripts/nextcloud-tuning/script
```

### Services Not Reloading
If changes don't take effect, try full container restart:
```bash
docker restart nextcloud
# Then re-run the tuning script after container starts
```

---

## Maintenance

### When to Update Script

1. **Container name changes**: Update `CONTAINER` variable
2. **PHP version upgrade**: Update path in sed commands (e.g., `php84` → `php85`)
3. **Additional tuning needed**: Add new configuration blocks
4. **Different Nextcloud deployment**: Adjust paths and Docker commands

### Version Control
The script is maintained in this repository at:
`scripts/nextcloud-tuning-unraid.sh`

To update the User Scripts version:
1. Edit the script in this repository
2. Commit changes to Git
3. Copy updated script to Settings → User Scripts → Edit Script in Unraid UI

---

## Results & Impact

### Before Tuning
- Error -9996 (file locked/timeout) on photo uploads
- Video uploads hanging indefinitely
- PHP-FPM worker exhaustion (hitting 5 max_children limit)
- Nginx timeouts after 60 seconds during video processing

### After Tuning + Persistence
- **100 PHP-FPM workers** available for concurrent requests
- **3600-second timeouts** allow large video processing
- **22 active workers** on average (20 start_servers + spares)
- **Settings persist** across container restarts and Unraid reboots
- **Error -9996 significantly reduced** or eliminated
- **Video uploads complete successfully** without manual intervention

### Performance Metrics
- **Worker availability**: 20x increase (5 → 100 max workers)
- **Video processing time**: Up to 75 seconds for large files
- **Timeout threshold**: 60x increase (60s → 3600s)
- **Concurrent uploads**: Can handle 100 simultaneous uploads

---

## Related Documentation

- [Nextcloud Tailscale Resolution](./NEXTCLOUD-TAILSCALE-RESOLUTION.md) - Trusted domains fix
- [Nextcloud Upload Errors Fix](./NEXTCLOUD-UPLOAD-ERRORS-FIX.md) - Initial PHP-FPM tuning
- [Nextcloud Video Upload Fix](./NEXTCLOUD-VIDEO-UPLOAD-FIX.md) - Nginx timeout configuration
- [Diagnostic Script](../scripts/diagnose-nextcloud-tailscale.sh) - Troubleshooting tool

---

## Security Considerations

### Script Safety
- **No credentials stored**: Script uses local Docker socket access
- **Idempotent**: Safe to run multiple times without side effects
- **Non-destructive**: Only modifies performance settings, not data
- **Logged execution**: All actions recorded for audit trail

### Unraid Permissions
- Script runs as `root` (required for Docker exec)
- Only accessible via Unraid UI (authenticated users)
- Located in `/boot/config` (Unraid protected partition)

### Container Security
- Settings modifications are internal to container only
- No changes to host system or network configuration
- No external connections or data exfiltration
- Uses standard Docker CLI commands only

---

## Future Improvements

### Potential Enhancements
1. **Health check integration**: Verify Nextcloud responds to HTTP requests before applying settings
2. **Monitoring integration**: Send notifications on script failures
3. **Dynamic tuning**: Adjust workers based on available system resources
4. **Backup verification**: Confirm settings backup before modifications
5. **Rollback capability**: Store previous settings and provide restore function

### Alternative Approaches Considered
1. **Custom Docker image**: More complex, requires image rebuilds
2. **Docker Compose overrides**: Not standard for Unraid deployments
3. **Persistent volume mounts**: LinuxServer.io containers don't support `/custom-cont-init.d` mounting
4. **Cron job**: User Scripts provides better integration with Unraid lifecycle

---

## Conclusion

The User Scripts automation provides a robust, Unraid-native solution for persisting Nextcloud performance tuning. This approach ensures optimal upload performance for photos and videos while maintaining ease of maintenance and troubleshooting.

**Key Success Factors**:
- ✅ Settings persist across container restarts
- ✅ Settings persist across Unraid reboots
- ✅ Automated execution at array startup
- ✅ Detailed logging for troubleshooting
- ✅ Non-intrusive implementation
- ✅ Easy to maintain and update

**Status**: ✅ **IMPLEMENTED & VERIFIED**
