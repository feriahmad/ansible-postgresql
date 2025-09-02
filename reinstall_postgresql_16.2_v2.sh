#!/bin/bash

# Script to forcefully reinstall PostgreSQL 16.2-1ubuntu4
# Version 2 - Enhanced error handling and logging

# Remove set -e to prevent script termination on errors
# set -e

echo "=== PostgreSQL 16.2-1ubuntu4 Complete Reinstallation Script v2 ==="
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

# Function to log errors
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to stop PostgreSQL services
stop_postgresql() {
    log "Stopping PostgreSQL services..."
    
    # Stop services gracefully
    if systemctl is-active --quiet postgresql; then
        systemctl stop postgresql
        log "PostgreSQL service stopped"
    else
        log "PostgreSQL service was not running"
    fi
    
    if systemctl is-active --quiet postgresql@16-main; then
        systemctl stop postgresql@16-main
        log "PostgreSQL@16-main service stopped"
    else
        log "PostgreSQL@16-main service was not running"
    fi
    
    # Kill any remaining postgres processes
    if pgrep -f postgres > /dev/null; then
        log "Killing remaining postgres processes..."
        pkill -f postgres || true
        sleep 3
        
        # Force kill if still running
        if pgrep -f postgres > /dev/null; then
            log "Force killing postgres processes..."
            pkill -9 -f postgres || true
            sleep 2
        fi
    else
        log "No postgres processes found"
    fi
    
    log "PostgreSQL services stopped successfully"
}

# Function to remove package holds
remove_holds() {
    log "Removing package holds..."
    
    # List current holds
    log "Current package holds:"
    HOLDS=$(apt-mark showhold | grep -i postgres || echo "")
    if [[ -n "$HOLDS" ]]; then
        echo "$HOLDS"
        
        # Remove holds on PostgreSQL packages
        apt-mark unhold postgresql* 2>/dev/null || true
        apt-mark unhold libpq* 2>/dev/null || true
        
        log "Package holds removed"
    else
        log "No PostgreSQL holds found"
    fi
}

# Function to completely remove PostgreSQL
remove_postgresql() {
    log "Completely removing PostgreSQL..."
    
    # Stop services first
    stop_postgresql
    
    # Check what packages are installed
    log "Checking installed PostgreSQL packages..."
    dpkg -l | grep -i postgres || log "No PostgreSQL packages found"
    
    # Remove packages with --allow-change-held-packages
    log "Removing PostgreSQL packages..."
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y --allow-change-held-packages \
        postgresql* \
        libpq* \
        pgdg-keyring 2>/dev/null || true
    
    # Autoremove orphaned packages
    log "Removing orphaned packages..."
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --allow-change-held-packages 2>/dev/null || true
    
    log "PostgreSQL packages removed"
}

# Function to clean data directories
clean_data_directories() {
    log "Cleaning PostgreSQL data directories..."
    
    # List directories before removal
    log "Checking existing PostgreSQL directories..."
    ls -la /var/lib/postgresql/ 2>/dev/null || log "No /var/lib/postgresql/ directory"
    ls -la /etc/postgresql/ 2>/dev/null || log "No /etc/postgresql/ directory"
    
    # Remove data directories
    if [[ -d "/var/lib/postgresql/" ]]; then
        rm -rf /var/lib/postgresql/
        log "Removed /var/lib/postgresql/"
    fi
    
    if [[ -d "/etc/postgresql/" ]]; then
        rm -rf /etc/postgresql/
        log "Removed /etc/postgresql/"
    fi
    
    if [[ -d "/var/log/postgresql/" ]]; then
        rm -rf /var/log/postgresql/
        log "Removed /var/log/postgresql/"
    fi
    
    if [[ -d "/run/postgresql/" ]]; then
        rm -rf /run/postgresql/
        log "Removed /run/postgresql/"
    fi
    
    # Check if postgres user exists before removing
    if id postgres &>/dev/null; then
        log "Removing postgres user..."
        userdel postgres 2>/dev/null || log "Could not remove postgres user (may not exist)"
    fi
    
    if getent group postgres &>/dev/null; then
        log "Removing postgres group..."
        groupdel postgres 2>/dev/null || log "Could not remove postgres group (may not exist)"
    fi
    
    log "Data directories cleaned"
}

# Function to update package lists
update_packages() {
    log "Updating package lists..."
    if apt-get update; then
        log "Package lists updated successfully"
    else
        log_error "Failed to update package lists"
        return 1
    fi
}

# Function to install specific PostgreSQL version
install_postgresql_16_2() {
    log "Installing PostgreSQL 16.2-1ubuntu4..."
    
    # Check if the specific version is available
    log "Checking available PostgreSQL versions..."
    apt-cache policy postgresql-16 || log "postgresql-16 package not found in cache"
    
    # Install specific version
    log "Installing PostgreSQL packages..."
    if DEBIAN_FRONTEND=noninteractive apt-get install -y \
        postgresql-16=16.2-1ubuntu4 \
        postgresql-client-16=16.2-1ubuntu4 \
        postgresql-contrib-16=16.2-1ubuntu4; then
        
        # Hold the packages to prevent automatic updates
        apt-mark hold postgresql-16 postgresql-client-16 postgresql-contrib-16
        
        log "PostgreSQL 16.2-1ubuntu4 installed and held successfully"
    else
        log_error "Failed to install PostgreSQL 16.2-1ubuntu4"
        log "Trying to install latest available version..."
        
        if DEBIAN_FRONTEND=noninteractive apt-get install -y \
            postgresql-16 \
            postgresql-client-16 \
            postgresql-contrib-16; then
            log "PostgreSQL 16 (latest available) installed successfully"
        else
            log_error "Failed to install PostgreSQL"
            return 1
        fi
    fi
}

