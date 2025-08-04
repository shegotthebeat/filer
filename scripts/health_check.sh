#!/bin/bash

echo "🏥 System Health Check"
echo "======================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_ok() {
    echo -e "✅ $1: ${GREEN}OK${NC}"
}

check_fail() {
    echo -e "❌ $1: ${RED}FAILED${NC}"
}

check_warn() {
    echo -e "⚠️  $1: ${YELLOW}WARNING${NC}"
}

echo ""
echo "🔍 Checking System Components..."
echo "================================="

# Check SSD mount
if df -h | grep -q "/mnt/storage"; then
    storage_info=$(df -h /mnt/storage | tail -1)
    available=$(echo $storage_info | awk '{print $4}')
    check_ok "SSD Mount ($available available)"
else
    check_fail "SSD Mount (not mounted at /mnt/storage)"
fi

# Check file service
if sudo systemctl is-active --quiet file-service; then
    check_ok "File Service (systemd)"
else
    check_fail "File Service (systemd not active)"
fi

# Check file service response
if curl -s http://localhost:5001 > /dev/null; then
    check_ok "File Service (HTTP response)"
else
    check_fail "File Service (not responding on port 5001)"
fi

# Check cloudflare tunnel
if sudo systemctl is-active --quiet cloudflared; then
    check_ok "Cloudflare Tunnel (systemd)"
else
    check_warn "Cloudflare Tunnel (systemd not active)"
fi

# Check main app port
if curl -s http://localhost:5000 > /dev/null; then
    check_ok "Main App (port 5000)"
else
    check_warn "Main App (not responding on port 5000)"
fi

# Check Python virtual environment
if [ -f ~/services/file_service_env/bin/python ]; then
    if ~/services/file_service_env/bin/python -c "import flask" 2>/dev/null; then
        check_ok "Python Environment (Flask installed)"
    else
        check_fail "Python Environment (Flask not found)"
    fi
else
    check_fail "Python Environment (virtual env not found)"
fi

# Check upload directory
if [ -d "/mnt/storage/uploads" ] && [ -w "/mnt/storage/uploads" ]; then
    file_count=$(ls /mnt/storage/uploads 2>/dev/null | wc -l)
    check_ok "Upload Directory ($file_count files)"
else
    check_fail "Upload Directory (not accessible)"
fi

# Check configuration files
if [ -f ~/.cloudflared/config.yml ]; then
    check_ok "Cloudflare Config"
else
    check_warn "Cloudflare Config (not found)"
fi

if [ -f /etc/systemd/system/file-service.service ]; then
    check_ok "Systemd Service Config"
else
    check_fail "Systemd Service Config (not found)"
fi

echo ""
echo "📊 System Resources..."
echo "======================"

# Memory usage
memory_info=$(free -h | grep "Mem:")
memory_used=$(echo $memory_info | awk '{print $3}')
memory_total=$(echo $memory_info | awk '{print $2}')
echo "Memory: $memory_used / $memory_total"

# CPU load
load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
echo "Load Average: $load_avg"

# Disk usage
if df -h | grep -q "/mnt/storage"; then
    storage_usage=$(df -h /mnt/storage | tail -1 | awk '{print $5}')
    echo "Storage Used: $storage_usage"
fi

# Network connectivity
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    check_ok "Internet Connectivity"
else
    check_fail "Internet Connectivity"
fi

echo ""
echo "🔧 Quick Actions..."
echo "=================="
echo "View service logs:"
echo "  sudo journalctl -u file-service -n 20"
echo "  sudo journalctl -u cloudflared -n 20"
echo ""
echo "Restart services:"
echo "  ./start_services.sh"
echo ""
echo "Test file service manually:"
echo "  cd ~/services && ./file_service_env/bin/python file_service.py"
echo ""
echo "Check detailed status:"
echo "  sudo systemctl status file-service"
echo "  sudo systemctl status cloudflared"

# Summary
echo ""
echo "📋 Summary"
echo "=========="

failed_checks=0

# Count failures
if ! df -h | grep -q "/mnt/storage"; then ((failed_checks++)); fi
if ! sudo systemctl is-active --quiet file-service; then ((failed_checks++)); fi
if ! curl -s http://localhost:5001 > /dev/null; then ((failed_checks++)); fi

if [ $failed_checks -eq 0 ]; then
    echo -e "${GREEN}✅ All critical systems operational${NC}"
elif [ $failed_checks -lt 3 ]; then
    echo -e "${YELLOW}⚠️  $failed_checks issue(s) detected - check warnings above${NC}"
else
    echo -e "${RED}❌ Multiple critical issues detected - system needs attention${NC}"
fi
