# [scripts](.)
This directory exists to store scripts that will be run on competition day.

## Table of Contents

### Core Competition Scripts (run in order)
- [01_ssh_lockdown.sh](#01_ssh_lockdownsh) - SSH hardening, backdoor removal, key deployment
- [02_fail2ban_deploy.sh](#02_fail2ban_deploysh) - Brute force protection
- [03_kernel_hardening.sh](#03_kernel_hardeningsh) - Kernel security parameters
- [04_firewall_lockdown.sh](#04_firewall_lockdownsh) - UFW firewall configuration
- [05_service_audit.sh](#05_service_auditsh) - Disable unnecessary services
- [06_file_integrity.sh](#06_file_integritysh) - File integrity monitoring
- [07_log_monitoring.sh](#07_log_monitoringsh) - **HIDS: Falco + AIDE + ntfy alerts**
- [08_web_hardening.sh](#08_web_hardeningsh) - Web server security (Apache/Nginx)
- [09_database_hardening.sh](#09_database_hardeningsh) - Database security (MySQL/PostgreSQL)
- [10_final_audit.sh](#10_final_auditsh) - Comprehensive security audit

### Optional Scripts (@ prefix = run anytime)
- [@gravwell_setup.sh](#gravwell_setupsh) - Centralized logging to Gravwell

### Legacy Scripts
- [backups.sh](#backupssh) - Local and remote backups of important directories
- [ssh_keys.sh](#ssh_keyssh) - Add public scoring and team keys to users
- [websetup.sh](#websetupsh) - Web server cronjob management

## [backups.sh](./backups.sh)
- This script performs both local and remote backups of important directories.
- Author: Christopher Reed
- Must be run with sudo.

**Key Files Created/Used:**
- `/root/backups/` - Local backup directory
- `/root/backups/etc_backup.txt` - Backup log for /etc
- `/root/backups/home_backup.txt` - Backup log for /home
- `/root/backups/var_backup.txt` - Backup log for /var/log
- `/root/backups/lib_backup.txt` - Backup log for /lib/systemd
- `/root/backups/bin_backup.txt` - Backup log for /usr/bin
- `/root/backups/sbin_backup.txt` - Backup log for /usr/sbin
- `/root/backups/curr_backup.txt` - Current remote backup log
- `/root/backup_key` - SSH key for remote backups
- `backups@192.168.2.15:~/backups/` - Remote backup location
## [ssh_keys.sh](./ssh_keys.sh)
- This script adds the public scoring key to each scoring user and David's public key to the blueteam user.
- Author: Christopher Reed
- Must be run with sudo.
- Uses:
  - [ssh_scoring_users.txt](../dynamic_files/ssh_scoring_users.txt): List of SSH scoring users
  - [scoring_key.pub](../dynamic_files/scoring_users.txt): Public Scoring Key
  - [david_key.pub](../dynamic_files/david_key.pub): David's Public Key

**Key Files Created/Used:**
- `/home/{user}/.ssh/` - SSH directories created for each scoring user
- `/home/{user}/.ssh/authorized_keys` - Authorized keys files for each user
- `/home/{user}/.ssh/scoring_key.pub` - Copied scoring key for each user
- `/home/blueteam/.ssh/david_key.pub` - David's public key for blueteam
- `../dynamic_files/scoring_users.txt` - Input file with scoring usernames
- `../dynamic_files/scoring_key.pub` - Input scoring public key
- `../dynamic_files/david_key.pub` - Input David's public key
- SSH and SSHD services enabled and restarted
## [websetup.sh](./websetup.sh)
- This script aids in web server cronjob management.
- Author: Ryan Speulstra

**Key Files Created/Used:**
- Crontab entries modified (removes all existing, adds new)
- `*/10 * * * * sudo systemctl restart {service}` - New cronjob added
- Apache2 or Nginx service detection and startup
- System hostname and user information displayed
- Current user's crontab completely replaced

---

## [07_log_monitoring.sh](./07_log_monitoring.sh)
**Host-Based Intrusion Detection System (HIDS) - Falco + AIDE + ntfy**

Deploys a three-layer detection stack with instant push notifications:
1. **inotifywait file watcher** - Instant alerts on changes to critical files
2. **Falco runtime detection** - eBPF-based behavioral monitoring
3. **AIDE file integrity** - Periodic baseline comparisons

**Deployment time:** ~5 minutes (AIDE baseline builds in background)

**Usage:**
```bash
# Interactive (prompts for ntfy topic):
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/07_log_monitoring.sh | sudo bash

# Non-interactive:
NTFY_TOPIC=blueteam-alerts curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/07_log_monitoring.sh | sudo bash
```

**What it detects:**
- Reverse shells (bash/sh with network socket connection)
- Webshells (shell spawned from apache2/nginx/php-fpm)
- Bind shells (netcat listeners)
- Attacker tools (nmap, hydra, sqlmap, linpeas, metasploit, etc.)
- Persistence mechanisms:
  - Crontab modifications
  - SSH authorized_keys tampering
  - New systemd services
  - Kernel module loading (rootkits)
- User/group modifications (useradd, usermod, passwd)
- Suspicious downloads to /tmp, /dev/shm, /var/tmp
- Sensitive file reads by non-root (/etc/shadow, SSL keys)
- Base64 encoding (common obfuscation technique)
- Modified system binaries or configs (AIDE)

**Key Files Created:**
- `/usr/local/bin/hids-filewatcher.sh` - File watcher daemon
- `/usr/local/bin/falco-ntfy.sh` - Falco → ntfy forwarder
- `/usr/local/bin/aide-check-ntfy.sh` - AIDE → ntfy alerter
- `/etc/systemd/system/hids-filewatcher.service` - File watcher service
- `/etc/falco/rules.d/competition.yaml` - 12 custom Falco rules
- `/etc/falco/config.d/competition.yaml` - Falco output configuration
- `/etc/aide/aide.conf.d/90_competition` - AIDE monitoring rules
- `/etc/cron.d/aide-competition` - AIDE cron job (every 10 min)
- `/var/log/falco/events.log` - Falco event log (JSON)
- `/var/log/aide-check.log` - AIDE scan results

**Services Created:**
- `hids-filewatcher.service` - Real-time file monitoring
- `falco.service` or `falco-modern-bpf.service` - Falco runtime detection

**Monitoring Commands:**
```bash
# Watch Falco detections live
tail -f /var/log/falco/events.log

# Check service status
systemctl status hids-filewatcher falco

# View service logs
journalctl -u falco -f
journalctl -u hids-filewatcher -f

# Manual AIDE check
/usr/local/bin/aide-check-ntfy.sh

# Rebuild AIDE baseline after intentional changes
aideinit && cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

**Resource Usage:**
- inotifywait: ~5 MB RAM
- Falco: 100-512 MB RAM, 1-5% CPU
- AIDE: 0 MB (between scans), ~1-5 min per scan

**Before Competition:**
1. Install ntfy app on all team phones
2. Subscribe to your ntfy topic
3. Test: `curl -d "test" https://ntfy.sh/your-topic`
4. Filter noise: Use `?priority=high,urgent` subscription filter

---

## [@gravwell_setup.sh](./@gravwell_setup.sh)
**Centralized Logging to Gravwell (Optional)**

Installs and configures Gravwell File Follower to send logs from this host to a central Gravwell indexer. Run AFTER deploying script 07 (log monitoring).

**What it ingests:**
- `tag=falco` - Falco runtime detection events
- `tag=auth` - SSH/authentication logs
- `tag=syslog` - System logs
- `tag=aide` - AIDE file integrity checks
- `tag=kern` - Kernel logs
- `tag=cron` - Cron logs

**Usage:**
```bash
# Interactive (prompts for Gravwell host/secret):
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/@gravwell_setup.sh | sudo bash

# Non-interactive:
GRAVWELL_HOST=10.0.0.5 GRAVWELL_SECRET=MySecret curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/@gravwell_setup.sh | sudo bash
```

**Key Files Created:**
- `/opt/gravwell/etc/file_follow.conf` - Gravwell ingester configuration

**Services:**
- `gravwell_file_follow.service` - Gravwell File Follower ingester

**Useful Gravwell Queries:**
```
# High-severity Falco alerts
tag=falco json priority rule output | grep -e priority "Critical" "Error" | table

# AIDE file changes
tag=aide grep -e "Added" "Removed" "Changed" | table

# SSH login attempts
tag=auth grep -e "Failed password" "Accepted publickey" | table

# Timeline of all security events
tag=falco,auth,aide count by time | chart count

# Failed SSH by source IP
tag=auth grep "Failed password" | regex "from (?P<ip>\S+)" | count by ip | table
```

**Network Requirements:**
- Gravwell indexer must be reachable on port 4023 (cleartext) or 4024 (TLS)
- No firewall blocking between host and Gravwell server
