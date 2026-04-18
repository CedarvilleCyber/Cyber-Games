# [scripts](.)

Scripts for hardening and auditing Linux machines during NCAE cyber competitions.

## Quick Start

```bash
git clone https://github.com/CedarvilleCyber/Cyber-Games.git && cd Cyber-Games && bash tools/setup.sh
```

Clones the repo and downloads open-source tools (pspy64, linpeas, lynis, restic). Then run scripts from `scripts/`.

## Table of Contents

### Core Competition Scripts (run in order)
- [01_ssh_lockdown.sh](#01_ssh_lockdownsh) - SSH hardening, backdoor removal, key deployment, user cleanup
- [02_fail2ban_deploy.sh](#02_fail2ban_deploysh) - Brute force protection
- [03_audit.sh](#03_auditsh) - Service lockdown, full security audit

### Optional Scripts (@ prefix = run anytime)
- [@dn_install.sh](#dn_installsh) - defined.net dnclient one-step install & enroll
- [@dn_enroll.sh](#dn_enrollsh) - defined.net CTF mass host enrollment
- [@doctor.sh](#doctorsh) - Service diagnostics (why is it down?)
- [@fruit.sh](#fruitsh) - Service config misconfiguration audit
- [@gravwell_setup.sh](#gravwell_setupsh) - Centralized logging to Gravwell
- [@init_overview.sh](#init_overviewsh) - Initial machine cleanup (crontabs, immutability, /tmp)
- [@ftp_setup.sh](#ftp_setupsh) - FTP server setup for scoring
- [@smb_setup.sh](#smb_setupsh) - SMB server setup for scoring
- [@monitor.sh](#monitorsh) - Periodic connection and user check
- [@watchdog.sh](#watchdogsh) - tmux monitoring dashboard

### Utility Scripts
- [backups.sh](#backupssh) - Local and remote backups

---

## [01_ssh_lockdown.sh](./01_ssh_lockdown.sh)

Full SSH hardening — run first and fast on competition images.

1. Creates `blueteam` user, sets passwords (prompted or auto-generated)
2. Replaces `sshd_config` with hardened version (no password auth, AllowUsers enforced)
3. Locks down file permissions, cleans sudoers
4. Deploys scoring key + team keys
5. Kills non-protected sessions, reverse shells, deleted-exe processes
6. Deletes non-protected user accounts and home dirs
7. Purges `/tmp`, `/var/tmp`, `/dev/shm`
8. Disables `sshd_config.d`, restarts sshd

**Config:** Edit `TEAM_KEYS`, `SCORING_USERS`, `PROTECTED_USERS`, `ALLOWED_USERS` arrays before running.

---

## [02_fail2ban_deploy.sh](./02_fail2ban_deploy.sh)

Installs fail2ban with SSH jail (3 attempts, 1h ban). RHEL users: change log path to `/var/log/secure`.

---

## [03_audit.sh](./03_audit.sh)

Disables unnecessary services and scans for threats. **red** = critical, **yellow** = warning, **gray** = clean.

**Silent lockdown:** disables cups/bluetooth/avahi/nfs/etc., secures `/run/shm`, removes SUID from temp dirs.

**Audit checks:** suspicious services, UID 0 accounts, user shells, nologin binary integrity, system accounts with passwords, `/etc/hosts` hijacking, binary integrity (debsums/dpkg-V/rpm-Va), ld.so.preload, ELF in staging dirs, kernel modules, listening ports, hidden ports (rootkit detection), firewall NAT hijacking, xinetd, crontabs, at jobs, systemd timers, shell profiles, SUID/SGID (known-good whitelist), PwnKit, capabilities, sudoers NOPASSWD, PAM pam_exec, sshd_config directives, SSH keys, immutable files, scored services, world-writable dirs, recently modified binaries, suspicious processes, deleted executables, auth failures. Numbered findings summary at end.

**Config:** Edit `SCORED_SERVICES` and `KNOWN_SUID` arrays.

---

## [@dn_install.sh](./@dn_install.sh)

One-step defined.net dnclient install + enroll.

```bash
sudo ./dn_install.sh <ENROLL_CODE>
# Custom dir: DN_INSTALL_DIR=/opt/dn sudo ./dn_install.sh <CODE>
```

---

## [@dn_enroll.sh](./@dn_enroll.sh)

Mass host enrollment via defined.net API. Prints enrollment one-liner for each host.

```bash
DN_API_KEY=xxx ./dn_enroll.sh kali-1 kali-2 ubuntu-target
```

Defaults: `DN_NETWORK_ID=network-JC2XSVID2IICN3ZZXYZ3JOW65E`, `DN_ROLE_ID=role-5JSB3SLU2BJIOGYP3KP6APTJQM`

---

## [@doctor.sh](./@doctor.sh)

*Adapted from [DSU-DefSec/cyber](https://github.com/DSU-DefSec/cyber)*

Service diagnostics — why is it down? Checks running status, config syntax, listening address, and scans journal logs for common failures (port conflicts, permission denied, syntax errors, segfaults, OOM, TLS errors).

**Supports:** Apache, Nginx, OpenSSH, PostgreSQL, MySQL/MariaDB, vsftpd, Samba, BIND DNS

```bash
sudo ./doctor.sh
```

---

## [@fruit.sh](./@fruit.sh)

*Adapted from [DSU-DefSec/cyber](https://github.com/DSU-DefSec/cyber)*

Service config audit — scans for vulnerable misconfigurations with severity ratings and fix suggestions.

**Services:** apache2, nginx, openssh, vsftpd, samba, bind, postgres, mysql, php, cron, sudoers

```bash
sudo ./fruit.sh              # all services
sudo ./fruit.sh openssh samba  # specific services
```

---

## [@watchdog.sh](./@watchdog.sh)

tmux monitoring dashboard — filters localhost noise.

- **Top-left:** Process monitor (pspy64 or find-based)
- **Top-right:** Network (non-loopback listening + established)
- **Bottom-left:** Auth log (Failed/Accepted/sudo/useradd only)
- **Bottom-right:** Users + non-loopback listening ports
- **Window 2:** Audit re-runs every 15 min
- **Window 3:** Shell

**Keybinds** (all prefix-less, no Ctrl+b):
| Key | Action |
|-----|--------|
| Alt+Arrow / Alt+hjkl | Switch panes |
| Alt+1/2/3 | Switch windows |
| Shift+Left/Right | Prev/next window |
| Alt+z | Zoom/unzoom pane |
| Alt+q | Kill session and exit |
| Ctrl+Alt+Arrow | Resize panes |
| Alt+d | Detach |
| Mouse | Click, scroll, drag borders |

```bash
sudo ./watchdog.sh    # reattach if already running
```

Requires: `bash tools/setup.sh` for pspy64.

---

## [@gravwell_setup.sh](./@gravwell_setup.sh)

Centralized logging to Gravwell. Sends falco, auth, syslog, aide, kern, cron logs.

```bash
# Interactive:
sudo ./gravwell_setup.sh

# Non-interactive:
GRAVWELL_HOST=10.0.0.5 GRAVWELL_SECRET=secret sudo ./gravwell_setup.sh
```

---

## [@init_overview.sh](./@init_overview.sh)

Initial machine cleanup. Clears `/tmp`, removes `ld.so.preload`, removes immutable flags, changes current user shell to `/bin/bash`, nukes all crontabs and masks cron.

**Warning:** Deletes all cron jobs and masks cron. Make sure no scored services depend on cron.

---

## [@ftp_setup.sh](./@ftp_setup.sh)

FTP scoring setup — creates scoring group/directory, configures vsftpd (no anonymous, chroot, userlist).

**Config:** Edit `SCORING_USERS` and `SCORING_DIRECTORY`.

---

## [@smb_setup.sh](./@smb_setup.sh)

SMB scoring setup — creates scoring group/directory, configures smbd (SMB3, encrypted, no guest).

**Config:** Edit `SCORING_USERS`, `SCORING_PASSWORDS`, `SCORING_DIRECTORY`.

---

## [@monitor.sh](./@monitor.sh)

Simple loop — shows `w` and `ss -tulnp` every 2 seconds.

---

## [backups.sh](./backups.sh)

Local and remote backups of `/etc`, `/home`, `/var/log`, `/lib/systemd`, `/usr/bin`, `/usr/sbin`. Must run as root.
