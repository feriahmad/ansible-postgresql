#!/bin/bash

# PostgreSQL Restore Script
# Script untuk restore backup PostgreSQL dengan handling error

set -e

# Konfigurasi
BACKUP_DIR="/var/backups/postgresql"
LOG_FILE="${BACKUP_DIR}/restore.log"

# Fungsi untuk log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "${LOG_FILE}"
}

# Fungsi untuk menampilkan bantuan
show_help() {
    echo "PostgreSQL Restore Script"
    echo ""
    echo "Usage: $0 [OPTIONS] <backup_file>"
    echo ""
    echo "Options:"
    echo "  -d, --database NAME    Target database name (default: postgres)"
    echo "  -c, --clean           Drop database before restore"
    echo "  -v, --verbose         Verbose output"
    echo "  -f, --force           Force restore (ignore version warnings)"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 backup_file.sql.gz"
    echo "  $0 -d mydb -c backup_file.sql"
    echo "  $0 -f -v backup_file.sql.gz"
}

# Default values
DATABASE="postgres"
CLEAN_DB=false
VERBOSE=false
FORCE=false
BACKUP_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--database)
            DATABASE="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_DB=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option $1"
            show_help
            exit 1
            ;;
        *)
            BACKUP_FILE="$1"
            shift
            ;;
    esac
done

# Validasi input
if [[ -z "$BACKUP_FILE" ]]; then
    echo "Error: Backup file tidak dispesifikasi"
    show_help
    exit 1
fi

# Cek apakah file backup ada
if [[ ! -f "$BACKUP_FILE" ]]; then
    # Coba cari di direktori backup
    if [[ -f "${BACKUP_DIR}/${BACKUP_FILE}" ]]; then
        BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILE}"
    else
        echo "Error: File backup tidak ditemukan: $BACKUP_FILE"
        exit 1
    fi
fi

log_message "Memulai proses restore dari: $BACKUP_FILE"

# Cek apakah file terkompresi
if [[ "$BACKUP_FILE" == *.gz ]]; then
    log_message "File terkompresi terdeteksi, akan diekstrak..."
    TEMP_FILE="/tmp/restore_$(date +%s).sql"
    
    if gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"; then
        log_message "File berhasil diekstrak ke: $TEMP_FILE"
        BACKUP_FILE="$TEMP_FILE"
        CLEANUP_TEMP=true
    else
        log_message "Error: Gagal mengekstrak file backup"
        exit 1
    fi
fi

# Cek versi PostgreSQL dari backup
BACKUP_VERSION=$(head -20 "$BACKUP_FILE" | grep "Dumped by pg_dump version" | sed 's/.*version \([0-9.]*\).*/\1/' || echo "unknown")
CURRENT_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -o "PostgreSQL [0-9.]*" | sed 's/PostgreSQL //' || echo "unknown")

log_message "Versi backup: $BACKUP_VERSION"
log_message "Versi PostgreSQL saat ini: $CURRENT_VERSION"

# Warning jika versi berbeda
if [[ "$BACKUP_VERSION" != "unknown" && "$CURRENT_VERSION" != "unknown" && "$BACKUP_VERSION" != "$CURRENT_VERSION"* ]]; then
    if [[ "$FORCE" == false ]]; then
        echo "WARNING: Perbedaan versi terdeteksi!"
        echo "Backup version: $BACKUP_VERSION"
        echo "Current version: $CURRENT_VERSION"
        echo ""
        echo "Ini bisa menyebabkan masalah kompatibilitas."
        echo "Gunakan flag -f untuk memaksa restore atau -h untuk bantuan."
        exit 1
    else
        log_message "WARNING: Memaksa restore meskipun ada perbedaan versi"
    fi
fi

# Drop database jika diminta
if [[ "$CLEAN_DB" == true && "$DATABASE" != "postgres" ]]; then
    log_message "Menghapus database: $DATABASE"
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS \"$DATABASE\";" || true
    sudo -u postgres psql -c "CREATE DATABASE \"$DATABASE\";"
fi

# Lakukan restore
log_message "Memulai restore ke database: $DATABASE"

PSQL_OPTS="-d $DATABASE"
if [[ "$VERBOSE" == true ]]; then
    PSQL_OPTS="$PSQL_OPTS -v ON_ERROR_STOP=1"
else
    PSQL_OPTS="$PSQL_OPTS -q"
fi

# Restore dengan error handling
if sudo -u postgres psql $PSQL_OPTS < "$BACKUP_FILE" 2>&1 | tee -a "$LOG_FILE"; then
    log_message "Restore berhasil diselesaikan"
    echo "✅ Restore berhasil!"
    echo "Database: $DATABASE"
    echo "Log: $LOG_FILE"
else
    log_message "Error: Restore gagal"
    echo "❌ Restore gagal!"
    echo "Periksa log untuk detail: $LOG_FILE"
    
    # Cleanup jika ada error
    if [[ "$CLEANUP_TEMP" == true ]]; then
        rm -f "$TEMP_FILE"
    fi
    exit 1
fi

# Cleanup temporary file
if [[ "$CLEANUP_TEMP" == true ]]; then
    rm -f "$TEMP_FILE"
    log_message "File temporary dibersihkan"
fi

# Tampilkan informasi database setelah restore
echo ""
echo "Informasi database setelah restore:"
sudo -u postgres psql -d "$DATABASE" -c "\l+" | grep "$DATABASE" || true
sudo -u postgres psql -d "$DATABASE" -c "\dt" 2>/dev/null | head -10 || echo "Tidak ada tabel yang ditemukan"

log_message "Proses restore selesai"
