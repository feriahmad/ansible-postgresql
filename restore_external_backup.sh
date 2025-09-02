#!/bin/bash

# Script untuk restore backup PostgreSQL dari server eksternal
# Menangani perbedaan konfigurasi, versi, dan data format

set -e

# Konfigurasi
BACKUP_DIR="/var/backups/postgresql"
LOG_FILE="${BACKUP_DIR}/external_restore.log"

# Fungsi untuk log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "${LOG_FILE}"
}

# Fungsi untuk menampilkan bantuan
show_help() {
    echo "PostgreSQL External Backup Restore Script"
    echo ""
    echo "Usage: $0 [OPTIONS] <backup_file>"
    echo ""
    echo "Options:"
    echo "  -d, --database NAME    Target database name (default: postgres)"
    echo "  -c, --clean           Drop database before restore"
    echo "  -v, --verbose         Verbose output"
    echo "  -f, --force           Force restore (ignore all warnings)"
    echo "  -s, --skip-errors     Continue on errors"
    echo "  -o, --owner-fix       Fix ownership issues"
    echo "  -r, --role-fix        Create missing roles"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -f -s -o external_backup.sql"
    echo "  $0 -d newdb -c -r external_backup.sql.gz"
}

# Default values
DATABASE="postgres"
CLEAN_DB=false
VERBOSE=false
FORCE=false
SKIP_ERRORS=false
OWNER_FIX=false
ROLE_FIX=false
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
        -s|--skip-errors)
            SKIP_ERRORS=true
            shift
            ;;
        -o|--owner-fix)
            OWNER_FIX=true
            shift
            ;;
        -r|--role-fix)
            ROLE_FIX=true
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
    echo "Error: File backup tidak ditemukan: $BACKUP_FILE"
    exit 1
fi

log_message "=== MEMULAI RESTORE BACKUP EKSTERNAL ==="
log_message "File backup: $BACKUP_FILE"
log_message "Target database: $DATABASE"

# Buat direktori backup jika belum ada
sudo mkdir -p "${BACKUP_DIR}"

# Deteksi dan ekstrak file jika terkompresi
WORKING_FILE="$BACKUP_FILE"
if [[ "$BACKUP_FILE" == *.gz ]]; then
    log_message "File terkompresi terdeteksi, mengekstrak..."
    WORKING_FILE="/tmp/external_restore_$(date +%s).sql"
    
    if gunzip -c "$BACKUP_FILE" > "$WORKING_FILE"; then
        log_message "File berhasil diekstrak ke: $WORKING_FILE"
        CLEANUP_TEMP=true
    else
        log_message "Error: Gagal mengekstrak file backup"
        exit 1
    fi
fi

# Analisis backup file
log_message "Menganalisis file backup..."

# Cek versi PostgreSQL dari backup
BACKUP_VERSION=$(head -20 "$WORKING_FILE" | grep "Dumped by pg_dump version" | sed 's/.*version \([0-9.]*\).*/\1/' || echo "unknown")
CURRENT_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -o "PostgreSQL [0-9.]*" | sed 's/PostgreSQL //' || echo "unknown")

log_message "Versi backup: $BACKUP_VERSION"
log_message "Versi PostgreSQL saat ini: $CURRENT_VERSION"

# Cek apakah ada roles/users yang perlu dibuat
ROLES_IN_BACKUP=$(grep -o "OWNER TO [a-zA-Z_][a-zA-Z0-9_]*" "$WORKING_FILE" | sed 's/OWNER TO //' | sort -u || true)
if [[ -n "$ROLES_IN_BACKUP" ]]; then
    log_message "Roles ditemukan di backup: $ROLES_IN_BACKUP"
fi

# Cek apakah ada extensions
EXTENSIONS=$(grep -o "CREATE EXTENSION [a-zA-Z_][a-zA-Z0-9_]*" "$WORKING_FILE" | sed 's/CREATE EXTENSION //' | sort -u || true)
if [[ -n "$EXTENSIONS" ]]; then
    log_message "Extensions ditemukan: $EXTENSIONS"
fi

# Buat file backup yang sudah dimodifikasi untuk kompatibilitas
MODIFIED_FILE="/tmp/external_restore_modified_$(date +%s).sql"
log_message "Membuat file backup yang dimodifikasi untuk kompatibilitas..."

