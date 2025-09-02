#!/bin/bash

# Script untuk memperbaiki masalah login PostgreSQL
# Mengatasi masalah authentication postgres user

set -e

echo "🔧 Fixing PostgreSQL login issues..."

# Check if PostgreSQL is running
if ! sudo systemctl is-active --quiet postgresql; then
    echo "🚀 Starting PostgreSQL service..."
    sudo systemctl start postgresql
    sleep 3
fi

# Backup current pg_hba.conf
echo "💾 Backing up current pg_hba.conf..."
sudo cp /etc/postgresql/16/main/pg_hba.conf /etc/postgresql/16/main/pg_hba.conf.backup.$(date +%s) 2>/dev/null || true

# Reset pg_hba.conf to allow peer authentication for postgres user
echo "🔧 Resetting authentication configuration..."
sudo tee /etc/postgresql/16/main/pg_hba.conf > /dev/null << 'EOF'
# PostgreSQL Client Authentication Configuration File
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                peer
local   all             all                                     peer

# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5

# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
EOF

# Restart PostgreSQL
echo "🔄 Restarting PostgreSQL..."
sudo systemctl restart postgresql
sleep 3

# Test connection as postgres user
echo "🔍 Testing postgres user connection..."
if sudo -u postgres psql -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Postgres user connection successful with peer authentication"
    
    # Now set password and enable md5 authentication
    echo "🔐 Setting postgres password..."
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'PostgreSQL123!';"
    
    # Update pg_hba.conf to allow both peer and md5
    echo "🔧 Enabling password authentication..."
    sudo tee /etc/postgresql/16/main/pg_hba.conf > /dev/null << 'EOF'
# PostgreSQL Client Authentication Configuration File
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                peer
local   all             postgres                                md5
local   all             all                                     peer
local   all             all                                     md5

# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5

# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
EOF
    
    # Restart PostgreSQL again
    sudo systemctl restart postgresql
    sleep 3
    
    echo "✅ PostgreSQL login fix completed successfully!"
    echo ""
    echo "You can now connect using:"
    echo "  sudo -u postgres psql                    # Using peer authentication"
    echo "  psql -h localhost -U postgres -d postgres # Using password authentication"
    echo ""
    echo "Password: PostgreSQL123!"
    
else
    echo "❌ Failed to connect as postgres user"
    echo "Checking PostgreSQL status..."
    sudo systemctl status postgresql --no-pager -l
    
    echo ""
    echo "Checking PostgreSQL logs..."
    sudo tail -20 /var/log/postgresql/postgresql-16-main.log 2>/dev/null || echo "Log file not found"
    
    echo ""
    echo "Manual troubleshooting steps:"
    echo "1. Check if PostgreSQL is running: sudo systemctl status postgresql"
    echo "2. Check logs: sudo tail -f /var/log/postgresql/postgresql-16-main.log"
    echo "3. Try connecting: sudo -u postgres psql"
fi

# Show current authentication configuration
echo ""
echo "Current authentication configuration:"
echo "======================================"
sudo cat /etc/postgresql/16/main/pg_hba.conf | grep -v '^#' | grep -v '^$'
