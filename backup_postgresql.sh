#!/bin/bash

# PostgreSQL Backup Script Sederhana
# Untuk backup manual PostgreSQL

set -e

# Konfigurasi
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="postgresql_backup_${DATE}.sql"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Buat direktori backup jika belum ada
sudo mkdir -p "${BACKUP_DIR}"

# Fungsi untuk log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "${LOG_FILE}"
}

log_message "Memulai backup PostgreSQL..."

# Lakukan backup
if sudo -u postgres pg_dumpall > "/tmp/${BACKUP_FILE}"; then
    log_message "Backup berhasil: ${BACKUP_FILE}"
    
    # Pindahkan ke direktori backup
    sudo mv "/tmp/${BACKUP_FILE}" "${BACKUP_DIR}/"
    
    # Kompres backup
    if sudo gzip "${BACKUP_DIR}/${BACKUP_FILE}"; then
        log_message "Backup berhasil dikompres: ${BACKUP_FILE}.gz"
    else
        log_message "Warning: Gagal mengkompres backup"
    fi
else
    log_message "Error: Backup gagal!"
    exit 1
fi

# Set permission yang benar
sudo chown postgres:postgres "${BACKUP_DIR}/${BACKUP_FILE}.gz" 2>/dev/null || true
sudo chmod 600 "${BACKUP_DIR}/${BACKUP_FILE}.gz" 2>/dev/null || true

log_message "Proses backup selesai."

# Tampilkan informasi backup
echo "Backup tersimpan di: ${BACKUP_DIR}/${BACKUP_FILE}.gz"
echo "Log backup: ${LOG_FILE}"
