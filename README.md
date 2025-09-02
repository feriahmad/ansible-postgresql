# Ansible PostgreSQL 16.3 Installation

Script Ansible sederhana untuk install PostgreSQL 16.3 di Ubuntu 24.04 dengan backup otomatis.

## Fitur

- ✅ Install PostgreSQL 16.3 dari repository resmi
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
   ansible-playbook playbook.yml
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

```bash
# Ekstrak backup
gunzip /var/backups/postgresql/postgresql_backup_YYYYMMDD_HHMMSS.sql.gz

# Restore database
sudo -u postgres psql < /var/backups/postgresql/postgresql_backup_YYYYMMDD_HHMMSS.sql
```

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
├── playbook.yml               # Main playbook
└── README.md                  # File ini
