#!/bin/bash
set -e

echo "💾 SSD Mounting Setup"
echo "====================="

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

# Check if already mounted
if df -h | grep -q "/mnt/storage"; then
    print_status "SSD already mounted at /mnt/storage"
    df -h | grep storage
    exit 0
fi

print_status "Scanning for external drives..."
lsblk

echo ""
print_warning "⚠️  IMPORTANT: Make sure you identify the correct drive!"
print_warning "    Your SD card is usually mmcblk0 - DO NOT select this!"
print_warning "    Your SSD should be sda, sdb, etc. and around 1TB"
echo ""

# Show drives that look like external SSDs
print_status "Potential external drives found:"
lsblk | grep -E "sd[a-z]" | grep -v "loop" || echo "No external drives detected"

echo ""
read -p "Enter the drive identifier (e.g., sda): " drive_id

if [ -z "$drive_id" ]; then
    print_error "No drive specified"
    exit 1
fi

# Validate drive exists
if ! lsblk | grep -q "^$drive_id "; then
    print_error "Drive $drive_id not found"
    exit 1
fi

# Check if drive has partitions
if lsblk | grep -q "${drive_id}1"; then
    partition="${drive_id}1"
    print_status "Using partition /dev/$partition"
else
    print_error "No partition found on /dev/$drive_id"
    echo "The drive may need to be formatted first."
    exit 1
fi

# Get UUID
print_status "Getting UUID for /dev/$partition..."
uuid=$(sudo blkid /dev/$partition | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)

if [ -z "$uuid" ]; then
    print_error "Could not get UUID for /dev/$partition"
    print_error "The drive may not be formatted with a supported filesystem"
    exit 1
fi

print_status "Found UUID: $uuid"

# Create mount point
print_status "Creating mount point..."
sudo mkdir -p /mnt/storage

# Check if already in fstab
if grep -q "$uuid" /etc/fstab 2>/dev/null; then
    print_warning "Drive already configured in /etc/fstab"
else
    print_status "Adding to /etc/fstab for auto-mount..."
    sudo cp /etc/fstab /etc/fstab.backup
    echo "UUID=$uuid /mnt/storage ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab > /dev/null
fi

# Mount the drive
print_status "Mounting drive..."
sudo mount -a

# Verify mount
if df -h | grep -q "/mnt/storage"; then
    print_status "✅ SSD successfully mounted!"
    df -h | grep storage
    
    # Set permissions
    print_status "Setting permissions..."
    sudo chown $(whoami):$(whoami) /mnt/storage
    
    # Test write access
    if touch /mnt/storage/test_file 2>/dev/null; then
        rm /mnt/storage/test_file
        print_status "✅ Write access confirmed"
    else
        print_error "❌ Write access failed"
        exit 1
    fi
    
    # Create directory structure
    print_status "Creating directory structure..."
    mkdir -p /mnt/storage/uploads
    mkdir -p /mnt/storage/data
    mkdir -p /mnt/storage/media
    mkdir -p /mnt/storage/backups
    
    print_status "✅ SSD setup complete!"
    echo ""
    echo "Mount point: /mnt/storage"
    echo "Available space: $(df -h /mnt/storage | tail -1 | awk '{print $4}')"
    echo "File system: $(df -T /mnt/storage | tail -1 | awk '{print $2}')"
    
else
    print_error "❌ Failed to mount SSD"
    exit 1
fi
