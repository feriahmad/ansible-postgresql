#!/bin/bash

# Script untuk install PostgreSQL 16.4 spesifik
# Untuk kompatibilitas dengan backup dari server lain

set -e

echo "🔧 Installing PostgreSQL 16.4 specifically..."

# Update system
echo "📦 Updating system packages..."
sudo apt update

# Install dependencies
echo "📦 Installing dependencies..."
sudo apt install -y wget ca-certificates gnupg lsb-release

# Add PostgreSQL official repository
echo "🔑 Adding PostgreSQL official repository..."
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

# Update package list
sudo apt update

# Remove existing PostgreSQL if any
echo "🗑️  Removing existing PostgreSQL installations..."
sudo systemctl stop postgresql 2>/dev/null || true
sudo apt remove --purge -y postgresql* 2>/dev/null || true
sudo rm -rf /var/lib/postgresql 2>/dev/null || true
sudo rm -rf /etc/postgresql 2>/dev/null || true

# Check available versions
echo "🔍 Checking available PostgreSQL 16 versions..."
apt-cache madison postgresql-16 | head -10

# Try different package naming conventions for 16.4
echo "📦 Attempting to install PostgreSQL 16.4..."

# Method 1: Try with Ubuntu 24.04 naming
if sudo apt install -y postgresql-16=16.4-1.pgdg24.04+1 postgresql-client-16=16.4-1.pgdg24.04+1 postgresql-contrib-16=16.4-1.pgdg24.04+1 2>/dev/null; then
    echo "✅ Installed with pgdg24.04+1 naming"
# Method 2: Try with Ubuntu 22.04 naming (sometimes works)
elif sudo apt install -y postgresql-16=16.4-1.pgdg22.04+1 postgresql-client-16=16.4-1.pgdg22.04+1 postgresql-contrib-16=16.4-1.pgdg22.04+1 2>/dev/null; then
    echo "✅ Installed with pgdg22.04+1 naming"
# Method 3: Try with Ubuntu 20.04 naming
elif sudo apt install -y postgresql-16=16.4-1.pgdg20.04+1 postgresql-client-16=16.4-1.pgdg20.04+1 postgresql-contrib-16=16.4-1.pgdg20.04+1 2>/dev/null; then
    echo "✅ Installed with pgdg20.04+1 naming"
# Method 4: Try without Ubuntu version
elif sudo apt install -y postgresql-16=16.4-1 postgresql-client-16=16.4-1 postgresql-contrib-16=16.4-1 2>/dev/null; then
    echo "✅ Installed with generic naming"
# Method 5: Download and install manually
else
    echo "⚠️  Standard package installation failed, trying manual download..."
    
    # Create temp directory
    TEMP_DIR="/tmp/postgresql_16.4_install"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Determine architecture
    ARCH=$(dpkg --print-architecture)
    
    # Download packages manually
    echo "📥 Downloading PostgreSQL 16.4 packages..."
    
    # Try to download from different sources
    BASE_URL="http://apt.postgresql.org/pub/repos/apt/pool/main/p"
    
    # Download main packages
    wget "${BASE_URL}/postgresql-16/postgresql-16_16.4-1.pgdg24.04+1_${ARCH}.deb" || \
    wget "${BASE_URL}/postgresql-16/postgresql-16_16.4-1.pgdg22.04+1_${ARCH}.deb" || \
    wget "${BASE_URL}/postgresql-16/postgresql-16_16.4-1.pgdg20.04+1_${ARCH}.deb" || {
        echo "❌ Failed to download PostgreSQL 16.4 packages"
        echo "Available versions:"
        apt-cache madison postgresql-16
        exit 1
    }
    
    # Download client packages
    wget "${BASE_URL}/postgresql-client-16/postgresql-client-16_16.4-1.pgdg24.04+1_${ARCH}.deb" || \
    wget "${BASE_URL}/postgresql-client-16/postgresql-client-16_16.4-1.pgdg22.04+1_${ARCH}.deb" || \
    wget "${BASE_URL}/postgresql-client-16/postgresql-client-16_16.4-1.pgdg20.04+1_${ARCH}.deb" || true
    
    # Download contrib packages
    wget "${BASE_URL}/postgresql-contrib-16/postgresql-contrib-16_16.4-1.pgdg24.04+1_${ARCH}.deb" || \
    wget "${BASE_URL}/postgresql-contrib-16/postgresql-contrib-16_16.4-1.pgdg22.04+1_${ARCH}.deb" || \
    wget "${BASE_URL}/postgresql-contrib-16/postgresql-contrib-16_16.4-1.pgdg20.04+1_${ARCH}.deb" || true
    
    # Install downloaded packages
    echo "📦 Installing downloaded packages..."
    sudo dpkg -i *.deb || sudo apt-get install -f -y
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
fi

# Hold packages to prevent automatic updates
echo "🔒 Holding PostgreSQL packages to prevent updates..."
sudo apt-mark hold postgresql-16 postgresql-client-16 postgresql-contrib-16

# Start and enable PostgreSQL
echo "🚀 Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check installation
echo "✅ Checking PostgreSQL installation..."
sudo -u postgres psql -c "SELECT version();" || {
    echo "❌ PostgreSQL installation verification failed"
    exit 1
}

# Set password
echo "🔐 Setting PostgreSQL password..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'PostgreSQL123!';"

# Create backup directory
echo "📁 Creating backup directory..."
sudo mkdir -p /var/backups/postgresql
sudo chown postgres:postgres /var/backups/postgresql
sudo chmod 755 /var/backups/postgresql

echo ""
echo "✅ PostgreSQL 16.4 installation completed successfully!"
echo ""
echo "Connection details:"
echo "  Username: postgres"
echo "  Password: PostgreSQL123!"
echo "  Database: postgres"
echo "  Host: localhost"
echo ""
echo "To connect:"
echo "  sudo -u postgres psql"
echo ""
echo "To restore your backup:"
echo "  ./restore_external_backup.sh -f -s -o -r your_backup_file.sql"
