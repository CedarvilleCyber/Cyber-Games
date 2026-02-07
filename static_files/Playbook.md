# Competition Playbook

## Quick Reference

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

### After internet is up

Alternative — pull and run directly from GitHub:

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/01_ssh_lockdown.sh | sudo bash
```

**Remember**: Take a snapshot immediately after the script completes.

## After Internet Access - Additional Hardening

Once internet is available, run additional hardening scripts in sequence:

### Rapid Deployment

```bash
# Download and run all critical hardening scripts
scripts=(02_fail2ban_deploy 03_kernel_hardening 04_firewall_lockdown 05_service_audit)
for script in "${scripts[@]}"; do
    curl -sSL "https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/${script}.sh" | sudo bash
done
```

### Individual Scripts

**Fail2ban (blocks attackers automatically)**:
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/02_fail2ban_deploy.sh | sudo bash
```

**Kernel hardening (sysctl security settings)**:
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/03_kernel_hardening.sh | sudo bash
```

**Firewall lockdown (UFW/firewalld)**:
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/04_firewall_lockdown.sh | sudo bash
```

**Service audit (disable unnecessary services)**:
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/05_service_audit.sh | sudo bash
```

### Optional Enhancements (time permitting)

**File integrity monitoring**:
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/06_file_integrity.sh | sudo bash
```

**Local security monitoring**:
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/07_log_monitoring.sh | sudo bash
```

**Web server hardening**:
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/08_web_hardening.sh | sudo bash
```

**Database hardening**:
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/09_database_hardening.sh | sudo bash
```

**Final security audit**:
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/10_final_audit.sh | sudo bash
```

## Competition Strategy

### Timeline
- **T+0:00**: SSH lockdown on all machines (Proxmox console)
- **T+0:05**: Take snapshots, verify SSH access works
- **T+0:10**: Deploy fail2ban + kernel hardening once internet is up
- **T+0:20**: Firewall + service audit on critical machines
- **T+0:30+**: Additional hardening scripts as time allows

### Priority Order
1. **Web servers** - highest attack target
2. **Database servers** - contain sensitive data  
3. **DNS servers** - critical infrastructure
4. **Other services** - as time allows

### Team Coordination
- Person 1: Web servers
- Person 2: Database servers
- Person 3: DNS/infrastructure
- Person 4: Monitor scoreboard, coordinate fixes
- Person 5: Run enhancement scripts (06-10) on stable servers

## Troubleshooting

### SSH Lockout Recovery

If script 01 locks you out:

1. Use Proxmox console access
2. Fix SSH config:
   ```bash
   nano /etc/ssh/sshd_config
   # Add your username to AllowUsers line
   systemctl restart sshd
   ```

### Service Down Recovery

If additional scripts break scored services:

1. Check what broke:
   ```bash
   systemctl status SERVICE_NAME
   tail -f /var/log/syslog
   ```

2. Revert recent changes:
   ```bash
   # Scripts create .backup files
   cp /etc/service/config.backup /etc/service/config
   systemctl restart SERVICE_NAME
   ```

3. Or restore from snapshot

### Firewall Issues

If firewall blocks scored services:

```bash
# Check what's listening
ss -tulpn | grep LISTEN

# Allow specific ports
ufw allow PORT/tcp comment 'SERVICE_NAME'

# Check firewall status
ufw status verbose
```

## Essential Commands

### Monitoring
```bash
# Real-time system monitoring
htop

# Network connections
ss -tulpn | grep LISTEN

# Recent authentication events  
tail -f /var/log/auth.log

# System logs
journalctl -f
```

### Security Checks
```bash
# Active sessions
w

# Recent logins
last

# Failed login attempts
grep "Failed password" /var/log/auth.log | tail -10

# Listening services
systemctl list-units --type=service --state=running
```

### Quick Fixes
```bash
# Restart SSH safely
systemctl restart sshd

# Reload firewall
ufw reload

# Check service status
systemctl status SERVICE_NAME

# View service logs
journalctl -u SERVICE_NAME -f
```

### Files

| File | Purpose |
|------|---------|
| `scripts/01_ssh_lockdown.sh` | Self-contained — all keys/users embedded, no file dependencies |
| `scripts/02_fail2ban_deploy.sh` | Automated intrusion prevention |
| `scripts/03_kernel_hardening.sh` | Kernel security settings |
| `scripts/04_firewall_lockdown.sh` | Network security |
| `scripts/05_service_audit.sh` | Service management |
| `scripts/06-10_*.sh` | Additional hardening enhancements |
