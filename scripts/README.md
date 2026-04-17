# [scripts](.)

Scripts for hardening and auditing Linux machines during NCAE cyber competitions.

## Table of Contents

### Core Competition Scripts (run in order)
- [01_ssh_lockdown.sh](#01_ssh_lockdownsh) - SSH hardening, backdoor removal, key deployment, user cleanup, temp purge
- [02_fail2ban_deploy.sh](#02_fail2ban_deploysh) - Brute force protection
- [03_audit.sh](#03_auditsh) - Service lockdown, full security audit

### Optional Scripts (@ prefix = run anytime)
- [@gravwell_setup.sh](#gravwell_setupsh) - Centralized logging to Gravwell

### Utility Scripts
- [backups.sh](#backupssh) - Local and remote backups of important directories

---

## [01_ssh_lockdown.sh](./01_ssh_lockdown.sh)

Full SSH hardening — run first and fast on competition images.

**What it does:**
1. Creates `blueteam` user, sets passwords (prompted or auto-generated)
2. Backs up and replaces `sshd_config` with hardened version (no password auth, ciphers restricted, AllowUsers enforced)
3. Locks down file permissions (`/etc/passwd`, `/etc/shadow`, `/etc/ssh/sshd_config`, `/etc/sudoers`)
4. Cleans sudoers — only root + sudo group, disables `/etc/sudoers.d/`
5. Removes non-protected users from sudo group
6. Deploys scoring key to all scoring users and team keys to blueteam
7. Kills non-protected SSH sessions, reverse shells, and processes with deleted executables
8. **Deletes non-protected user accounts** and their home directories
9. Purges `/tmp`, `/var/tmp`, `/dev/shm` (removes dropped payloads)
10. Disables `sshd_config.d` override files
11. Restarts sshd
12. Validates sshd config

**Configuration:** Edit the `TEAM_KEYS`, `SCORING_USERS`, `PROTECTED_USERS`, and `ALLOWED_USERS` arrays at the top of the script before running.

---

## [02_fail2ban_deploy.sh](./02_fail2ban_deploy.sh)

Installs and configures fail2ban for SSH brute-force protection.

**What it does:**
- Installs fail2ban via apt/dnf/yum
- Writes `/etc/fail2ban/jail.local` with SSH jail (3 attempts, 1h ban)
- Enables and starts fail2ban service

**Note:** Assumes `/var/log/auth.log` (Debian path). On RHEL systems the log path is `/var/log/secure` — edit the config if needed.

---

## [03_audit.sh](./03_audit.sh)

Disables unnecessary services and scans for threats. Output is color-coded: **red** = critical/suspicious, **yellow** = warning/review, **gray** = clean/noise.

**Lockdown actions (silent):**
- Disables unnecessary services (cups, bluetooth, avahi, nfs, etc.)
- Secures shared memory (`/run/shm` noexec,nosuid in fstab)
- Removes SUID binaries from `/tmp`, `/var/tmp`, `/dev/shm`

**Audit checks (printed):**
- Suspicious services (unusual paths or names)
- Non-root UID 0 accounts
- SUID/SGID binaries (temp dirs removed, `/opt` flagged for review, system-wide scan flags unusual locations)
- PwnKit check (pkexec SUID)
- Unusual listening ports
- xinetd services
- Crontabs (suspicious patterns in system cron, **any** user/root crontab entries highlighted since nothing should exist during comp)
- Systemd timers (suspicious paths or commands)
- Shell profiles for backdoor aliases (nc, socat, /dev/tcp, curl|sh, etc.)
- Scored services (running vs down)
- World-writable directories (outside /tmp, /var/tmp, /dev/shm)
- Recently modified system files (24h)
- Suspicious processes (reverse shells, netcat, etc.)
- Active network connections
- Recent authentication failures

**Configuration:** Edit the `SCORED_SERVICES` array at the top of the script to match your competition's scored services.

---

## [@gravwell_setup.sh](./@gravwell_setup.sh)

**Centralized Logging to Gravwell (Optional)**

Installs and configures Gravwell File Follower to send logs from this host to a central Gravwell indexer.

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

---

## [backups.sh](./backups.sh)

Performs both local and remote backups of important directories.

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