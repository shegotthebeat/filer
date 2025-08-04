#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                 Pi 5 File Server Quick Start                 ║"
echo "║                     One-Click Recovery                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}This script will:${NC}"
echo "  ✅ Install file service with minimalist interface"
echo "  ✅ Set up auto-boot systemd service"
echo "  ✅ Configure external SSD storage"
echo "  ✅ Install Cloudflare Tunnel (optional)"
echo "  ✅ Set up domain routing (with your input)"
echo ""

# Check if we're in the right directory
if [ ! -f "setup.sh" ] || [ ! -f "configure-tunnel.sh" ]; then
    echo -e "${RED}❌ Error: Run this from the pi-file-server directory${NC}"
    echo ""
    echo "Try:"
    echo "  git clone https://github.com/yourusername/pi-file-server.git"
    echo "  cd pi-file-server"
    echo "  ./quick-start.sh"
    exit 1
fi

# Pre-flight checks
echo -e "${BLUE}🔍 Running pre-flight checks...${NC}"

# Check if SSD is available
if ! lsblk | grep -E "sd[a-z]" | grep -q "disk"; then
    echo -e "${RED}❌ No external drive detected${NC}"
    echo "Please connect your SSD and try again"
    exit 1
fi

# Check if SSD is already mounted
if mount | grep -q "/mnt/storage"; then
    echo -e "${GREEN}✅ SSD already mounted at /mnt/storage${NC}"
    SSD_MOUNTED=true
else
    echo -e "${YELLOW}⚠️  SSD not mounted${NC}"
    SSD_MOUNTED=false
fi

# Ask user for confirmation
echo ""
echo -e "${BOLD}Ready to proceed?${NC}"
echo "This will:"
echo "  • Install packages and dependencies"
echo "  • Create file service on port 5001"
if [ "$SSD_MOUNTED" = false ]; then
    echo "  • Format and mount your external SSD (⚠️  THIS WILL ERASE ALL DATA)"
fi
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted by user"
    exit 1
fi

# Handle SSD setup if needed
if [ "$SSD_MOUNTED" = false ]; then
    echo ""
    echo -e "${BLUE}💾 Setting up SSD storage...${NC}"
    
    # List available drives
    echo "Available drives:"
    lsblk | grep -E "sd[a-z].*disk"
    echo ""
    
    read -p "Enter drive to format (e.g., sda): " DRIVE
    
    if [ ! -b "/dev/$DRIVE" ]; then
        echo -e "${RED}❌ Drive /dev/$DRIVE not found${NC}"
        exit 1
    fi
    
    echo -e "${RED}⚠️  WARNING: This will ERASE ALL DATA on /dev/$DRIVE${NC}"
    read -p "Are you absolutely sure? Type 'yes' to continue: " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted by user"
        exit 1
    fi
    
    echo -e "${BLUE}🔧 Formatting /dev/$DRIVE...${NC}"
    
    # Create partition
    sudo fdisk /dev/$DRIVE << EOF
g
n
1


w
EOF
    
    # Format as ext4
    sudo mkfs.ext4 -L "PiStorage" /dev/${DRIVE}1
    
    # Mount
    sudo mkdir -p /mnt/storage
    sudo mount /dev/${DRIVE}1 /mnt/storage
    
    # Add to fstab
    UUID=$(sudo blkid -s UUID -o value /dev/${DRIVE}1)
    echo "UUID=$UUID /mnt/storage ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
    
    # Set permissions
    sudo chown $USER:$USER /mnt/storage
    
    echo -e "${GREEN}✅ SSD formatted and mounted${NC}"
fi

# Run main setup
echo ""
echo -e "${BLUE}🚀 Running main setup...${NC}"
./setup.sh

# Check if setup was successful
if ! sudo systemctl is-active --quiet file-service; then
    echo -e "${RED}❌ Setup failed - service not running${NC}"
    exit 1
fi

