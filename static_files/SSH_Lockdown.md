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
| 1 | Backs up current `sshd_config` |
| 2 | Writes hardened `sshd_config` (pubkey-only, no root login, no password auth, no forwarding, `AllowUsers` whitelist) |
| 3 | Sudoers cleanup — replaces `/etc/sudoers` (root + sudo/wheel only), disables `/etc/sudoers.d/*`, strips non-protected users from sudo/wheel group |
| 4 | Nukes `.ssh/` for all non-protected users, removes `authorized_keys2` everywhere |
| 5 | Deploys scoring key to scoring users, Kieran's key to `blueteam` |
| 6 | Kills all SSH sessions from non-protected users |
| 7 | Locks non-protected accounts (`passwd -l` + shell → `/sbin/nologin`) |
| 8 | Disables all `sshd_config.d/*.conf` overrides |
| 9 | Restarts sshd |
| 10 | Validates config syntax and prints status |

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
