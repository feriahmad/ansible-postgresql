# Ansible PostgreSQL 16 Installation

Script Ansible sederhana untuk install PostgreSQL 16 di Ubuntu 24.04 dengan backup otomatis.

## Fitur

- ✅ Install PostgreSQL 16 (versi terbaru) dari repository resmi
- ✅ User postgres dengan password: `PostgreSQL123!`
- ✅ Backup otomatis harian dengan kompresi
- ✅ Cleanup backup otomatis (retensi 7 hari)
- ✅ Konfigurasi localhost only

## Cara Penggunaan

1. **Clone repository:**
   ```bash
   git clone <repository-url>
   cd ansible-postgresql
   ```

2. **Install Ansible (jika belum ada):**
   ```bash
   sudo apt update
   sudo apt install ansible
   ```

3. **Jalankan script:**
   ```bash
   # Untuk PostgreSQL versi terbaru
   ansible-playbook playbook.yml
   
   # Atau untuk PostgreSQL 16.2 spesifik (recommended untuk restore backup eksternal)
   chmod +x install_postgresql_16.2.sh
   ./install_postgresql_16.2.sh
   ```

## Informasi Login

- **Username:** postgres
- **Password:** PostgreSQL123!
- **Database:** postgres
- **Host:** localhost

## Koneksi ke PostgreSQL

```bash
# Sebagai user postgres
sudo -u postgres psql

# Dengan password dari user lain
psql -h localhost -U postgres -d postgres
```

## Backup System

- **Backup harian:** Jam 02:00 setiap hari
- **Cleanup backup:** Jam 03:30 setiap hari Minggu
- **Lokasi backup:** `/var/backups/postgresql/`
- **Format:** File SQL terkompresi (.sql.gz)

### Manual Backup

```bash
# Menggunakan script backup sederhana
chmod +x backup_postgresql.sh
./backup_postgresql.sh

# Atau jalankan backup yang sudah diinstall Ansible
sudo -u postgres /usr/local/bin/postgresql_backup.sh

# Jalankan cleanup manual
sudo -u postgres /usr/local/bin/postgresql_cleanup_backups.sh
```

### Restore Backup

#### Menggunakan Script Restore (Recommended)
```bash
# Buat script executable
chmod +x restore_postgresql.sh

# Restore dengan pengecekan versi otomatis
./restore_postgresql.sh backup_file.sql.gz

# Restore ke database tertentu
./restore_postgresql.sh -d mydatabase backup_file.sql.gz

# Force restore (abaikan warning versi)
./restore_postgresql.sh -f -v backup_file.sql.gz

# Restore dengan drop database dulu
./restore_postgresql.sh -c -d mydatabase backup_file.sql.gz
```

#### Manual Restore
```bash
# Ekstrak backup
gunzip /var/backups/postgresql/postgresql_backup_YYYYMMDD_HHMMSS.sql.gz

# Restore database
sudo -u postgres psql < /var/backups/postgresql/postgresql_backup_YYYYMMDD_HHMMSS.sql
```

#### Menangani Perbedaan Versi PostgreSQL
Jika backup dari versi PostgreSQL yang berbeda:

1. **Backup dari versi lama ke baru:** Biasanya aman
2. **Backup dari versi baru ke lama:** Bisa bermasalah
3. **Gunakan flag `-f` untuk memaksa restore**
4. **Periksa log error di `/var/backups/postgresql/restore.log`**

**Tips untuk masalah versi:**
```bash
# Cek versi PostgreSQL saat ini
sudo -u postgres psql -c "SELECT version();"

# Restore dengan verbose untuk melihat error detail
./restore_postgresql.sh -f -v backup_file.sql.gz

# Jika ada error, coba restore ke database baru
./restore_postgresql.sh -c -d test_restore backup_file.sql.gz
```

#### Menangani Data Corrupt/Invalid JSON
Jika terjadi error seperti "invalid input syntax for type json":

```bash
# Perbaiki data backup yang corrupt
chmod +x fix_backup_data.sh

# Perbaiki file backup
./fix_backup_data.sh backup_file.sql backup_file_fixed.sql

# Atau dengan backup asli dan verbose
./fix_backup_data.sh -b -v backup_file.sql backup_file_fixed.sql

# Kemudian restore file yang sudah diperbaiki
./restore_postgresql.sh -f backup_file_fixed.sql
```

**Masalah umum yang diperbaiki:**
- JSON time format corrupt (`"06:0"` → `"06:00"`)
- JSON string tidak tertutup
- Trailing comma di JSON
- Boolean value yang corrupt

#### Restore Backup dari Server Eksternal
Untuk backup dari server lain dengan konfigurasi berbeda:

```bash
# Script khusus untuk backup eksternal
chmod +x restore_external_backup.sh

# Restore dengan semua perbaikan otomatis
./restore_external_backup.sh -f -s -o -r backup_file.sql

# Restore ke database baru dengan cleanup
./restore_external_backup.sh -c -d external_db -f -s backup_file.sql

# Verbose mode untuk troubleshooting
./restore_external_backup.sh -v -f -s -o backup_file.sql
```

**Fitur script eksternal:**
- **`-f`** : Force restore (abaikan warning)
- **`-s`** : Skip errors (lanjutkan meski ada error)
- **`-o`** : Fix ownership issues (ubah owner ke postgres)
- **`-r`** : Create missing roles otomatis
- **`-c`** : Clean database sebelum restore
- **`-v`** : Verbose output untuk debugging

**Masalah yang ditangani:**
- Perbedaan versi PostgreSQL
- User/role yang tidak ada
- Ownership issues
- JSON format corrupt
- SET statements yang tidak kompatibel
- Extensions yang berbeda

## Troubleshooting

### Cek Status PostgreSQL
```bash
sudo systemctl status postgresql
```

### Lihat Log PostgreSQL
```bash
sudo tail -f /var/log/postgresql/postgresql-16-main.log
```

### Cek Log Backup
```bash
sudo tail -f /var/backups/postgresql/backup.log
```

## File Structure

```
ansible-postgresql/
├── inventory/
│   └── hosts.yml              # Inventory localhost
├── templates/
│   ├── backup_script.sh.j2    # Script backup harian
│   └── cleanup_backups.sh.j2  # Script cleanup backup
├── ansible.cfg                # Konfigurasi Ansible
├── backup_postgresql.sh       # Script backup manual
├── fix_backup_data.sh         # Script perbaikan data corrupt
├── install_postgresql_16.2.sh # Script install PostgreSQL 16.2 spesifik
├── install_postgresql_16.4.sh # Script install PostgreSQL 16.4 spesifik
├── restore_postgresql.sh      # Script restore dengan version handling
├── restore_external_backup.sh # Script restore backup dari server eksternal
├── playbook.yml               # Main playbook
└── README.md                  # File ini
