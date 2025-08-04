#!/bin/bash

echo "🚀 Starting All Services..."
echo "============================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Start file service
print_status "Starting file service..."
if sudo systemctl start file-service; then
    print_status "File service started"
else
    print_error "Failed to start file service"
fi

# Start cloudflared
print_status "Starting Cloudflare tunnel..."
if sudo systemctl list-unit-files | grep -q cloudflared; then
    if sudo systemctl start cloudflared; then
        print_status "Cloudflare tunnel started"
    else
        print_error "Failed to start Cloudflare tunnel"
    fi
else
    print_warning "Cloudflared service not found, creating it..."
    
    # Create the service file
    sudo tee /etc/systemd/system/cloudflared.service > /dev/null << EOF
[Unit]
Description=Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(whoami)
ExecStart=/usr/local/bin/cloudflared tunnel run
WorkingDirectory=$HOME/.cloudflared
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload and enable
    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared
    
    if sudo systemctl start cloudflared; then
        print_status "Cloudflare tunnel service created and started"
    else
        print_error "Failed to start Cloudflare tunnel"
    fi
fi

echo ""
print_status "Checking service status..."

# Check file service
if sudo systemctl is-active --quiet file-service; then
    echo -e "✅ File service: ${GREEN}Running${NC}"
else
    echo -e "❌ File service: ${RED}Not running${NC}"
fi

# Check cloudflared
if sudo systemctl is-active --quiet cloudflared; then
    echo -e "✅ Cloudflare tunnel: ${GREEN}Running${NC}"
else
    echo -e "❌ Cloudflare tunnel: ${RED}Not running${NC}"
fi

echo ""
print_status "Testing local connections..."

# Test file service
if curl -s http://localhost:5001 > /dev/null; then
    echo -e "✅ File service (port 5001): ${GREEN}Responding${NC}"
else
    echo -e "❌ File service (port 5001): ${RED}Not responding${NC}"
fi

# Test if port 5000 is active (main app)
if curl -s http://localhost:5000 > /dev/null; then
    echo -e "✅ Main app (port 5000): ${GREEN}Responding${NC}"
else
    echo -e "❌ Main app (port 5000): ${RED}Not responding${NC}"
fi

echo ""
echo "🎯 Service URLs:"
echo "- Local file service: http://localhost:5001"
echo "- Main app: http://localhost:5000"
echo ""
echo "📊 Check detailed status:"
echo "- File service: sudo systemctl status file-service"
echo "- Cloudflare: sudo systemctl status cloudflared"
echo ""
echo "📋 View logs:"
echo "- File service: sudo journalctl -u file-service -f"
echo "- Cloudflare: sudo journalctl -u cloudflared -f"
