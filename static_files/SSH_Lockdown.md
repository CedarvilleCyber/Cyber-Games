# SSH Lockdown Playbook

## Quick Reference

### Generate the paste-ready one-liner (run on your laptop)

```bash
echo "echo '$(base64 < scripts/ssh_lockdown_standalone.sh)' | base64 -d | sudo bash"
```

This outputs a single line you copy-paste into each Proxmox console. Run it every time you update `ssh_lockdown_standalone.sh` to get a fresh payload.

### On each VM (via Proxmox console)

1. Log in as root
2. Paste the one-liner from above
3. Done — box is locked in ~5 seconds

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
| 12 | Security audit — flags UID 0 accounts, removes SUID files from `/tmp`/`/var/tmp`/`/dev/shm`, prints listening ports |

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
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/ssh_lockdown_standalone.sh | sudo bash
```

### Files

| File | Purpose |
|------|---------|
| `scripts/ssh_lockdown_standalone.sh` | Self-contained — all keys/users embedded, no file dependencies |
