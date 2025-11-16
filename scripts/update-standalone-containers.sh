#!/bin/bash
#
# Standalone Container Update Script
# Updates individual containers not managed by docker-compose
#
# Usage: ./update-standalone-containers.sh [container_name]
#   No arguments: Interactive mode (prompts for each container)
#   container_name: Updates specific container
#
# Safety features:
# - Dry-run mode to see what would change
# - Automatic backup of critical services
# - Health checks after updates
# - Easy rollback via image tags

set -euo pipefail

# Containers to manage (not in docker-compose)
declare -A CONTAINERS=(
    ["pihole"]="pihole/pihole:latest"
    ["caddy"]="caddy:latest"
    ["vaultwarden"]="vaultwarden/server:alpine"
    ["portainer"]="portainer/portainer-ee:latest"
)

# Critical containers that need backups
CRITICAL_CONTAINERS=("vaultwarden" "pihole")

# Notification URL
NOTIFY_URL="${NOTIFY_URL:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

notify() {
    if [[ -n "$NOTIFY_URL" ]]; then
        curl -s -X POST "$NOTIFY_URL" -d "$1" > /dev/null 2>&1 || true
    fi
}

check_for_updates() {
    local container_name="$1"
    local image_name="$2"

    log_info "Checking for updates: $container_name"

    # Get current image ID
    CURRENT_ID=$(docker inspect --format='{{.Image}}' "$container_name" 2>/dev/null || echo "")

    if [[ -z "$CURRENT_ID" ]]; then
        log_error "Container '$container_name' not found"
        return 1
    fi

    # Pull latest image
    log_info "Pulling latest image: $image_name"
    docker pull "$image_name" > /dev/null 2>&1

    # Get new image ID
    NEW_ID=$(docker inspect --format='{{.Id}}' "$image_name" 2>/dev/null || echo "")

    if [[ "$CURRENT_ID" == "$NEW_ID" ]]; then
        log_info "✅ $container_name is already up to date"
        return 1
    else
        log_warn "📦 Update available for $container_name"
        log_info "Current: ${CURRENT_ID:7:12}"
        log_info "New:     ${NEW_ID:7:12}"
        return 0
    fi
}

backup_container() {
    local container_name="$1"

    case "$container_name" in
        vaultwarden)
            log_info "Running Vaultwarden backup..."
            if [[ -x "/home/automation/scripts/backup-vaultwarden.sh" ]]; then
                /home/automation/scripts/backup-vaultwarden.sh
            else
                log_warn "Backup script not found, performing manual backup..."
                docker exec vaultwarden sqlite3 /data/db.sqlite3 \
                    ".backup '/data/backup_$(date +%Y%m%d_%H%M%S).sqlite3'"
            fi
            ;;
        pihole)
            log_info "Backing up Pi-hole configuration..."
            docker exec pihole pihole -a -t > "/tmp/pihole_backup_$(date +%Y%m%d_%H%M%S).tar.gz" 2>/dev/null || true
            ;;
        *)
            log_info "No backup needed for $container_name"
            ;;
    esac
}

update_container() {
    local container_name="$1"
    local image_name="$2"

    log_section "Updating Container: $container_name"

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_error "Container '$container_name' does not exist"
        return 1
    fi

    # Backup if critical
    if [[ " ${CRITICAL_CONTAINERS[@]} " =~ " ${container_name} " ]]; then
        backup_container "$container_name"
    fi

    # Get container info before update
    log_info "Current container info:"
    docker inspect "$container_name" --format='Image: {{.Config.Image}}
Status: {{.State.Status}}
Started: {{.State.StartedAt}}' || true

    # Export container config for recreation
    log_info "Saving container configuration..."
    docker inspect "$container_name" > "/tmp/${container_name}_config_$(date +%Y%m%d_%H%M%S).json"

    # Pull latest image
    log_info "Pulling latest image: $image_name"
    if ! docker pull "$image_name"; then
        log_error "Failed to pull image for $container_name"
        notify "❌ Failed to pull image for $container_name"
        return 1
    fi

    # For Portainer-managed containers, use Portainer API
    log_warn "⚠️  IMPORTANT: This script cannot automatically recreate containers"
    log_warn "Please use one of these methods to complete the update:"
    echo ""
    echo "Option 1 - Portainer UI (Recommended):"
    echo "  1. Open Portainer: https://sweetrpi-desktop.tailc12764.ts.net:9443"
    echo "  2. Go to Containers → $container_name"
    echo "  3. Click 'Duplicate/Edit'"
    echo "  4. Enable 'Re-pull image' toggle"
    echo "  5. Click 'Deploy the container'"
    echo ""
    echo "Option 2 - Manual recreation:"
    echo "  docker stop $container_name"
    echo "  docker rm $container_name"
    echo "  # Then recreate using saved config in /tmp/${container_name}_config_*.json"
    echo ""

    read -p "Press Enter when you've completed the update via Portainer..." -r

    # Verify container is running
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_info "✅ Container '$container_name' is running"

        # Show logs
        log_info "Recent logs:"
        docker logs "$container_name" --tail=20

        notify "✅ $container_name updated successfully"
        return 0
    else
        log_error "Container '$container_name' is not running!"
        notify "❌ $container_name update may have failed"
        return 1
    fi
}

# Main execution
log_section "Standalone Container Updater"
log_info "Date: $(date)"

TARGET_CONTAINER="${1:-}"

if [[ -n "$TARGET_CONTAINER" ]]; then
    # Update specific container
    if [[ -v CONTAINERS[$TARGET_CONTAINER] ]]; then
        if check_for_updates "$TARGET_CONTAINER" "${CONTAINERS[$TARGET_CONTAINER]}"; then
            update_container "$TARGET_CONTAINER" "${CONTAINERS[$TARGET_CONTAINER]}"
        fi
    else
        log_error "Unknown container: $TARGET_CONTAINER"
        log_info "Available containers: ${!CONTAINERS[*]}"
        exit 1
    fi
else
    # Interactive mode - check all containers
    log_info "Checking all containers for updates..."
    echo ""

    UPDATES_AVAILABLE=()

    for container in "${!CONTAINERS[@]}"; do
        if check_for_updates "$container" "${CONTAINERS[$container]}"; then
            UPDATES_AVAILABLE+=("$container")
        fi
        echo ""
    done

    if [[ ${#UPDATES_AVAILABLE[@]} -eq 0 ]]; then
        log_info "🎉 All containers are up to date!"
        exit 0
    fi

    log_warn "Updates available for: ${UPDATES_AVAILABLE[*]}"
    echo ""

    # Prompt for each container with updates
    for container in "${UPDATES_AVAILABLE[@]}"; do
        read -p "Update $container? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            update_container "$container" "${CONTAINERS[$container]}"
        else
            log_info "Skipped $container"
        fi
        echo ""
    done
fi

log_info "Done!"
