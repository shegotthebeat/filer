# home-filer
SSD file server setup for Raspberry Pi 5

- **1TB SSD storage** at `/mnt/storage` with auto-mount
- **Auto-boot ready** - everything starts automatically

## 📂 ** File Structure**

```
home-filer/
├── README.md                    # This documentation
├── setup.sh                    # Complete system setup
├── install_service.sh          # File service installation  
├── start_services.sh           # Start all services
├── config/
│   ├── cloudflare.yml          # Cloudflare tunnel template
│   └── file-service.service    # Systemd service template
├── src/
│   ├── file_service.py         # Main application (minimalist UI)
│   └── requirements.txt        # Python dependencies
└── scripts/
    ├── mount_ssd.sh            # SSD mounting helper
    └── health_check.sh         # System health checker
```

## 🔄 **From Zero to Running (Complete Restore)**

```bash
# 1. Fresh Pi 5 with Raspberry Pi OS
# 2. Connect your pre-formatted ext4 SSD
# 3. Clone your repository:

git clone https://github.com/yourusername/home-filer.git
cd pi-file-server

# 4. Make scripts executable
chmod +x *.sh scripts/*.sh

# 5. Run complete setup
./setup.sh

# 6. Configure your specific details
nano ~/.cloudflared/config.yml
# Update: tunnel ID, domain name, credentials file

# 7. Add DNS route  
cloudflared tunnel route dns YOUR_TUNNEL_ID files.yourdomain.com

# 8. Start everything
./start_services.sh

# 9. Verify
./scripts/health_check.sh
```

**Result**: Working file server accessible at `files.yourdomain.com`

---

## 📋 **Prerequisites**

✅ **Raspberry Pi 5** with fresh Raspberry Pi OS  
✅ **External SSD** already formatted as ext4  
✅ **Cloudflare account** with domain  
✅ **Cloudflare tunnel** already created  

---

## 🚀 **Quick Setup**

```bash
# 1. Clone this repo
git clone <your-repo-url>
cd pi-file-server

# 2. Run complete setup
chmod +x setup.sh
./setup.sh

# 3. Configure your domain and tunnel ID in config
nano config/cloudflare.yml

# 4. Start services
./start_services.sh
```

---

## 📂 **Repository Structure**

```
pi-file-server/
├── README.md
├── setup.sh                 # Complete setup script
├── install_service.sh       # Install file service
├── start_services.sh        # Start all services
├── config/
│   ├── cloudflare.yml      # Cloudflare tunnel config template
│   └── file-service.service # Systemd service template
├── src/
│   ├── file_service.py     # Main file service application
│   └── requirements.txt    # Python dependencies
└── scripts/
    ├── mount_ssd.sh        # SSD mounting script
    └── health_check.sh     # Service health checker
```



## ✅ **Success Checklist**

After setup, verify:

- ✅ **SSD mounted**: `df -h | grep storage` shows ~930GB
- ✅ **File service**: `curl http://localhost:5001` returns HTML
- ✅ **Tunnel active**: `sudo systemctl status cloudflared` shows active
- ✅ **Domain works**: `https://files.yourdomain.com` loads interface
- ✅ **Auto-start**: Reboot Pi, all services return automatically
- ✅ **File upload**: Can upload files via web interface
- ✅ **File storage**: Files appear in `/mnt/storage/uploads/`

---

## 📞 **Support**

**Log locations:**
- File service: `sudo journalctl -u file-service`
- Cloudflare: `sudo journalctl -u cloudflared`  
- System: `sudo journalctl -b`

**Key files:**
- File service: `~/services/file_service.py`
- Tunnel config: `~/.cloudflared/config.yml`
- Service config: `/etc/systemd/system/file-service.service`
- Mount config: `/etc/fstab`

**Service ports:**
- 5000: Main Flask app
- 5001: File service  
- 8080: Cloudflare metrics (local only)
