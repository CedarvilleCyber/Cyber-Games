# Competition Playbook

## SSH Lockdown Quick Setup

### Generate the paste-ready one-liner (run on your laptop)

```bash
echo "echo '$(base64 < scripts/01_ssh_lockdown.sh)' | base64 -d | sudo bash"
```

This outputs a single line you copy-paste into each Proxmox console. Run it every time you update `01_ssh_lockdown.sh` to get a fresh payload.

### On each VM (via Proxmox console)

1. Log in as root
2. Paste the one-liner from above
3. **TAKE A SNAPSHOT** — critical for quick recovery if red team breaks something
4. Done — box is locked in ~5 seconds

### What the lockdown does

| Step | Action |
|------|--------|
| 1 | **Prompts for root & blueteam passwords** (typed into Proxmox console — never stored in script), creates `blueteam` user if missing, adds to sudo/wheel |
| 2 | Backs up current `sshd_config` |
| 3 | Writes hardened `sshd_config` (pubkey-only, no root login, no password auth, no forwarding, `AllowUsers` whitelist, restricted ciphers/MACs/kex, rate limiting). Locks down critical file permissions (`/etc/passwd` 644, `/etc/shadow` 640, `/etc/group` 644, `sshd_config` 600, `/etc/sudoers` 600) |
| 4 | Sudoers cleanup — replaces `/etc/sudoers` (root + sudo/wheel only), disables `/etc/sudoers.d/*`, strips non-protected users from sudo/wheel group |
| 5 | Nukes `.ssh/` for all non-protected users, removes `authorized_keys2` everywhere, removes planted private keys (skips protected users) |
| 6 | Deploys scoring key to scoring users, Kieran's key to `blueteam` |
| 7 | Kills non-protected SSH sessions, reverse shells (`nc`, `ncat`, `/dev/tcp`, `socat`, etc.), and processes running from deleted executables |
| 8 | Locks non-protected accounts (`passwd -l` + shell → `/sbin/nologin`) |
| 9 | Disables all `sshd_config.d/*.conf` overrides |
| 10 | Restarts sshd |
| 11 | Validates config syntax and prints status |
| 12 | Security audit — flags UID 0 accounts, removes SUID files from `/tmp`/`/var/tmp`/`/dev/shm`/`/opt`, prints listening ports, lists all aliases and functions for manual review |

### Protected users (never killed/locked)

- `blackteam` — competition infrastructure
- `blueteam` — our operational user
- `root` — kept for local console access (SSH login still denied by `PermitRootLogin no`)
- All 24 scoring users from the scoring list

### Adding users before comp

Edit the `ALLOWED_USERS` array in `scripts/ssh_lockdown_standalone.sh`:

```bash
ALLOWED_USERS=(
    "alice"
    "bob"
)
```

Then re-run the generator one-liner on your laptop to get an updated payload.

## After Internet Access - Command Reference

**Script 01 - SSH Lockdown** - Complete system hardening, kill backdoors, deploy keys
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/01_ssh_lockdown.sh | sudo bash
```

**Script 02 - Fail2ban** - Auto-ban brute force attackers, essential first defense
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/02_fail2ban_deploy.sh | sudo bash
```

**Script 03 - Kernel Hardening** - Disable dangerous protocols, prevent network exploits
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/03_kernel_hardening.sh | sudo bash
```

**Script 04 - Firewall** - Block unnecessary ports, monitor scoreboard closely after
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/04_firewall_lockdown.sh | sudo bash
```

**Script 05 - Service Audit** - Disable unnecessary services, reduce attack surface
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/05_service_audit.sh | sudo bash
```

**Script 06 - File Integrity** - Monitor system files for unauthorized changes
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/06_file_integrity.sh | sudo bash
```

**Script 07 - HIDS & Intrusion Detection** - Falco runtime detection + AIDE + instant ntfy alerts
```bash
# Prompts for ntfy topic, or set with: NTFY_TOPIC=blueteam-alerts
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/07_log_monitoring.sh | sudo bash
```

