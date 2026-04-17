# [scripts](.)

Scripts for hardening and auditing Linux machines during NCAE cyber competitions.

## Table of Contents

### Core Competition Scripts (run in order)
- [01_ssh_lockdown.sh](#01_ssh_lockdownsh) - SSH hardening, backdoor removal, key deployment, user cleanup, temp purge
- [02_fail2ban_deploy.sh](#02_fail2ban_deploysh) - Brute force protection
- [03_audit.sh](#03_auditsh) - Service lockdown, full security audit

### Optional Scripts (@ prefix = run anytime)
- [@dn_install.sh](#dn_installsh) - defined.net dnclient one-step install & enroll
- [@dn_enroll.sh](#dn_enrollsh) - defined.net CTF mass host enrollment
- [@gravwell_setup.sh](#gravwell_setupsh) - Centralized logging to Gravwell
- [@init_overview.sh](#init_overviewsh) - Initial machine cleaning (crontabs, immutability, /tmp)
- [@ftp_setup.sh](#ftp_setupsh) - FTP server setup for scoring
- [@smb_setup.sh](#smb_setupsh) - SMB server setup for scoring
- [@monitor.sh](#monitor.sh) - Simple script to periodically check active connections and users

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
- User default shells (flags nonstandard shells)
- nologin/false binary integrity (shell strings inside binary, missing denial strings, `/etc/shells` listing)
- System accounts with passwords
- `/etc/hosts` hijacking (non-loopback entries)
- Binary integrity (`debsums`/`dpkg -V`/`rpm -Va` checksums)
- `ld.so.preload` and `ld.so.conf.d` suspicious paths, `LD_PRELOAD` env var
- ELF binaries in staging directories (`/tmp`, `/dev/shm`, `/var/tmp`)
- Kernel modules from unusual paths
- Listening ports (with process binary)
- Hidden ports (`/proc/net/tcp` vs `ss` mismatch — rootkit detection)
- Firewall NAT hijacking (nftables/iptables DNAT/REDIRECT)
- xinetd services
- Crontabs (suspicious patterns in system cron, **any** user/root crontab entries highlighted since nothing should exist during comp)
- `at` jobs
- Systemd timers (suspicious paths or commands)
- Shell profiles for backdoor aliases (nc, socat, /dev/tcp, curl|sh, etc.)
- SUID/SGID binaries (temp dirs removed, known-good whitelist, `/opt` flagged for review, `/home` flagged)
- PwnKit check (pkexec SUID)
- Elevated capabilities (`getcap`)
- sudoers NOPASSWD ALL
- PAM `pam_exec` (command execution on auth)
- sshd_config dangerous directives (PermitRootLogin yes, PermitEmptyPasswords yes, GatewayPorts yes, non-standard AuthorizedKeysFile)
- SSH authorized keys per user
- Immutable files (`lsattr` on critical configs)
- Scored services (running vs down)
- World-writable directories (outside /tmp, /var/tmp, /dev/shm)
- Recently modified system binaries (7 days)
- Suspicious processes (reverse shells, netcat, etc.)
- Processes with deleted executables
- Active network connections
- Recent authentication failures
- Numbered findings summary

**Configuration:** Edit the `SCORED_SERVICES` and `KNOWN_SUID` arrays at the top of the script to match your competition's scored services.

---

## [@dn_install.sh](./@dn_install.sh)

defined.net dnclient one-step install — downloads, installs, starts, and enrolls the dnclient server binary.

**What it does:**
1. Detects OS and architecture
2. Fetches the latest download URL from the defined.net API
3. Downloads the dnclient binary
4. Installs to `/usr/local/bin` (configurable via `DN_INSTALL_DIR`)
5. Installs and starts the dnclient service (auto-starts on boot)
6. Enrolls the host with the provided enrollment code

**Usage:**
```bash
sudo ./dn_install.sh ABCD-1234-EFGH-5678

# Custom install directory:
DN_INSTALL_DIR=/opt/dn sudo ./dn_install.sh ABCD-1234-EFGH-5678
```

---

## [@dn_enroll.sh](./@dn_enroll.sh)

defined.net CTF mass host enrollment — creates hosts via the defined.net API and prints one-liner enrollment commands.

**What it does:**
- For each host name argument, creates a host on the defined.net network via API
- Prints the assigned IP and enrollment command for each host
- Requires `curl` and `jq`

**Configuration:** Set `DN_API_KEY` and `DN_NETWORK_ID` environment variables (required). Optionally set `DN_ROLE_ID` to assign a role.

**Usage:**
```bash
# Enroll multiple hosts:
DN_API_KEY=xxx DN_NETWORK_ID=network-XXXXXXX ./dn_enroll.sh kali-1 kali-2 ubuntu-target

# With a role:
DN_API_KEY=xxx DN_NETWORK_ID=network-XXXXXXX DN_ROLE_ID=role-XXXXXXX ./dn_enroll.sh db-server
```

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

## [@init_overview.sh](./@init_overview.sh)

Initial machine cleanup — run first thing on a fresh image.

**What it does:**
- Clears `/tmp` and removes `/etc/ld.so.preload` (common LD_PRELOAD hijack)
- Prints OS info, active users, and connections
- Checks for tainted kernel
- Removes immutable flags from `/etc` and `/usr` (undoes `chattr +i` persistence)
- Changes default shell to `/bin/bash` for current user
- Removes all crontabs and masks the cron daemon

**Warning:** This is aggressive — it deletes all cron jobs and masks cron entirely. Make sure no scored services depend on cron.

---

## [@ftp_setup.sh](./@ftp_setup.sh)

FTP server setup for scoring — configures vsftpd with a scoring group and user whitelist.

**What it does:**
- Creates `scoring` group
- Creates scoring directory with correct permissions (setgid 2770)
- Adds scoring users to group and vsftpd userlist
- Sets scoring users' shell to `/usr/sbin/nologin` and home to the scoring directory
- Writes hardened `vsftpd.conf` (no anonymous, chroot, passive mode, userlist deny)
- Restarts vsftpd

**Configuration:** Edit `SCORING_USERS` and `SCORING_DIRECTORY` at the top of the script before running.

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
