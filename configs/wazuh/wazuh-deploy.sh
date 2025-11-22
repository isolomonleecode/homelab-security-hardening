#!/bin/bash

# Wazuh SIEM Quick Deployment Script
# Author: Latrent Childs
# Date: November 19, 2025
# Purpose: Automated Wazuh SIEM deployment for homelab security monitoring

set -e

echo "═════════════════════════════════════════════════════════════"
echo "  Wazuh SIEM Deployment for Homelab Security Monitoring"
echo "  Author: Latrent Childs | Security+ Certified"
echo "═════════════════════════════════════════════════════════════"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}[INFO]${NC} Deployment directory: $SCRIPT_DIR"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Docker is not running. Please start Docker first."
    exit 1
fi

echo -e "${GREEN}[✓]${NC} Docker is running"

# Check system resources
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 4 ]; then
    echo -e "${YELLOW}[WARNING]${NC} System has less than 4GB RAM. Wazuh may run slowly."
    echo -e "    Current RAM: ${TOTAL_MEM}GB | Recommended: 4GB+"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}[✓]${NC} Sufficient RAM available: ${TOTAL_MEM}GB"
fi

# Download official Wazuh Docker compose file
echo ""
echo -e "${YELLOW}[INFO]${NC} Downloading official Wazuh Docker configuration..."

cd "$SCRIPT_DIR"

# Create clean deployment using official single-node config
if [ ! -f "generate-indexer-certs.yml" ]; then
    echo -e "${YELLOW}[INFO]${NC} Downloading Wazuh Docker files..."

    # Download single-node deployment
    curl -so docker-compose-official.yml https://raw.githubusercontent.com/wazuh/wazuh-docker/v4.9.0/single-node/docker-compose.yml

    # Download certificate generation config
    curl -so generate-indexer-certs.yml https://raw.githubusercontent.com/wazuh/wazuh-docker/v4.9.0/single-node/generate-indexer-certs.yml

    # Download certificate generation script
    curl -so wazuh-certificates-tool.sh https://raw.githubusercontent.com/wazuh/wazuh-docker/v4.9.0/single-node/config/wazuh_indexer_ssl_certs/wazuh-certificates-tool.sh
    chmod +x wazuh-certificates-tool.sh

    echo -e "${GREEN}[✓]${NC} Downloaded Wazuh configuration files"
else
    echo -e "${GREEN}[✓]${NC} Wazuh configuration files already exist"
fi

# Generate SSL certificates
echo ""
echo -e "${YELLOW}[INFO]${NC} Generating SSL certificates for secure communication..."

if [ ! -d "wazuh-certificates" ]; then
    docker run --rm -v "$(pwd)":/certificates wazuh/wazuh-certs-generator:0.0.2 \
        -A

    echo -e "${GREEN}[✓]${NC} SSL certificates generated"
else
    echo -e "${GREEN}[✓]${NC} SSL certificates already exist"
fi

# Use official docker-compose file
if [ -f "docker-compose-official.yml" ]; then
    cp docker-compose-official.yml docker-compose.yml
    echo -e "${GREEN}[✓]${NC} Using official Wazuh Docker Compose configuration"
fi

# Deploy Wazuh stack
echo ""
echo -e "${YELLOW}[INFO]${NC} Starting Wazuh SIEM stack..."
echo -e "    This will start 3 containers: Manager, Indexer, Dashboard"

docker-compose up -d

echo ""
echo -e "${GREEN}[✓]${NC} Wazuh containers started"

# Wait for services to be ready
echo ""
echo -e "${YELLOW}[INFO]${NC} Waiting for services to initialize (this may take 2-3 minutes)..."

sleep 10

# Check container status
echo ""
echo "Container Status:"
docker-compose ps

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
echo "📊 Default Credentials (CHANGE THESE IN PRODUCTION!):"
echo "   - Web UI: admin / SecretPassword"
echo "   - API: wazuh-wui / MyS3cr37P450r.*-"
echo ""
echo "📋 Next Steps:"
echo "   1. Log into dashboard: https://$SERVER_IP"
echo "   2. Navigate to 'Agents' to verify manager is ready"
echo "   3. Deploy agents to your Docker containers"
echo "   4. Configure security rules and alerts"
echo ""
echo "🔧 Useful Commands:"
echo "   View logs:    docker-compose logs -f"
echo "   Stop stack:   docker-compose down"
echo "   Restart:      docker-compose restart"
echo ""
echo "📖 Full documentation: ./README.md"
echo "═════════════════════════════════════════════════════════════"
