#!/bin/bash

# Script untuk install PostgreSQL 16.2 spesifik
# Menggunakan versi yang tersedia di repository

set -e

echo "🔧 Installing PostgreSQL 16.2 specifically..."

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
echo "🔍 Available PostgreSQL 16 versions:"
apt-cache madison postgresql-16 | head -10

# Install PostgreSQL 16.2
echo "📦 Installing PostgreSQL 16.2..."

if sudo apt install -y postgresql-16=16.2-1ubuntu4 postgresql-client-16=16.2-1ubuntu4 postgresql-contrib-16=16.2-1ubuntu4; then
    echo "✅ Installed PostgreSQL 16.2 successfully"
else
    echo "❌ Failed to install specific version, trying without version constraint..."
    sudo apt install -y postgresql-16 postgresql-client-16 postgresql-contrib-16
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
INSTALLED_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | head -1)
echo "Installed version: $INSTALLED_VERSION"

# Set password
echo "🔐 Setting PostgreSQL password..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'PostgreSQL123!';"

# Create backup directory
echo "📁 Creating backup directory..."
sudo mkdir -p /var/backups/postgresql
sudo chown postgres:postgres /var/backups/postgresql
sudo chmod 755 /var/backups/postgresql

# Configure PostgreSQL for localhost only
echo "🔧 Configuring PostgreSQL..."
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /etc/postgresql/16/main/postgresql.conf 2>/dev/null || true

# Configure authentication
sudo sed -i "s/local   all             postgres                                peer/local   all             postgres                                md5/" /etc/postgresql/16/main/pg_hba.conf 2>/dev/null || true

# Restart PostgreSQL to apply configuration
echo "🔄 Restarting PostgreSQL to apply configuration..."
sudo systemctl restart postgresql

echo ""
echo "✅ PostgreSQL 16.2 installation completed successfully!"
echo ""
echo "Connection details:"
echo "  Username: postgres"
echo "  Password: PostgreSQL123!"
echo "  Database: postgres"
echo "  Host: localhost"
echo ""
echo "Installed version:"
sudo -u postgres psql -t -c "SELECT version();" | head -1
echo ""
echo "To connect:"
echo "  sudo -u postgres psql"
echo ""
echo "To restore your backup:"
echo "  ./restore_external_backup.sh -f -s -o -r your_backup_file.sql"
echo ""
echo "Note: PostgreSQL 16.2 should be compatible with your 16.4 backup file."
echo "The restore script will handle any minor version differences."
