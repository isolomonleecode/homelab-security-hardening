#!/bin/bash
#
# Docker Compose Stack Update Script
# Safely updates all docker-compose stacks on Raspberry Pi
#
# Usage: ./update-compose-stacks.sh [stack_name]
#   No arguments: Updates all stacks
#   stack_name: Updates specific stack (loki-stack, homeassistant, saml-lab)
#
# Safety features:
# - Backups before updates
# - Health checks after updates
# - Automatic rollback on failure

set -euo pipefail

# Configuration
COMPOSE_DIRS=(
    "/home/automation/docker/loki-stack"
    "/home/automation/homeassistant"
    "/home/automation/docker/saml-lab"
)

STACK_NAMES=(
    "loki-stack"
    "homeassistant"
    "saml-lab"
)

# Notification URL (optional)
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

# Check if specific stack requested
TARGET_STACK="${1:-all}"

update_stack() {
    local stack_dir="$1"
    local stack_name="$2"

    log_section "Updating Stack: $stack_name"

    if [[ ! -d "$stack_dir" ]]; then
        log_error "Stack directory not found: $stack_dir"
        return 1
    fi

    cd "$stack_dir" || return 1

    # Backup current docker-compose.yml
    log_info "Backing up docker-compose.yml..."
    cp docker-compose.yml "docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"

    # Get current container states
    log_info "Checking current container health..."
    docker compose ps

    # Pull latest images
    log_info "Pulling latest images..."
    if ! docker compose pull; then
        log_error "Failed to pull images for $stack_name"
        notify "❌ Failed to pull images for $stack_name"
        return 1
    fi

    # Show what will change
    log_info "Images that will be updated:"
    docker compose config --images

    # Update containers
    log_info "Recreating containers with new images..."
    if ! docker compose up -d --remove-orphans; then
        log_error "Failed to recreate containers for $stack_name"
        notify "❌ Failed to update $stack_name stack"

        # Attempt rollback
        log_warn "Attempting rollback..."
        docker compose down
        mv "docker-compose.yml.backup.$(date +%Y%m%d)_"* docker-compose.yml 2>/dev/null || true
        docker compose up -d
        return 1
    fi

    # Wait for containers to stabilize
    log_info "Waiting for containers to stabilize (15 seconds)..."
    sleep 15

    # Health check
    log_info "Checking container health..."
    docker compose ps

    # Verify all containers are running
    UNHEALTHY=$(docker compose ps --format json | jq -r 'select(.State != "running") | .Name' 2>/dev/null || true)

    if [[ -n "$UNHEALTHY" ]]; then
        log_error "Some containers are not healthy:"
        echo "$UNHEALTHY"
        notify "⚠️ $stack_name updated but some containers unhealthy"
        return 1
    fi

    log_info "✅ Stack '$stack_name' updated successfully!"
    notify "✅ Stack '$stack_name' updated successfully"

    # Show logs for verification
    log_info "Recent logs (last 20 lines):"
    docker compose logs --tail=20

    return 0
}

# Main execution
log_section "Docker Compose Stack Updater"
log_info "Target: $TARGET_STACK"
log_info "Date: $(date)"

UPDATED_COUNT=0
FAILED_COUNT=0

for i in "${!STACK_NAMES[@]}"; do
    stack_name="${STACK_NAMES[$i]}"
    stack_dir="${COMPOSE_DIRS[$i]}"

    # Skip if specific stack requested and this isn't it
    if [[ "$TARGET_STACK" != "all" ]] && [[ "$TARGET_STACK" != "$stack_name" ]]; then
        continue
    fi

    if update_stack "$stack_dir" "$stack_name"; then
        ((UPDATED_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
done

# Summary
log_section "Update Summary"
log_info "Successfully updated: $UPDATED_COUNT stack(s)"
if [[ $FAILED_COUNT -gt 0 ]]; then
    log_error "Failed updates: $FAILED_COUNT stack(s)"
    notify "⚠️ Stack updates complete: $UPDATED_COUNT success, $FAILED_COUNT failed"
    exit 1
else
    log_info "🎉 All stack updates completed successfully!"
    notify "✅ All Docker Compose stacks updated successfully"
fi

# Cleanup old backups (keep last 10)
log_info "Cleaning up old backup files..."
for stack_dir in "${COMPOSE_DIRS[@]}"; do
    if [[ -d "$stack_dir" ]]; then
        find "$stack_dir" -name "docker-compose.yml.backup.*" -type f | sort -r | tail -n +11 | xargs rm -f 2>/dev/null || true
    fi
done

log_info "Done!"
