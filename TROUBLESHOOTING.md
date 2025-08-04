# Troubleshooting Guide

## 🚨 Common Issues and Solutions

### File Service Won't Start

#### Check Service Status
```bash
sudo systemctl status file-service
```

#### View Detailed Logs
```bash
sudo journalctl -u file-service -f
```

#### Common Causes & Fixes

**1. Virtual Environment Issues**
```bash
# Check if virtual environment exists
ls -la ~/services/file_service_env/

# Recreate if missing or corrupted
cd ~/services
rm -rf file_service_env
python3 -m venv file_service_env
source file_service_env/bin/activate
pip install Flask requests Werkzeug
deactivate

# Restart service
sudo systemctl restart file-service
```

**2. Permission Issues**
```bash
# Fix ownership
sudo chown -R $USER:$USER ~/services
sudo chown -R $USER:$USER /mnt/storage

# Fix service file permissions
sudo systemctl daemon-reload
sudo systemctl restart file-service
```

**3. Port Already in Use**
```bash
# Check what's using port 5001
sudo netstat -tlnp | grep :5001

# Kill the process if needed
sudo kill $(sudo lsof -t -i:5001)

# Restart service
sudo systemctl restart file-service
```

---

### SSD Storage Issues

#### SSD Not Mounted
```bash
# Check current mounts
df -h | grep storage
mount | grep storage

# Check if SSD is detected
lsblk

# Manual mount
sudo mount -a

# Check fstab entry
grep storage /etc/fstab
```

#### Fix Auto-Mount
```bash
# Get UUID of your SSD
sudo blkid /dev/sda1

# Add to fstab (replace YOUR_UUID)
echo "UUID=YOUR_UUID /mnt/storage ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Test mount
sudo mount -a
```

#### Permission Issues
```bash
# Fix ownership
sudo chown -R $USER:$USER /mnt/storage

# Create uploads directory
mkdir -p /mnt/storage/uploads
```

---

### Cloudflare Tunnel Issues

#### Tunnel Not Working
```bash
# Check tunnel status
sudo systemctl status cloudflared

# View tunnel logs
sudo journalctl -u cloudflared -f

# List available tunnels
cloudflared tunnel list

# Test manual tunnel
cloudflared tunnel run
```

#### DNS Not Resolving
```bash
# Test DNS resolution
nslookup files.salamander.blue
dig files.salamander.blue

# Check DNS routes
cloudflared tunnel route ip show TUNNEL_ID
```

#### Fix Tunnel Configuration
```bash
# Validate config
cloudflared tunnel ingress validate

# Recreate config
./configure-tunnel.sh YOUR_TUNNEL_ID files.salamander.blue

# Restart tunnel
sudo systemctl restart cloudflared
```

---

### Upload Issues

#### Files Not Uploading
1. **Check browser console** for JavaScript errors
2. **Try mobile form** if drag & drop fails
3. **Check file permissions** on upload directory
4. **Test with small files** first

```bash
# Check upload directory
ls -la /mnt/storage/uploads/

# Check disk space
df -h /mnt/storage

# Check service logs during upload
sudo journalctl -u file-service -f
```

#### Large File Upload Fails
```bash
# Check available disk space
df -h /mnt/storage

# Check system memory 
free -h

# Monitor during upload
htop
```

---

### Network Issues

#### Can't Access Locally
```bash
# Check if service is running
curl http://localhost:5001

# Check firewall
sudo ufw status

# Get Pi IP address
hostname -I

# Test from another device on network
curl http://PI_IP:5001
```

#### Slow Upload/Download
1. **Check Wi-Fi signal strength**
2. **Test wired connection** if possible
3. **Check SSD health**
4. **Monitor system resources** with `htop`

---

## 🔧 Diagnostic Commands

### System Health Check
```bash
# Service status
sudo systemctl status file-service cloudflared

# Storage info
df -h /mnt/storage
lsblk

# Network info
hostname -I
curl -I http://localhost:5001

# System resources
htop
free -h
```

### Log Analysis
```bash
# Service logs (last 50 lines)
sudo journalctl -u file-service -n 50

# Tunnel logs (last 50 lines)  
sudo journalctl -u cloudflared -n 50

# System logs for errors
sudo journalctl -p err -n 20

# Boot logs
sudo journalctl -b
```

### File System Check
```bash
# Check SSD health
sudo smartctl -a /dev/sda

# Check file system
sudo fsck /dev/sda1

# Check mount options
mount | grep storage
```

---

## 🚑 Emergency Recovery

### Complete Service Reset
```bash
# Stop services
sudo systemctl stop file-service cloudflared

# Backup important files
cp -r /mnt/storage/uploads ~/backup-uploads

# Remove and reinstall
sudo systemctl disable file-service
sudo rm /etc/systemd/system/file-service.service
rm -rf ~/services

# Re-run setup
./setup.sh
```

### SSD Recovery
```bash
# Check file system
sudo fsck -f /dev/sda1

# Remount
sudo umount /mnt/storage
sudo mount /dev/sda1 /mnt/storage

# Check files
ls -la /mnt/storage/uploads/
```

---

## 📞 Getting Help

### Collect Debug Info
```bash
# Create debug report
{
    echo "=== SYSTEM INFO ==="
    uname -a
    cat /etc/os-release
    
    echo -e "\n=== SERVICES ==="
    sudo systemctl status file-service cloudflared --no-pager
    
    echo -e "\n=== STORAGE ==="
    df -h
    lsblk
    mount | grep storage
    
    echo -e "\n=== NETWORK ==="
    hostname -I
    curl -I http://localhost:5001 2>&1 || echo "Service not responding"
    
    echo -e "\n=== RECENT LOGS ==="
    sudo journalctl -u file-service -n 10 --no-pager
    sudo journalctl -u cloudflared -n 10 --no-pager
    
} > debug-report.txt

echo "Debug report saved to debug-report.txt"
```

### Before Asking for Help
1. **Run the debug report** above
2. **Try the solutions** in this guide
3. **Include the debug report** in your issue
4. **Describe what you were doing** when the problem occurred
5. **Include any error messages** you see

---

## 🔄 Regular Maintenance

### Weekly Checks
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Check disk space
df -h /mnt/storage

# Check service status
sudo systemctl status file-service cloudflared

# Check for large files
du -sh /mnt/storage/uploads/*
```

### Monthly Tasks
```bash
# Clean up old uploads if needed
find /mnt/storage/uploads -type f -mtime +30 -ls

# Check SSD health
sudo smartctl -a /dev/sda

# Update Python packages
cd ~/services
source file_service_env/bin/activate
pip list --outdated
deactivate
```

---

**💡 Tip: Keep this troubleshooting guide handy and run through the diagnostic commands whenever you encounter issues!**