**Script 08 - Web Hardening** - Secure Apache/Nginx, scan for web shells (web servers only)
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/08_web_hardening.sh | sudo bash
```

**Script 09 - Database Hardening** - Secure MySQL/PostgreSQL, change passwords (DB servers only)
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/09_database_hardening.sh | sudo bash
```

**Script 10 - Final Audit** - Comprehensive security scan and vulnerability assessment
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/10_final_audit.sh | sudo bash
```

## Optional Scripts (@ prefix = run anytime)

**@gravwell_setup** - Add centralized logging to Gravwell (run AFTER script 07)
```bash
# Prompts for Gravwell host/secret, or set with: GRAVWELL_HOST=10.0.0.5 GRAVWELL_SECRET=secret
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/@gravwell_setup.sh | sudo bash
```

## Script 07 - HIDS Details

**What it deploys:**
- **inotifywait file watcher** - Instant ntfy alerts on changes to `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, SSH configs, cron files, systemd services
- **Falco runtime detection** - eBPF-based behavioral monitoring with 12 competition rules:
  - Reverse shells, webshells, bind shells
  - Attacker tools (nmap, hydra, sqlmap, linpeas, etc.)
  - Persistence mechanisms (cron, systemd, SSH keys)
  - User/group modifications
  - Suspicious downloads to `/tmp`
  - Kernel module loading (rootkit indicator)
  - Sensitive file reads by non-root
  - Base64 encoding (obfuscation)
- **AIDE file integrity** - Periodic scans every 10 minutes, monitors system binaries, configs, web roots

**Deployment time:** ~5 minutes (AIDE baseline builds in background)

**Before competition:**
1. Subscribe all team phones to ntfy topic: Install ntfy app → subscribe to your topic
2. Test alerts: `curl -d "test alert" https://ntfy.sh/your-topic`
3. Filter noise: Subscribe with `?priority=high,urgent` to only see critical alerts

**During competition:**
```bash
# Quick status checks
systemctl status hids-filewatcher falco
tail -f /var/log/falco/events.log     # Watch Falco detections in real-time
journalctl -u falco -f                 # Falco service logs

# Manual AIDE check
/usr/local/bin/aide-check-ntfy.sh

# Rebuild AIDE baseline after intentional changes
aideinit && cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

**Alert examples you'll receive:**
- `⚠ File Change on webserver1: MODIFY: /etc/passwd`
- `🚨 Falco [db-server]: Shell Spawned from Web Server`
- `🔍 AIDE Alert [app-server]: Changed files: /usr/bin/ps, /etc/crontab`

## SSH Lockdown Priority Tasks

Run scripts 01-05 first - they provide the core security foundation.

## Emergency Recovery

### SSH Lockout Recovery
1. Use Proxmox console access
2. Fix SSH config: `nano /etc/ssh/sshd_config`
3. Add your username to `AllowUsers` line
4. Restart: `systemctl restart sshd`

### Service Down Recovery
1. Check what broke: `systemctl status SERVICE_NAME`
2. Check logs: `tail -f /var/log/syslog`
3. Revert configs: `cp /etc/service/config.backup /etc/service/config`
4. Restart service: `systemctl restart SERVICE_NAME`
5. Or restore from snapshot

### Firewall Issues
```bash
# Check what's listening
ss -tulpn | grep LISTEN

# Allow specific ports
ufw allow PORT/tcp comment 'SERVICE_NAME'

# Check firewall status
ufw status verbose
```

## Essential Monitoring Commands

```bash
# Real-time monitoring
htop
ss -tulpn | grep LISTEN
tail -f /var/log/auth.log
journalctl -f

# HIDS monitoring (if script 07 deployed)
tail -f /var/log/falco/events.log              # Falco detections
journalctl -u falco -f                         # Falco service logs
journalctl -u hids-filewatcher -f              # File watcher status
systemctl status falco hids-filewatcher        # Check HIDS services
/usr/local/bin/aide-check-ntfy.sh              # Manual AIDE scan

# Security checks
w                    # Active sessions
last                 # Recent logins
systemctl list-units --type=service --state=running

# Quick service management
systemctl restart sshd
systemctl status SERVICE_NAME
journalctl -u SERVICE_NAME -f
```
