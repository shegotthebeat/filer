#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -eq 0 ]; then
    echo -e "${BLUE}☁️  Cloudflare Tunnel Configuration${NC}"
    echo ""
    echo "Usage: $0 <tunnel-id> [subdomain]"
    echo ""
    echo "Examples:"
    echo "  $0 dc1f834e-1234-5678-9abc-123456789012 files.salamander.blue"
    echo "  $0 my-tunnel-name files.mydomain.com"
    echo ""
    echo -e "${BLUE}📋 To find your tunnel ID:${NC}"
    echo "  cloudflared tunnel list"
    echo ""
    exit 1
fi

TUNNEL_ID=$1
SUBDOMAIN=${2:-"files.salamander.blue"}

echo -e "${BLUE}☁️  Configuring Cloudflare Tunnel...${NC}"
echo "Tunnel ID: $TUNNEL_ID"
echo "Subdomain: $SUBDOMAIN"
echo ""

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo -e "${RED}❌ Error: cloudflared not found${NC}"
    echo "Please install cloudflared first or run setup.sh"
    exit 1
fi

# Check if user is logged in to Cloudflare
if ! cloudflared tunnel list &> /dev/null; then
    echo -e "${YELLOW}⚠️  You need to login to Cloudflare first${NC}"
    echo "Running: cloudflared tunnel login"
    cloudflared tunnel login
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to login to Cloudflare${NC}"
        exit 1
    fi
fi

# Verify tunnel exists
echo -e "${BLUE}🔍 Verifying tunnel exists...${NC}"
if ! cloudflared tunnel list | grep -q "$TUNNEL_ID"; then
    echo -e "${RED}❌ Tunnel '$TUNNEL_ID' not found${NC}"
    echo ""
    echo -e "${BLUE}Available tunnels:${NC}"
    cloudflared tunnel list
    exit 1
fi

echo -e "${GREEN}✅ Tunnel found${NC}"

# Add DNS route for subdomain
echo -e "${BLUE}🌐 Adding DNS route for $SUBDOMAIN...${NC}"
if cloudflared tunnel route dns "$TUNNEL_ID" "$SUBDOMAIN" 2>/dev/null; then
    echo -e "${GREEN}✅ DNS route added successfully${NC}"
elif cloudflared tunnel route dns "$TUNNEL_ID" "$SUBDOMAIN" 2>&1 | grep -q "already configured"; then
    echo -e "${YELLOW}⚠️  DNS route already exists${NC}"
else
    echo -e "${RED}❌ Failed to add DNS route${NC}"
    echo "You may need to add it manually in the Cloudflare dashboard"
fi

# Check if config directory exists
mkdir -p ~/.cloudflared

# Create or update config file
CONFIG_FILE="$HOME/.cloudflared/config.yml"
echo -e "${BLUE}⚙️  Updating tunnel configuration...${NC}"

# Extract domain from subdomain
DOMAIN=$(echo "$SUBDOMAIN" | sed 's/^[^.]*\.//')

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠️  Config file exists, backing up...${NC}"
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%s)"
fi

# Create config file
cat > "$CONFIG_FILE" << EOF
tunnel: $TUNNEL_ID
credentials-file: ~/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: $SUBDOMAIN
    service: http://localhost:5001
  - hostname: $DOMAIN
    service: http://localhost:5000
  - service: http_status:404
EOF

echo -e "${GREEN}✅ Config file created/updated${NC}"

# Download credentials if they don't exist
CREDS_FILE="$HOME/.cloudflared/${TUNNEL_ID}.json"
if [ ! -f "$CREDS_FILE" ]; then
    echo -e "${BLUE}🔑 Downloading tunnel credentials...${NC}"
    if cloudflared tunnel token --cred-file "$CREDS_FILE" "$TUNNEL_ID"; then
        echo -e "${GREEN}✅ Credentials downloaded${NC}"
    else
        echo -e "${RED}❌ Failed to download credentials${NC}"
        echo "You may need to download them manually"
    fi
else
    echo -e "${GREEN}✅ Credentials already exist${NC}"
fi

# Check if cloudflared service exists
if systemctl list-unit-files | grep -q cloudflared.service; then
    echo -e "${BLUE}🔧 Restarting cloudflared service...${NC}"
    sudo systemctl restart cloudflared
    
    # Wait for service to start
    sleep 3
    
    if sudo systemctl is-active --quiet cloudflared; then
        echo -e "${GREEN}✅ Cloudflared service restarted${NC}"
    else
        echo -e "${RED}❌ Cloudflared service failed to start${NC}"
        echo "Check logs: sudo journalctl -u cloudflared -f"
    fi
else
    echo -e "${YELLOW}⚠️  Cloudflared service not found${NC}"
    echo "You can start the tunnel manually:"
    echo "  cloudflared tunnel run"
    echo ""
    echo "Or create a service:"
    echo "  sudo cloudflared service install"
fi

# Test the configuration
echo -e "${BLUE}🧪 Testing configuration...${NC}"
if cloudflared tunnel ingress validate 2>/dev/null; then
    echo -e "${GREEN}✅ Configuration is valid${NC}"
else
    echo -e "${YELLOW}⚠️  Configuration validation failed${NC}"
    echo "The tunnel should still work, but check your config file"
fi

echo ""
echo -e "${GREEN}🎉 Tunnel Configuration Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "  Tunnel ID: $TUNNEL_ID"
echo "  File Service: https://$SUBDOMAIN"
echo "  Main Domain: https://$DOMAIN"
echo "  Config File: $CONFIG_FILE"
echo ""

echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "1. Wait 1-2 minutes for DNS propagation"
echo "2. Test your file service: https://$SUBDOMAIN"
echo "3. If it doesn't work, check the Cloudflare dashboard:"
echo "   Zero Trust > Networks > Tunnels > Configure"
echo ""

echo -e "${BLUE}📝 Manual Dashboard Setup (if needed):${NC}"
echo "  Subdomain: ${SUBDOMAIN%%.*}"
echo "  Domain: $DOMAIN"
echo "  Service Type: HTTP"
echo "  URL: localhost:5001"
echo ""

echo -e "${BLUE}🚨 Troubleshooting:${NC}"
echo "  Check tunnel status: sudo systemctl status cloudflared"
echo "  View tunnel logs: sudo journalctl -u cloudflared -f"
echo "  Test manual tunnel: cloudflared tunnel run"
echo "  Validate config: cloudflared tunnel ingress validate"
echo ""

echo -e "${GREEN}✨ Your tunnel should be live shortly!${NC}"
