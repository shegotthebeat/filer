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
