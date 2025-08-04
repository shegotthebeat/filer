# home-filer
SSD file server setup for Raspberry Pi 5

- **External SSD storage** with power-loss protection  
- **Cloudflare Tunnel** integration for secure access
- **Minimalist file upload/download web interface**
- **Mobile-friendly** with drag & drop support
- **Auto-boot** services that start automatically

### 1. Prerequisites

- **Raspberry Pi 5** with fresh OS install
- **External SSD** already formatted as ext4 and mounted at `/mnt/storage`
- **Cloudflare account** with existing tunnel
- **SSH access** to your Pi

### 2. One-Command Setup

```bash
# Clone this repo
git clone https://github.com/shegotthebeat/home-filer.git
cd home-filer

# Run setup script
chmod +x setup.sh
./setup.sh
```

### 3. Configure Cloudflare Tunnel

```bash
# Replace with your actual values
./configure-tunnel.sh dc1f834e-YOUR-TUNNEL-ID sub.yourdomain.com
```

**Done!** Your file server should be live at `sub.yourdomain.com`

---

## 📁 Repository Structure

```
pi-file-server/
├── README.md                 # This file
├── setup.sh                  # Main setup script
├── configure-tunnel.sh       # Cloudflare tunnel configuration
├── services/
│   ├── file_service.py      # Main Python service
│   └── requirements.txt     # Python dependencies
├── config/
│   └── file-service.service # Systemd service file
└── docs/
    └── troubleshooting.md   # Common issues and fixes
```

