#!/bin/bash
#
# Vaultwarden Backup Automation Setup
# Configures automated backups before updates and on schedule
#
# Usage: ./setup-backup-automation.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

log_section "Vaultwarden Backup Automation Setup"

# Create backup directory
log_info "Creating backup directory..."
sudo mkdir -p /data/vaultwarden-backups
sudo chown -R automation:automation /data/vaultwarden-backups
log_info "✅ Backup directory created: /data/vaultwarden-backups"

# Copy backup script to system location
log_info "Installing backup script..."
sudo cp /home/automation/scripts/backup-vaultwarden.sh /usr/local/bin/backup-vaultwarden
sudo chmod +x /usr/local/bin/backup-vaultwarden
log_info "✅ Backup script installed to /usr/local/bin/backup-vaultwarden"

# Test the backup script
log_info "Testing backup script..."
if /usr/local/bin/backup-vaultwarden; then
    log_info "✅ Test backup successful!"
else
    log_error "❌ Test backup failed - please check Vaultwarden container"
    exit 1
fi

# Set up cron job for automated backups
log_section "Setting up Scheduled Backups"

CRON_JOB="0 2 * * * /usr/local/bin/backup-vaultwarden >> /var/log/vaultwarden-backup.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "backup-vaultwarden"; then
    log_info "Cron job already exists"
else
    log_info "Adding cron job for daily backups at 2 AM..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    log_info "✅ Cron job added"
fi

# Create log rotation config
log_info "Setting up log rotation..."
sudo tee /etc/logrotate.d/vaultwarden-backup > /dev/null <<EOF
/var/log/vaultwarden-backup.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0644 automation automation
}
EOF
log_info "✅ Log rotation configured"

# Create systemd timer (alternative to cron)
log_section "Creating Systemd Timer (Alternative to Cron)"

sudo tee /etc/systemd/system/vaultwarden-backup.service > /dev/null <<EOF
[Unit]
Description=Vaultwarden Backup Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=automation
ExecStart=/usr/local/bin/backup-vaultwarden
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/vaultwarden-backup.timer > /dev/null <<EOF
[Unit]
Description=Vaultwarden Daily Backup Timer
Requires=vaultwarden-backup.service

[Timer]
OnCalendar=daily
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

log_info "Reloading systemd..."
sudo systemctl daemon-reload

log_info "Enabling backup timer..."
sudo systemctl enable vaultwarden-backup.timer
sudo systemctl start vaultwarden-backup.timer

log_info "✅ Systemd timer enabled"

# Show timer status
log_info "Timer status:"
sudo systemctl status vaultwarden-backup.timer --no-pager || true

# Create pre-update hook
log_section "Creating Pre-Update Hook"

sudo tee /usr/local/bin/pre-update-hook > /dev/null <<'EOF'
#!/bin/bash
# Pre-update hook - runs before container updates

CONTAINER_NAME="$1"

case "$CONTAINER_NAME" in
    vaultwarden)
        echo "Running Vaultwarden backup before update..."
        /usr/local/bin/backup-vaultwarden
        ;;
    pihole)
        echo "Backing up Pi-hole configuration..."
        docker exec pihole pihole -a -t > "/tmp/pihole_backup_$(date +%Y%m%d_%H%M%S).tar.gz" 2>/dev/null || true
        ;;
    *)
        echo "No backup needed for $CONTAINER_NAME"
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/pre-update-hook
log_info "✅ Pre-update hook created"

# Summary
log_section "Setup Complete!"

cat <<EOF
${GREEN}✅ Backup automation configured successfully!${NC}

${BLUE}What was set up:${NC}

1. ${GREEN}Backup Directory:${NC} /data/vaultwarden-backups
   - 30-day retention policy
   - Automatic compression

2. ${GREEN}Scheduled Backups:${NC}
   - Daily at 2:00 AM
   - Via cron: $(crontab -l | grep backup-vaultwarden)
   - Via systemd timer: vaultwarden-backup.timer

3. ${GREEN}Backup Script:${NC} /usr/local/bin/backup-vaultwarden
   - Manual usage: sudo backup-vaultwarden

4. ${GREEN}Pre-Update Hook:${NC} /usr/local/bin/pre-update-hook
   - Automatically backs up critical containers before updates

5. ${GREEN}Logging:${NC} /var/log/vaultwarden-backup.log
   - 7-day rotation policy

${BLUE}Next Steps:${NC}

1. Test manual backup:
   ${YELLOW}sudo /usr/local/bin/backup-vaultwarden${NC}

2. Verify timer is running:
   ${YELLOW}sudo systemctl status vaultwarden-backup.timer${NC}

3. Check backup files:
   ${YELLOW}ls -lh /data/vaultwarden-backups${NC}

4. View backup logs:
   ${YELLOW}tail -f /var/log/vaultwarden-backup.log${NC}

${BLUE}Restore Instructions:${NC}

If you need to restore from backup:

1. Stop Vaultwarden:
   ${YELLOW}docker stop vaultwarden${NC}

2. Decompress backup:
   ${YELLOW}gunzip /data/vaultwarden-backups/vault_backup_YYYYMMDD_HHMMSS.sqlite3.gz${NC}

3. Copy to container:
   ${YELLOW}docker cp /data/vaultwarden-backups/vault_backup_*.sqlite3 vaultwarden:/data/db.sqlite3${NC}

4. Start Vaultwarden:
   ${YELLOW}docker start vaultwarden${NC}

EOF