# Modifikasi backup untuk kompatibilitas
cat "$WORKING_FILE" | \
    # Hapus SET statements yang mungkin bermasalah
    sed '/^SET lock_timeout = 0;/d' | \
    sed '/^SET idle_in_transaction_session_timeout = 0;/d' | \
    sed '/^SET row_security = off;/d' | \
    # Perbaiki JSON format yang corrupt
    sed -E 's/"([0-9]{1,2}):([0-9])"/"0\1:0\20"/g' | \
    sed -E 's/"([0-9]{2}):([0-9])"/"0\1:0\20"/g' | \
    # Hapus comment yang mungkin bermasalah
    sed '/^--.*$/d' | \
    # Perbaiki ownership jika diminta
    $(if [[ "$OWNER_FIX" == true ]]; then echo "sed 's/OWNER TO [a-zA-Z_][a-zA-Z0-9_]*/OWNER TO postgres/g'"; else echo "cat"; fi) \
    > "$MODIFIED_FILE"

# Buat roles yang diperlukan jika diminta
if [[ "$ROLE_FIX" == true && -n "$ROLES_IN_BACKUP" ]]; then
    log_message "Membuat roles yang diperlukan..."
    for role in $ROLES_IN_BACKUP; do
        if [[ "$role" != "postgres" ]]; then
            log_message "Membuat role: $role"
            sudo -u postgres psql -c "CREATE ROLE \"$role\" LOGIN;" 2>/dev/null || log_message "Role $role sudah ada atau gagal dibuat"
        fi
    done
fi

# Drop database jika diminta
if [[ "$CLEAN_DB" == true && "$DATABASE" != "postgres" ]]; then
    log_message "Menghapus database: $DATABASE"
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS \"$DATABASE\";" || true
    sudo -u postgres psql -c "CREATE DATABASE \"$DATABASE\";"
fi

# Siapkan opsi psql
PSQL_OPTS="-d $DATABASE"
if [[ "$SKIP_ERRORS" == true ]]; then
    PSQL_OPTS="$PSQL_OPTS -v ON_ERROR_STOP=0"
else
    PSQL_OPTS="$PSQL_OPTS -v ON_ERROR_STOP=1"
fi

if [[ "$VERBOSE" == false ]]; then
    PSQL_OPTS="$PSQL_OPTS -q"
fi

# Lakukan restore
log_message "Memulai proses restore..."
log_message "Opsi psql: $PSQL_OPTS"

# Restore dengan error handling yang lebih baik
RESTORE_SUCCESS=false
if sudo -u postgres psql $PSQL_OPTS < "$MODIFIED_FILE" 2>&1 | tee -a "$LOG_FILE"; then
    RESTORE_SUCCESS=true
    log_message "Restore berhasil diselesaikan"
else
    if [[ "$SKIP_ERRORS" == true ]]; then
        log_message "Restore selesai dengan beberapa error (diabaikan)"
        RESTORE_SUCCESS=true
    else
        log_message "Error: Restore gagal"
    fi
fi

# Cleanup temporary files
if [[ "$CLEANUP_TEMP" == true ]]; then
    rm -f "$WORKING_FILE"
fi
rm -f "$MODIFIED_FILE"

# Tampilkan hasil
echo ""
if [[ "$RESTORE_SUCCESS" == true ]]; then
    echo "✅ Restore eksternal berhasil!"
    echo "Database: $DATABASE"
    
    # Tampilkan informasi database
    echo ""
    echo "Informasi database setelah restore:"
    sudo -u postgres psql -d "$DATABASE" -c "\l+" | grep "$DATABASE" || true
    
    echo ""
    echo "Tabel yang berhasil di-restore:"
    sudo -u postgres psql -d "$DATABASE" -c "\dt" 2>/dev/null | head -10 || echo "Tidak ada tabel yang ditemukan"
    
    echo ""
    echo "Jumlah record di beberapa tabel:"
    sudo -u postgres psql -d "$DATABASE" -c "
        SELECT schemaname,tablename,n_tup_ins as inserted_rows 
        FROM pg_stat_user_tables 
        WHERE n_tup_ins > 0 
        ORDER BY n_tup_ins DESC 
        LIMIT 5;" 2>/dev/null || true
        
else
    echo "❌ Restore gagal!"
    echo ""
    echo "Tips troubleshooting:"
    echo "1. Coba dengan flag -s (skip errors): $0 -s -f $BACKUP_FILE"
    echo "2. Coba dengan role fix: $0 -r -o -f $BACKUP_FILE"
    echo "3. Coba ke database baru: $0 -c -d test_restore -f $BACKUP_FILE"
    echo "4. Periksa log detail: tail -f $LOG_FILE"
fi

echo ""
echo "Log lengkap: $LOG_FILE"
log_message "=== RESTORE EKSTERNAL SELESAI ==="