# Function to initialize database cluster
initialize_database() {
    log "Initializing PostgreSQL database cluster..."
    
    # Ensure postgres user exists
    if ! id postgres &>/dev/null; then
        log "Creating postgres user..."
        useradd -r -s /bin/bash -d /var/lib/postgresql postgres
    else
        log "Postgres user already exists"
    fi
    
    # Create necessary directories
    log "Creating PostgreSQL directories..."
    mkdir -p /var/lib/postgresql/16/main
    mkdir -p /var/log/postgresql
    mkdir -p /run/postgresql
    
    # Set proper ownership
    chown -R postgres:postgres /var/lib/postgresql
    chown -R postgres:postgres /var/log/postgresql
    chown -R postgres:postgres /run/postgresql
    
    # Check if cluster already exists
    if [[ -f "/var/lib/postgresql/16/main/PG_VERSION" ]]; then
        log "Database cluster already exists, removing..."
        rm -rf /var/lib/postgresql/16/main/*
    fi
    
    # Initialize the database cluster
    log "Running initdb..."
    if sudo -u postgres /usr/lib/postgresql/16/bin/initdb \
        --pgdata=/var/lib/postgresql/16/main \
        --auth-local=peer \
        --auth-host=md5 \
        --encoding=UTF8 \
        --locale=en_US.UTF-8; then
        log "Database cluster initialized successfully"
    else
        log_error "Failed to initialize database cluster"
        return 1
    fi
}

# Function to configure PostgreSQL
configure_postgresql() {
    log "Configuring PostgreSQL..."
    
    # Start PostgreSQL service
    log "Starting PostgreSQL service..."
    if systemctl start postgresql; then
        log "PostgreSQL service started"
    else
        log_error "Failed to start PostgreSQL service"
        systemctl status postgresql --no-pager
        return 1
    fi
    
    systemctl enable postgresql
    
    # Wait for service to be ready
    log "Waiting for PostgreSQL to be ready..."
    sleep 5
    
    # Check if service is running
    if systemctl is-active --quiet postgresql; then
        log "PostgreSQL service is active"
    else
        log_error "PostgreSQL service is not active"
        systemctl status postgresql --no-pager
        return 1
    fi
    
    # Set postgres user password
    log "Setting postgres user password..."
    if sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres123';"; then
        log "Postgres user password set successfully"
    else
        log_error "Failed to set postgres user password"
        return 1
    fi
    
    # Update pg_hba.conf for md5 authentication
    PG_HBA="/etc/postgresql/16/main/pg_hba.conf"
    if [[ -f "$PG_HBA" ]]; then
        log "Updating pg_hba.conf..."
        # Backup original
        cp "$PG_HBA" "$PG_HBA.backup"
        
        # Update authentication method
        sed -i 's/local   all             postgres                                peer/local   all             postgres                                md5/' "$PG_HBA"
        sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' "$PG_HBA"
        
        # Reload configuration
        systemctl reload postgresql
        log "PostgreSQL configuration updated"
    else
        log_error "pg_hba.conf not found at $PG_HBA"
    fi
}

# Function to verify installation
verify_installation() {
    log "Verifying PostgreSQL installation..."
    
    # Check service status
    log "PostgreSQL service status:"
    systemctl status postgresql --no-pager
    
    # Check version
    log "PostgreSQL version:"
    sudo -u postgres psql -c "SELECT version();" || log_error "Failed to check version"
    
    # Check if we can connect with password
    log "Testing connection with password..."
    if PGPASSWORD=postgres123 psql -U postgres -h localhost -c "SELECT 'Connection successful';"; then
        log "Password authentication successful"
    else
        log_error "Password authentication failed"
    fi
    
    log "PostgreSQL installation verification completed"
}

# Main execution
main() {
    log "Starting PostgreSQL 16.2-1ubuntu4 reinstallation..."
    
    check_root
    
    # Execute each step with error handling
    if ! stop_postgresql; then
        log_error "Failed to stop PostgreSQL services"
    fi
    
    if ! remove_holds; then
        log_error "Failed to remove package holds"
    fi
    
    if ! remove_postgresql; then
        log_error "Failed to remove PostgreSQL packages"
    fi
    
    if ! clean_data_directories; then
        log_error "Failed to clean data directories"
    fi
    
    if ! update_packages; then
        log_error "Failed to update packages"
        exit 1
    fi
    
    if ! install_postgresql_16_2; then
        log_error "Failed to install PostgreSQL"
        exit 1
    fi
    
    if ! initialize_database; then
        log_error "Failed to initialize database"
        exit 1
    fi
    
    if ! configure_postgresql; then
        log_error "Failed to configure PostgreSQL"
        exit 1
    fi
    
    verify_installation
    
    log "PostgreSQL 16.2-1ubuntu4 reinstallation completed!"
    echo ""
    echo "=== Installation Summary ==="
    echo "Version: PostgreSQL 16.2-1ubuntu4 (or latest available)"
    echo "User: postgres"
    echo "Password: postgres123"
    echo "Authentication: md5"
    echo "Status: $(systemctl is-active postgresql 2>/dev/null || echo 'unknown')"
    echo ""
    echo "You can now connect using:"
    echo "  psql -U postgres -h localhost"
    echo "  Password: postgres123"
}

# Run main function
main "$@"
