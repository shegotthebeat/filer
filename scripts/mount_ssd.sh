#!/bin/bash
echo "🔧 Fixing SSD mount issue..."

# Find the SSD partition
SSD_PARTITION=$(lsblk | grep -E "sd[a-z]1" | head -1 | awk '{print $1}' | sed 's/├─//' | sed 's/└─//')

if [ -z "$SSD_PARTITION" ]; then
    echo "❌ No SSD partition found"
    exit 1
fi

echo "Found SSD partition: $SSD_PARTITION"

# Get the correct UUID
UUID=$(sudo blkid -s UUID -o value /dev/$SSD_PARTITION)

if [ -z "$UUID" ]; then
    echo "❌ Could not get UUID for /dev/$SSD_PARTITION"
    exit 1
fi

echo "Found UUID: $UUID"

# Backup current fstab
sudo cp /etc/fstab /etc/fstab.backup

# Remove any existing storage entries
sudo sed -i '/\/mnt\/storage/d' /etc/fstab

# Add correct entry
echo "UUID=$UUID /mnt/storage ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Create mount point
sudo mkdir -p /mnt/storage

# Reload and mount
sudo systemctl daemon-reload
sudo mount -a

# Check result
if df -h | grep -q "/mnt/storage"; then
    echo "✅ SSD mounted successfully!"
    df -h | grep storage
else
    echo "❌ Mount failed"
    exit 1
fi
