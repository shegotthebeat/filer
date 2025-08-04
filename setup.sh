#!/bin/bash
set -e

echo "🚀 Pi 5 File Server Setup Starting..."
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please run as regular user, not root!"
    exit 1
fi

print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

print_status "Installing required packages..."
sudo apt install -y python3 python3-pip python3-venv git curl htop

print_status "Checking for external SSD..."
if ! df -h | grep -q "/mnt/storage"; then
    print_warning "External SSD not mounted at /mnt/storage"
    echo "Please run: ./scripts/mount_ssd.sh first"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_status "SSD found at /mnt/storage"
fi

print_status "Setting up file service..."
./install_service.sh

print_status "Checking Cloudflare tunnel..."
if ! command -v cloudflared &> /dev/null; then
    print_warning "Cloudflare tunnel not installed"
    echo "Installing cloudflared..."
    
    # Download and install cloudflared
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
    sudo dpkg -i cloudflared-linux-arm64.deb
    rm cloudflared-linux-arm64.deb
    
    print_status "Cloudflared installed"
else
    print_status "Cloudflared already installed"
fi

print_status "Setting up Cloudflare config directory..."
mkdir -p ~/.cloudflared

if [ ! -f ~/.cloudflared/config.yml ]; then
    print_status "Copying Cloudflare config template..."
    cp config/cloudflare.yml ~/.cloudflared/config.yml
    print_warning "IMPORTANT: Edit ~/.cloudflared/config.yml with your tunnel details!"
else
    print_status "Cloudflare config already exists"
fi

print_status "Setting up systemd services..."

# Copy service file template
sudo cp config/file-service.service /etc/systemd/system/
sudo sed -i "s/YOUR_USERNAME/$(whoami)/g" /etc/systemd/system/file-service.service
sudo sed -i "s|/home/YOUR_USERNAME|$HOME|g" /etc/systemd/system/file-service.service

# Create cloudflared systemd service
print_status "Creating cloudflared systemd service..."
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

# Reload systemd
sudo systemctl daemon-reload

print_status "Enabling services for auto-start..."
sudo systemctl enable file-service
sudo systemctl enable cloudflared

print_status "Creating storage directories..."
mkdir -p /mnt/storage/uploads
mkdir -p /mnt/storage/data
mkdir -p /mnt/storage/media
mkdir -p /mnt/storage/backups

print_status "Setting permissions..."
sudo chown -R $(whoami):$(whoami) /mnt/storage 2>/dev/null || print_warning "Could not set storage permissions (SSD may not be mounted)"

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Next steps:"
echo "1. Edit ~/.cloudflared/config.yml with your tunnel details"
echo "2. Add DNS routes: cloudflared tunnel route dns YOUR_TUNNEL_ID files.yourdomain.com"
echo "3. Run: ./start_services.sh"
echo ""
echo "Configuration files:"
echo "- File service: ~/services/file_service.py"  
echo "- Cloudflare config: ~/.cloudflared/config.yml"
echo "- Service config: /etc/systemd/system/file-service.service"
echo ""
echo "Run './scripts/health_check.sh' to verify everything is working!"
