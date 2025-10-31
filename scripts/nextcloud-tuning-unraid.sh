#!/bin/bash
# Nextcloud Performance Tuning Script for Unraid
# Add this to User Scripts plugin and set to run "At Startup of Array"
# This ensures PHP-FPM and Nginx settings persist across container restarts

set -e

CONTAINER="nextcloud"
LOGFILE="/tmp/nextcloud-tuning.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "=== Starting Nextcloud Performance Tuning ==="

# Wait for container to be fully started
log "Waiting for Nextcloud container to be ready..."
TIMEOUT=60
ELAPSED=0
while ! docker ps --filter "name=${CONTAINER}" --filter "status=running" --format '{{.Names}}' | grep -q "^${CONTAINER}$"; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        log "ERROR: Timeout waiting for Nextcloud container"
        exit 1
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

# Additional wait for services to initialize
log "Container running, waiting for services to initialize..."
sleep 15

# Apply PHP-FPM tuning
log "Applying PHP-FPM worker pool tuning..."
docker exec ${CONTAINER} sed -i "s/^pm\.max_children = .*/pm.max_children = 200/" /etc/php84/php-fpm.d/www.conf
docker exec ${CONTAINER} sed -i "s/^pm\.start_servers = .*/pm.start_servers = 40/" /etc/php84/php-fpm.d/www.conf
docker exec ${CONTAINER} sed -i "s/^pm\.min_spare_servers = .*/pm.min_spare_servers = 20/" /etc/php84/php-fpm.d/www.conf
docker exec ${CONTAINER} sed -i "s/^pm\.max_spare_servers = .*/pm.max_spare_servers = 60/" /etc/php84/php-fpm.d/www.conf
log "PHP-FPM settings: max_children=200, start=40, min_spare=20, max_spare=60"

# Apply Nginx timeout tuning
log "Applying Nginx timeout configuration..."

# Add fastcgi timeouts if not present
if ! docker exec ${CONTAINER} grep -q "fastcgi_read_timeout" /config/nginx/site-confs/default.conf; then
    docker exec ${CONTAINER} sed -i '/fastcgi_intercept_errors on;/a\        fastcgi_read_timeout 3600s;\n        fastcgi_send_timeout 3600s;' /config/nginx/site-confs/default.conf
    log "Added fastcgi_read_timeout and fastcgi_send_timeout (3600s)"
else
    log "FastCGI timeouts already present"
fi

# Update client_body_timeout
docker exec ${CONTAINER} sed -i "s/client_body_timeout .*/client_body_timeout 3600s;/" /config/nginx/site-confs/default.conf
log "Set client_body_timeout to 3600s"

# Reload services to apply changes
log "Reloading PHP-FPM and Nginx..."
docker exec ${CONTAINER} bash -c "killall -USR2 php-fpm84 2>/dev/null || true"
docker exec ${CONTAINER} nginx -s reload 2>/dev/null || true

# Apply MariaDB tuning
DB_CONTAINER="nextcloud-db"
log "Applying MariaDB performance tuning..."

if docker ps --filter "name=${DB_CONTAINER}" --filter "status=running" --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    # Create MariaDB config file
    docker exec ${DB_CONTAINER} sh -c 'cat > /etc/mysql/conf.d/nextcloud-tuning.cnf << EOF
[mysqld]
innodb_lock_wait_timeout = 300
max_connections = 300
innodb_buffer_pool_size = 2G
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
EOF'

    # Restart MariaDB to apply settings
    log "Restarting MariaDB container to apply settings..."
    docker restart ${DB_CONTAINER}
    sleep 15
    log "MariaDB settings: lock_timeout=300s, max_connections=300, buffer_pool=2G"
else
    log "WARNING: MariaDB container not found, skipping database tuning"
fi

# Verify settings
log "Verifying applied settings..."
MAX_CHILDREN=$(docker exec ${CONTAINER} grep "^pm.max_children" /etc/php84/php-fpm.d/www.conf | awk '{print $3}')
FASTCGI_TIMEOUT=$(docker exec ${CONTAINER} grep "fastcgi_read_timeout" /config/nginx/site-confs/default.conf | head -1 | grep -o '[0-9]\+')

log "Verified: pm.max_children = ${MAX_CHILDREN}"
log "Verified: fastcgi_read_timeout = ${FASTCGI_TIMEOUT}s"

log "=== Nextcloud Performance Tuning Complete ==="
log "Settings will persist until container is recreated or updated"
log "Log file: $LOGFILE"
