#!/bin/bash

# Simplified Wazuh SIEM Deployment
# Author: Latrent Childs
# Uses official single-node deployment with pre-generated certificates

set -e

echo "═════════════════════════════════════════════════════════════"
echo "  Wazuh SIEM - Simplified Deployment"
echo "  Author: Latrent Childs | Security+ Certified"
echo "═════════════════════════════════════════════════════════════"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}[INFO]${NC} Working directory: $SCRIPT_DIR"
echo ""

# Check Docker
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Docker is not running. Please start Docker first."
    exit 1
fi
echo -e "${GREEN}[✓]${NC} Docker is running"

# Check system resources
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 4 ]; then
    echo -e "${YELLOW}[WARNING]${NC} System has ${TOTAL_MEM}GB RAM (4GB+ recommended)"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}[✓]${NC} Sufficient RAM: ${TOTAL_MEM}GB"
fi

# Clone official Wazuh Docker repository (simplified approach)
echo ""
echo -e "${YELLOW}[INFO]${NC} Setting up Wazuh deployment files..."

if [ ! -d "wazuh-docker" ]; then
    echo -e "${YELLOW}[INFO]${NC} Cloning official Wazuh Docker repository..."
    git clone https://github.com/wazuh/wazuh-docker.git --branch v4.9.0 --depth 1
    echo -e "${GREEN}[✓]${NC} Repository cloned"
else
    echo -e "${GREEN}[✓]${NC} Wazuh Docker repository already exists"
fi

# Navigate to single-node deployment
cd wazuh-docker/single-node

echo ""
echo -e "${YELLOW}[INFO]${NC} Generating SSL certificates..."

# Generate certificates using official script
docker compose -f generate-indexer-certs.yml run --rm generator

echo -e "${GREEN}[✓]${NC} Certificates generated"

# Start Wazuh stack
echo ""
echo -e "${YELLOW}[INFO]${NC} Starting Wazuh SIEM stack (3 containers)..."
echo -e "    - Wazuh Manager (security analysis engine)"
echo -e "    - Wazuh Indexer (event storage)"
echo -e "    - Wazuh Dashboard (web interface)"
echo ""

docker compose up -d

echo ""
echo -e "${GREEN}[✓]${NC} Wazuh containers started"

# Wait for services
echo ""
echo -e "${YELLOW}[INFO]${NC} Waiting for services to initialize (30 seconds)..."
sleep 30

# Check status
echo ""
echo "Container Status:"
docker compose ps

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "═════════════════════════════════════════════════════════════"
echo -e "${GREEN}  Wazuh SIEM Deployment Complete!${NC}"
echo "═════════════════════════════════════════════════════════════"
echo ""
echo "🌐 Access Wazuh Dashboard:"
echo "   URL: https://$SERVER_IP"
echo "   Username: admin"
echo "   Password: SecretPassword"
echo ""
echo "⚠️  Note: Browser will show SSL warning (self-signed cert)"
echo "   Click 'Advanced' → 'Proceed to site' to continue"
echo ""
echo "📋 Next Steps:"
echo "   1. Access dashboard in browser"
echo "   2. Login with credentials above"
echo "   3. Navigate to 'Agents' section"
echo "   4. Deploy your first agent (see QUICKSTART.md)"
echo ""
echo "🔧 Useful Commands:"
echo "   View logs:    cd $SCRIPT_DIR/wazuh-docker/single-node && docker compose logs -f"
echo "   Stop stack:   cd $SCRIPT_DIR/wazuh-docker/single-node && docker compose down"
echo "   Restart:      cd $SCRIPT_DIR/wazuh-docker/single-node && docker compose restart"
echo ""
echo "📖 Full documentation: $SCRIPT_DIR/README.md"
echo "═════════════════════════════════════════════════════════════"
