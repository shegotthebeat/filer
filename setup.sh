#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Pi 5 File Server Setup Starting...${NC}"
echo ""

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Warning: This doesn't appear to be a Raspberry Pi${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if SSD is mounted
if ! mount | grep -q "/mnt/storage"; then
    echo -e "${RED}❌ Error: SSD not mounted at /mnt/storage${NC}"
    echo "Please format and mount your SSD first:"
    echo "  sudo mkdir -p /mnt/storage"
    echo "  sudo mount /dev/sda1 /mnt/storage  # Replace sda1 with your SSD"
    echo "  sudo chown \$USER:\$USER /mnt/storage"
    exit 1
fi

echo -e "${GREEN}✅ SSD detected at /mnt/storage${NC}"

# Update system
echo -e "${BLUE}📦 Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo -e "${BLUE}📦 Installing dependencies...${NC}"
sudo apt install -y python3-venv python3-pip git curl wget

# Create services directory
echo -e "${BLUE}📁 Setting up services directory...${NC}"
mkdir -p ~/services
cd ~/services

# Create Python virtual environment
echo -e "${BLUE}🐍 Creating Python virtual environment...${NC}"
python3 -m venv file_service_env

# Install Python packages
echo -e "${BLUE}📦 Installing Python packages...${NC}"
source file_service_env/bin/activate

# Create requirements.txt if it doesn't exist
cat > requirements.txt << 'EOF'
Flask==2.3.3
requests==2.31.0
Werkzeug==2.3.7
EOF

pip install -r requirements.txt
deactivate

# Copy service file from repo
if [ -f "./services/file_service.py" ]; then
    echo -e "${BLUE}📄 Copying service files...${NC}"
    cp ./services/file_service.py .
else
    echo -e "${RED}❌ Error: services/file_service.py not found in repo${NC}"
    echo "Make sure you have the complete repository with all files"
    exit 1
fi

# Create systemd service file
echo -e "${BLUE}⚙️  Installing systemd service...${NC}"
cat > /tmp/file-service.service << EOF
[Unit]
Description=Personal File Upload Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$HOME/services
ExecStart=$HOME/services/file_service_env/bin/python file_service.py
Restart=always
RestartSec=15
Environment=PATH=$HOME/services/file_service_env/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

sudo cp /tmp/file-service.service /etc/systemd/system/
rm /tmp/file-service.service

# Create uploads directory
echo -e "${BLUE}📁 Creating uploads directory...${NC}"
mkdir -p /mnt/storage/uploads
sudo chown $USER:$USER /mnt/storage/uploads

# Enable and start service
echo -e "${BLUE}🔧 Enabling and starting service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable file-service
sudo systemctl start file-service

# Wait a moment for service to start
sleep 3

# Check service status
if sudo systemctl is-active --quiet file-service; then
    echo -e "${GREEN}✅ File service is running!${NC}"
else
    echo -e "${RED}❌ Service failed to start. Check logs:${NC}"
    echo "sudo journalctl -u file-service -n 20"
    exit 1
fi

# Get Pi IP address
PI_IP=$(hostname -I | awk '{print $1}')

# Install cloudflared if not present
if ! command -v cloudflared &> /dev/null; then
    echo -e "${BLUE}☁️  Installing Cloudflare Tunnel...${NC}"
    
    # Detect architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" ]]; then
        CLOUDFLARED_ARCH="arm64"
    elif [[ "$ARCH" == "armv7l" ]]; then
        CLOUDFLARED_ARCH="arm"
    else
        CLOUDFLARED_ARCH="amd64"
    fi
    
    curl -L --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CLOUDFLARED_ARCH}.deb"
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
    
    echo -e "${GREEN}✅ Cloudflared installed${NC}"
else
    echo -e "${GREEN}✅ Cloudflared already installed${NC}"
fi

# Final status check
echo ""
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
sudo systemctl status file-service --no-pager -l

echo ""
echo -e "${BLUE}🌐 Access Information:${NC}"
echo "  Local URL: http://$PI_IP:5001"
echo "  Upload Directory: /mnt/storage/uploads"
echo ""

# Check storage space
STORAGE_INFO=$(df -h /mnt/storage | tail -1)
echo -e "${BLUE}💾 Storage Info:${NC}"
echo "  $STORAGE_INFO"
echo ""

echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "1. Configure your Cloudflare tunnel:"
echo "   ./configure-tunnel.sh YOUR_TUNNEL_ID files.salamander.blue"
echo ""
echo "2. Or manually add to Cloudflare dashboard:"
echo "   - Subdomain: files"
echo "   - Domain: salamander.blue" 
echo "   - Service: http://localhost:5001"
echo ""

echo -e "${BLUE}📝 Useful Commands:${NC}"
echo "  Check service: sudo systemctl status file-service"
echo "  View logs: sudo journalctl -u file-service -f"
echo "  Restart: sudo systemctl restart file-service"
echo "  Storage usage: df -h /mnt/storage"
echo ""

echo -e "${GREEN}✨ Your Pi file server is ready!${NC}"
