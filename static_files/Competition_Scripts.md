# Competition Security Scripts

Numbered sequence of security hardening scripts for NCAE cyber competitions. Deploy in order after gaining internet access.

## Deployment Sequence

### T+0:00 - Immediate Lockdown (Proxmox Console)
**01 - SSH Lockdown** (No internet required)
```bash
# Generate base64 payload on your laptop:
echo "echo '$(base64 < scripts/01_ssh_lockdown.sh)' | base64 -d | sudo bash"

# Or with internet access:
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/01_ssh_lockdown.sh | sudo bash
```

**Critical**: Take VM snapshot immediately after completion.

---

### T+0:05 - Network Security (Internet Required)

**02 - Fail2ban Deployment**
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/02_fail2ban_deploy.sh | sudo bash
```

**03 - Kernel Hardening**
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/03_kernel_hardening.sh | sudo bash
```

**04 - Firewall Lockdown**
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/04_firewall_lockdown.sh | sudo bash
```

---

### T+0:15 - Service Security

**05 - Service Audit**
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/05_service_audit.sh | sudo bash
```

**06 - File Integrity Monitoring**
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/06_file_integrity.sh | sudo bash
```

**07 - Log Monitoring Setup**
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/07_log_monitoring.sh | sudo bash
```

---

### T+0:30 - Application Security

**08 - Web Server Hardening**
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/08_web_hardening.sh | sudo bash
```

**09 - Database Hardening**
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/09_database_hardening.sh | sudo bash
```

---

### T+1:00 - Final Verification

**10 - Final Security Audit**
```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/10_final_audit.sh | sudo bash
```

---

## Quick Deployment

### All-in-one deployment (after SSH lockdown):
```bash
# Download all scripts
mkdir -p /tmp/security-scripts && cd /tmp/security-scripts
for i in {02..10}; do
    curl -sSL "https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/${i}*.sh" -o "${i}.sh"
    chmod +x "${i}.sh"
done

# Run in sequence (review each before proceeding)
for script in *.sh; do
    echo "Running $script..."
    sudo ./"$script"
    read -p "Continue to next script? (y/n): " confirm
    [[ "$confirm" != "y" ]] && break
done
```

### Rapid deployment (minimal prompts):
```bash
# For experienced users - runs all scripts with minimal interaction
scripts=(02_fail2ban_deploy 03_kernel_hardening 04_firewall_lockdown 05_service_audit)
for script in "${scripts[@]}"; do
    curl -sSL "https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/${script}.sh" | sudo bash
done
```

---

## Script Details

| Script | Purpose | Time | Critical |
|--------|---------|------|----------|
| 01 | SSH lockdown, kill shells, deploy keys | 30s | YES |
| 02 | Install fail2ban, auto-ban attackers | 2min | YES |
| 03 | Kernel security settings, disable protocols | 1min | YES |
| 04 | Configure firewall, block unnecessary ports | 3min | YES |
| 05 | Audit services, disable unnecessary ones | 2min | YES |
| 06 | Install AIDE file integrity monitoring | 5min | NO |
| 07 | Set up centralized logging and alerts | 3min | NO |
| 08 | Harden web servers, scan for shells | 4min | NO |
| 09 | Secure databases, change passwords | 5min | NO |
| 10 | Comprehensive security audit and scan | 3min | NO |

---

## Team Strategy

### Role Assignment
- **Person 1**: Run scripts 01-04 on Linux web servers
- **Person 2**: Run scripts 01-04 on Linux DNS/database servers  
- **Person 3**: Handle Windows machines (separate playbook)
- **Person 4**: Monitor scoreboard, coordinate fixes
- **Person 5**: Run scripts 05-10 on critical servers after initial lockdown

### Timing
- **0-5 minutes**: Script 01 on ALL Linux machines simultaneously
- **5-15 minutes**: Scripts 02-04 on servers by priority (web first, then DB, then others)
- **15-60 minutes**: Scripts 05-10 on stable servers while monitoring scores

### Recovery
- VM snapshots after script 01 and script 04
- If services go red, revert snapshot and identify the breaking script
- Use scoreboard feedback to adjust firewall rules in script 04

---

## Troubleshooting

### Common Issues

**Script 01 locks you out**:
- Use Proxmox console access to fix `/etc/ssh/sshd_config`
- Check that your username is in the `AllowUsers` line

**Script 04 breaks scored services**:
- Check what ports your services need: `ss -tulpn | grep LISTEN`
- Add firewall rules: `ufw allow PORT/tcp`

**Scripts 08/09 break web/database**:
- Check application logs in `/var/log/`
- Revert config backups created by scripts

### Emergency Commands
```bash
# Check service status
systemctl status SERVICE_NAME

# Check firewall
ufw status verbose

# Check listening ports
ss -tulpn | grep LISTEN

# Check recent changes
find /etc -mtime -1 -ls

# Revert configs (scripts create .backup files)
cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
systemctl restart sshd
```

---

## Competition Notes

- Scripts are designed for Ubuntu/Debian and RHEL/CentOS
- Each script checks for prerequisites and handles errors gracefully
- All scripts log their actions for audit trails
- Scripts can be run multiple times safely (idempotent where possible)
- Focus on scripts 01-04 first - these provide 80% of the security value
- Scripts 05-10 are enhancements for when you have extra time

**Remember**: The goal is working scored services that are hardened against attack, not perfect security at the cost of functionality.