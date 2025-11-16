#!/bin/bash
# Configure Firewall for Home SOC Monitoring
# Opens ports for Prometheus (metrics) and Promtail (logs)
# Only allows connections from LAN (192.168.0.0/24)

set -e

echo "=========================================="
echo "Configuring Firewall for Monitoring"
echo "=========================================="
echo ""

# Check if firewalld is running
if systemctl is-active --quiet firewalld; then
    echo "✅ firewalld is active"

    # Add rich rules to allow node_exporter from LAN only
    echo "[1/3] Opening port 9100 (node_exporter) for LAN..."
    sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.0/24" port port="9100" protocol="tcp" accept' 2>/dev/null || \
    sudo firewall-cmd --permanent --zone=public --add-port=9100/tcp

    # Add rich rules to allow Promtail from LAN only
    echo "[2/3] Opening port 9080 (promtail) for LAN..."
    sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.0/24" port port="9080" protocol="tcp" accept' 2>/dev/null || \
    sudo firewall-cmd --permanent --zone=public --add-port=9080/tcp

    # Reload firewalld
    echo "[3/3] Reloading firewall..."
    sudo firewall-cmd --reload

    echo "✅ Firewall configured"
    echo ""
    echo "Open ports:"
    sudo firewall-cmd --list-ports
    echo ""
    echo "Rich rules:"
    sudo firewall-cmd --list-rich-rules | grep -E "(9100|9080)" || echo "  (Using simple port rules)"

elif command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "✅ UFW is active"

    echo "[1/2] Opening port 9100 (node_exporter) for LAN..."
    sudo ufw allow from 192.168.0.0/24 to any port 9100 proto tcp comment 'node_exporter metrics'

    echo "[2/2] Opening port 9080 (promtail) for LAN..."
    sudo ufw allow from 192.168.0.0/24 to any port 9080 proto tcp comment 'promtail logs'

    echo "✅ Firewall configured"
    echo ""
    sudo ufw status numbered | grep -E "(9100|9080)"

else
    echo "⚠️  No firewall detected (firewalld or UFW)"
    echo "Ports 9100 and 9080 should be accessible"
fi

echo ""
echo "=========================================="
echo "Testing Connectivity"
echo "=========================================="
echo ""

# Test local connectivity
echo "Testing localhost:9100..."
if curl -s http://localhost:9100/metrics | head -1 | grep -q "HELP"; then
    echo "✅ node_exporter responding locally"
else
    echo "⚠️  node_exporter not responding on localhost"
fi

echo ""
echo "Testing localhost:9080..."
if curl -s http://localhost:9080/ready | grep -q "ready"; then
    echo "✅ Promtail responding locally"
else
    echo "⚠️  Promtail may not be ready yet"
fi

echo ""
echo "Done! Prometheus on 192.168.0.19 should now be able to scrape metrics."
echo ""