echo -e "${GREEN}✅ File service is running!${NC}"

# Get local IP
PI_IP=$(hostname -I | awk '{print $1}')
echo "Local access: http://$PI_IP:5001"

# Ask about Cloudflare Tunnel
echo ""
echo -e "${BLUE}☁️  Cloudflare Tunnel Setup${NC}"
echo "Do you want to set up Cloudflare Tunnel for remote access?"
echo "(You'll need a Cloudflare account and existing tunnel)"
echo ""
read -p "Set up Cloudflare Tunnel? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}🔧 Cloudflare Tunnel Configuration${NC}"
    
    # Check if already logged in
    if ! cloudflared tunnel list &> /dev/null; then
        echo "You need to login to Cloudflare first"
        read -p "Login now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cloudflared tunnel login
        else
            echo "Skipping tunnel setup - you can run ./configure-tunnel.sh later"
            echo ""
            echo -e "${GREEN}🎉 Setup Complete!${NC}"
            echo "Access your file server at: http://$PI_IP:5001"
            exit 0
        fi
    fi
    
    # List tunnels
    echo ""
    echo -e "${BLUE}Available tunnels:${NC}"
    cloudflared tunnel list || {
        echo "No tunnels found. Create one first:"
        echo "  cloudflared tunnel create my-tunnel"
        exit 0
    }
    
    echo ""
    read -p "Enter tunnel ID or name: " TUNNEL_ID
    
    if [ -z "$TUNNEL_ID" ]; then
        echo "No tunnel ID provided, skipping tunnel setup"
    else
        echo ""
        read -p "Enter your domain (e.g., salamander.blue): " BASE_DOMAIN
        
        if [ -z "$BASE_DOMAIN" ]; then
            SUBDOMAIN="files.example.com"
            echo "Using example domain: $SUBDOMAIN"
        else
            SUBDOMAIN="files.$BASE_DOMAIN"
        fi
        
        echo ""
        echo -e "${BLUE}Configuring tunnel for $SUBDOMAIN...${NC}"
        ./configure-tunnel.sh "$TUNNEL_ID" "$SUBDOMAIN"
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}🎉 Complete Setup Successful!${NC}"
            echo ""
            echo -e "${BLUE}📋 Access URLs:${NC}"
            echo "  Local:  http://$PI_IP:5001"
            echo "  Remote: https://$SUBDOMAIN"
            echo ""
            echo -e "${BLUE}💡 Note:${NC} It may take 1-2 minutes for DNS to propagate"
        else
            echo -e "${YELLOW}⚠️  Tunnel setup had issues, but local service is working${NC}"
            echo "You can run ./configure-tunnel.sh manually later"
        fi
    fi
else
    echo ""
    echo -e "${GREEN}🎉 Local Setup Complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Access Information:${NC}"
    echo "  Local URL: http://$PI_IP:5001"
    echo "  Upload Directory: /mnt/storage/uploads"
    echo ""
    echo -e "${BLUE}💡 To add remote access later:${NC}"
    echo "  ./configure-tunnel.sh YOUR_TUNNEL_ID your-domain.com"
fi

# Show final status
echo ""
echo -e "${BLUE}📊 Final Status:${NC}"
echo "  File Service: $(sudo systemctl is-active file-service)"
if systemctl list-unit-files | grep -q cloudflared.service; then
    echo "  Cloudflare:   $(sudo systemctl is-active cloudflared)"
fi
echo "  Storage:      $(df -h /mnt/storage | tail -1 | awk '{print $4}') free"

echo ""
echo -e "${BLUE}📝 Useful Commands:${NC}"
echo "  Check status: sudo systemctl status file-service"
echo "  View logs:    sudo journalctl -u file-service -f"
echo "  Storage info: df -h /mnt/storage"

echo ""
echo -e "${GREEN}${BOLD}✨ Your Pi file server is ready to use! ✨${NC}"
echo ""
