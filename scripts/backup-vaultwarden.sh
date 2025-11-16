#!/bin/bash
#
# Vaultwarden Backup Script
# Automated backup of Vaultwarden database before updates
#
# Usage: ./backup-vaultwarden.sh
# Schedule: Run before updates or via cron

set -euo pipefail

# Configuration
BACKUP_DIR="/data/vaultwarden-backups"
CONTAINER_NAME="vaultwarden"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="vault_backup_${TIMESTAMP}.sqlite3"

# Notification settings (optional - configure ntfy.sh or similar)
NOTIFY_URL="${NOTIFY_URL:-}"  # Set via environment or leave empty

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

notify() {
    if [[ -n "$NOTIFY_URL" ]]; then
        curl -s -X POST "$NOTIFY_URL" -d "$1" > /dev/null 2>&1 || true
    fi
}

# Check if Vaultwarden container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_error "Vaultwarden container is not running!"
    exit 1
fi

# Create backup directory if it doesn't exist
if [[ ! -d "$BACKUP_DIR" ]]; then
    log_info "Creating backup directory: $BACKUP_DIR"
    sudo mkdir -p "$BACKUP_DIR"
    sudo chown -R automation:automation "$BACKUP_DIR"
fi

# Perform backup
log_info "Starting Vaultwarden backup..."
log_info "Backup file: $BACKUP_FILE"

# Check if container has sqlite3, if not use direct file copy
if docker exec "$CONTAINER_NAME" which sqlite3 > /dev/null 2>&1; then
    # Method 1: SQLite backup command (safest)
    log_info "Using SQLite backup command..."
    if docker exec "$CONTAINER_NAME" sqlite3 /data/db.sqlite3 ".backup '/data/backup.sqlite3'"; then
        docker cp "${CONTAINER_NAME}:/data/backup.sqlite3" "${BACKUP_DIR}/${BACKUP_FILE}"
        docker exec "$CONTAINER_NAME" rm -f /data/backup.sqlite3
    else
        log_error "SQLite backup command failed!"
        notify "❌ Vaultwarden backup failed - sqlite3 error"
        exit 1
    fi
else
    # Method 2: Direct file copy (works when sqlite3 not available)
    log_warn "sqlite3 not found in container, using direct file copy method..."
    log_info "Copying database files (db.sqlite3, db.sqlite3-shm, db.sqlite3-wal)..."

    # Create temporary directory for backup
    TEMP_BACKUP_DIR="/tmp/vaultwarden_backup_$$"
    mkdir -p "$TEMP_BACKUP_DIR"

    # Copy all SQLite files
    docker cp "${CONTAINER_NAME}:/data/db.sqlite3" "${TEMP_BACKUP_DIR}/"
    docker cp "${CONTAINER_NAME}:/data/db.sqlite3-shm" "${TEMP_BACKUP_DIR}/" 2>/dev/null || true
    docker cp "${CONTAINER_NAME}:/data/db.sqlite3-wal" "${TEMP_BACKUP_DIR}/" 2>/dev/null || true

    # Create tar archive
    tar -czf "${BACKUP_DIR}/${BACKUP_FILE}.tar.gz" -C "$TEMP_BACKUP_DIR" .

    # Clean up temp directory
    rm -rf "$TEMP_BACKUP_DIR"

    # Skip individual compression since we already made tar.gz
    if [[ -f "${BACKUP_DIR}/${BACKUP_FILE}.tar.gz" ]] && [[ -s "${BACKUP_DIR}/${BACKUP_FILE}.tar.gz" ]]; then
        COMPRESSED_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}.tar.gz" | cut -f1)
        log_info "✅ Backup completed successfully!"
        log_info "Size: $COMPRESSED_SIZE"
        log_info "Location: ${BACKUP_DIR}/${BACKUP_FILE}.tar.gz"
        notify "✅ Vaultwarden backup successful: ${BACKUP_FILE}.tar.gz ($COMPRESSED_SIZE)"
    else
        log_error "Backup file is empty or missing!"
        notify "❌ Vaultwarden backup failed - empty file"
        exit 1
    fi

    # Exit early since we already compressed
    ALREADY_COMPRESSED=true
fi

# Verify backup file exists and has size > 0
if [[ "${ALREADY_COMPRESSED:-false}" != "true" ]]; then
    if [[ -f "${BACKUP_DIR}/${BACKUP_FILE}" ]] && [[ -s "${BACKUP_DIR}/${BACKUP_FILE}" ]]; then
        BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
        log_info "✅ Backup completed successfully!"
        log_info "Size: $BACKUP_SIZE"
        log_info "Location: ${BACKUP_DIR}/${BACKUP_FILE}"

        # Compress backup to save space
        log_info "Compressing backup..."
        gzip "${BACKUP_DIR}/${BACKUP_FILE}"
        COMPRESSED_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}.gz" | cut -f1)
        log_info "Compressed size: $COMPRESSED_SIZE"

        notify "✅ Vaultwarden backup successful: ${BACKUP_FILE}.gz ($COMPRESSED_SIZE)"
    else
        log_error "Backup file is empty or missing!"
        notify "❌ Vaultwarden backup failed - empty file"
        exit 1
    fi
fi

# Clean up old backups (keep last 30 days)
log_info "Cleaning up backups older than ${RETENTION_DAYS} days..."
DELETED_COUNT=$(find "$BACKUP_DIR" \( -name "vault_backup_*.sqlite3.gz" -o -name "vault_backup_*.tar.gz" \) -type f -mtime +${RETENTION_DAYS} -delete -print | wc -l)
if [[ $DELETED_COUNT -gt 0 ]]; then
    log_info "Deleted $DELETED_COUNT old backup(s)"
fi

# List recent backups
log_info "Recent backups:"
ls -lh "$BACKUP_DIR" | tail -5

# Backup statistics
TOTAL_BACKUPS=$(find "$BACKUP_DIR" \( -name "vault_backup_*.sqlite3.gz" -o -name "vault_backup_*.tar.gz" \) -type f | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log_info "Total backups: $TOTAL_BACKUPS (using $TOTAL_SIZE)"

log_info "🎉 Backup process complete!"
