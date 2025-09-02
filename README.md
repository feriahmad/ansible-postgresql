# Ansible PostgreSQL 16.3 Installation

This Ansible playbook installs and configures PostgreSQL 16.3 on Ubuntu 24.04 with automated backup functionality.

## Features

- ✅ PostgreSQL 16.3 installation from official repository
- ✅ Secure password configuration via environment variables
- ✅ Automated daily backups with compression
- ✅ Backup retention and cleanup
- ✅ Localhost-only configuration
- ✅ Environment variables not tracked in Git

## Prerequisites

- Ubuntu 24.04 LTS
- Ansible installed on the target machine
- sudo privileges

## Quick Start

1. **Clone this repository:**
   ```bash
   git clone <repository-url>
   cd ansible-postgresql
   ```

2. **Configure environment variables:**
   ```bash
   cp .env .env.local  # Optional: create a local copy
   nano .env
   ```
   
   Update the following variables in `.env`:
   ```bash
   POSTGRES_PASSWORD=your_secure_password_here
   POSTGRES_DB=postgres
   POSTGRES_USER=postgres
   BACKUP_RETENTION_DAYS=7
   BACKUP_PATH=/var/backups/postgresql
   ```

3. **Run the playbook:**
   ```bash
   ansible-playbook -i inventory/hosts.yml playbook.yml
   ```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | PostgreSQL admin password | `your_secure_password_here` |
| `POSTGRES_USER` | PostgreSQL admin username | `postgres` |
| `POSTGRES_DB` | Default database name | `postgres` |
| `BACKUP_RETENTION_DAYS` | Days to keep backups | `7` |
| `BACKUP_PATH` | Backup storage directory | `/var/backups/postgresql` |

### Playbook Tags

You can run specific parts of the playbook using tags:

```bash
# Only setup and installation
ansible-playbook -i inventory/hosts.yml playbook.yml --tags "setup,install"

# Only backup configuration
ansible-playbook -i inventory/hosts.yml playbook.yml --tags "backup"

# Only PostgreSQL configuration
ansible-playbook -i inventory/hosts.yml playbook.yml --tags "configure"
```

## Backup System

### Automatic Backups

- **Daily backups**: Run at 2:00 AM every day
- **Backup cleanup**: Run at 3:30 AM every Sunday
- **Backup format**: Compressed SQL dumps (`.sql.gz`)
- **Backup location**: `/var/backups/postgresql/` (configurable)

### Manual Backup

```bash
# Run backup manually
sudo -u postgres /usr/local/bin/postgresql_backup.sh

# Run cleanup manually
sudo -u postgres /usr/local/bin/postgresql_cleanup_backups.sh
```

### Restore from Backup

```bash
# Decompress backup
gunzip /var/backups/postgresql/postgresql_backup_YYYYMMDD_HHMMSS.sql.gz

# Restore database
sudo -u postgres psql < /var/backups/postgresql/postgresql_backup_YYYYMMDD_HHMMSS.sql
```

## Security

- PostgreSQL is configured to listen only on localhost
- Password authentication is required for the postgres user
- Backup files are owned by postgres user with 600 permissions
- Environment variables containing sensitive data are excluded from Git

## Connecting to PostgreSQL

After installation, you can connect to PostgreSQL:

```bash
# Connect as postgres user
sudo -u postgres psql

# Connect with password (from another user)
psql -h localhost -U postgres -d postgres
```

## Troubleshooting

### Check PostgreSQL Status
```bash
sudo systemctl status postgresql
```

### View PostgreSQL Logs
```bash
sudo tail -f /var/log/postgresql/postgresql-16-main.log
```

### Check Backup Logs
```bash
sudo tail -f /var/backups/postgresql/backup.log
```

### Verify Backup Cron Jobs
```bash
sudo -u postgres crontab -l
```

## File Structure

```
ansible-postgresql/
├── inventory/
│   └── hosts.yml              # Ansible inventory (localhost)
├── templates/
│   ├── backup_script.sh.j2    # Daily backup script template
│   └── cleanup_backups.sh.j2  # Backup cleanup script template
├── vars/
│   └── main.yml               # Variable definitions
├── .env                       # Environment variables (not in Git)
├── .gitignore                 # Git ignore rules
├── playbook.yml               # Main Ansible playbook
└── README.md                  # This file
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.
