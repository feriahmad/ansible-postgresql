#!/bin/bash

# Script to forcefully reinstall PostgreSQL 16.2-1ubuntu4
# Addresses package hold issues and database initialization problems

set -e

echo "=== PostgreSQL 16.2-1ubuntu4 Complete Reinstallation Script ==="
echo "This script will:"
echo "1. Remove package holds"
echo "2. Completely remove PostgreSQL"
echo "3. Clean all data directories"
echo "4. Install specific PostgreSQL 16.2-1ubuntu4 version"
echo "5. Initialize database properly"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to stop PostgreSQL services
stop_postgresql() {
    log "Stopping PostgreSQL services..."
    systemctl stop postgresql || true
    systemctl stop postgresql@16-main || true
    systemctl stop postgresql.service || true
    
    # Kill any remaining postgres processes
    pkill -f postgres || true
    sleep 2
}

# Function to remove package holds
remove_holds() {
    log "Removing package holds..."
    
    # List current holds
    log "Current package holds:"
    apt-mark showhold | grep -i postgres || echo "No PostgreSQL holds found"
    
    # Remove holds on PostgreSQL packages
    apt-mark unhold postgresql* || true
    apt-mark unhold libpq* || true
    
    log "Package holds removed"
}

# Function to completely remove PostgreSQL
remove_postgresql() {
    log "Completely removing PostgreSQL..."
    
    # Stop services first
    stop_postgresql
    
    # Remove packages with --allow-change-held-packages
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y --allow-change-held-packages \
        postgresql* \
        libpq* \
        pgdg-keyring || true
    
    # Autoremove orphaned packages
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --allow-change-held-packages || true
    
    log "PostgreSQL packages removed"
}

# Function to clean data directories
clean_data_directories() {
    log "Cleaning PostgreSQL data directories..."
    
    # Remove data directories
    rm -rf /var/lib/postgresql/ || true
    rm -rf /etc/postgresql/ || true
    rm -rf /var/log/postgresql/ || true
    rm -rf /run/postgresql/ || true
    
    # Remove postgres user and group
    userdel postgres 2>/dev/null || true
    groupdel postgres 2>/dev/null || true
    
    log "Data directories cleaned"
}

# Function to update package lists
update_packages() {
    log "Updating package lists..."
    apt-get update
    log "Package lists updated"
}

# Function to install specific PostgreSQL version
install_postgresql_16_2() {
    log "Installing PostgreSQL 16.2-1ubuntu4..."
    
    # Install specific version
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        postgresql-16=16.2-1ubuntu4 \
        postgresql-client-16=16.2-1ubuntu4 \
        postgresql-contrib-16=16.2-1ubuntu4
    
    # Hold the packages to prevent automatic updates
    apt-mark hold postgresql-16 postgresql-client-16 postgresql-contrib-16
    
    log "PostgreSQL 16.2-1ubuntu4 installed and held"
}

# Function to initialize database cluster
initialize_database() {
    log "Initializing PostgreSQL database cluster..."
    
    # Ensure postgres user exists
    if ! id postgres &>/dev/null; then
        useradd -r -s /bin/bash -d /var/lib/postgresql postgres
    fi
    
    # Create necessary directories
    mkdir -p /var/lib/postgresql/16/main
    mkdir -p /var/log/postgresql
    mkdir -p /run/postgresql
    
    # Set proper ownership
    chown -R postgres:postgres /var/lib/postgresql
    chown -R postgres:postgres /var/log/postgresql
    chown -R postgres:postgres /run/postgresql
    
    # Initialize the database cluster
    sudo -u postgres /usr/lib/postgresql/16/bin/initdb \
        --pgdata=/var/lib/postgresql/16/main \
        --auth-local=peer \
        --auth-host=md5 \
        --encoding=UTF8 \
        --locale=en_US.UTF-8
    
    log "Database cluster initialized"
}

# Function to configure PostgreSQL
configure_postgresql() {
    log "Configuring PostgreSQL..."
    
    # Start PostgreSQL service
    systemctl start postgresql
    systemctl enable postgresql
    
    # Wait for service to be ready
    sleep 5
    
    # Set postgres user password
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres123';"
    
    # Update pg_hba.conf for md5 authentication
    PG_HBA="/etc/postgresql/16/main/pg_hba.conf"
    if [[ -f "$PG_HBA" ]]; then
        # Backup original
        cp "$PG_HBA" "$PG_HBA.backup"
        
        # Update authentication method
        sed -i 's/local   all             postgres                                peer/local   all             postgres                                md5/' "$PG_HBA"
        sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' "$PG_HBA"
        
        # Reload configuration
        systemctl reload postgresql
    fi
    
    log "PostgreSQL configured"
}

# Function to verify installation
verify_installation() {
    log "Verifying PostgreSQL installation..."
    
    # Check service status
    systemctl status postgresql --no-pager
    
    # Check version
    sudo -u postgres psql -c "SELECT version();"
    
    # Check if we can connect with password
    PGPASSWORD=postgres123 psql -U postgres -h localhost -c "SELECT 'Connection successful';"
    
    log "PostgreSQL installation verified successfully"
}

# Main execution
main() {
    log "Starting PostgreSQL 16.2-1ubuntu4 reinstallation..."
    
    check_root
    stop_postgresql
    remove_holds
    remove_postgresql
    clean_data_directories
    update_packages
    install_postgresql_16_2
    initialize_database
    configure_postgresql
    verify_installation
    
    log "PostgreSQL 16.2-1ubuntu4 reinstallation completed successfully!"
    echo ""
    echo "=== Installation Summary ==="
    echo "Version: PostgreSQL 16.2-1ubuntu4"
    echo "User: postgres"
    echo "Password: postgres123"
    echo "Authentication: md5"
    echo "Status: $(systemctl is-active postgresql)"
    echo ""
    echo "You can now connect using:"
    echo "  psql -U postgres -h localhost"
    echo "  Password: postgres123"
}

# Run main function
main "$@"
