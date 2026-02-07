# Competition Security Scripts

Numbered sequence of security hardening scripts for NCAE cyber competitions. Deploy in order after gaining internet access.

## Script 01 - SSH Lockdown (No Internet Required)

Complete SSH hardening and access control system that secures all user accounts, deploys authorized keys, kills malicious processes, and hardens system permissions in under 30 seconds. This is the most critical script - run it first on every Linux machine.

**What it does in detail:**
- Prompts for new root and blueteam passwords (never stored in script)
- Creates blueteam user if missing and adds to sudo/wheel groups
- Backs up original SSH configuration to `/etc/ssh/sshd_config.backup`
- Deploys hardened SSH config with pubkey-only auth, no root login, no password auth
- Sets AllowUsers whitelist to only scoring users + blueteam
- Configures restricted SSH ciphers, MACs, and key exchange algorithms
- Implements SSH rate limiting and connection throttling
- Hardens critical file permissions (passwd 644, shadow 640, sudoers 600)
- Replaces sudoers file with clean version (root + sudo/wheel only)
- Disables all files in `/etc/sudoers.d/` directory
- Removes non-protected users from sudo/wheel groups
- Destroys all .ssh directories for non-protected users
- Removes authorized_keys2 files and planted private keys
- Deploys competition scoring key to all scoring users
- Deploys team member keys to blueteam user
- Kills all non-protected SSH sessions and reverse shells
- Hunts for and kills processes running from deleted executables
- Locks all non-protected user accounts (passwd -l + nologin shell)
- Disables SSH config overrides in sshd_config.d
- Restarts SSH daemon with new configuration
- Performs comprehensive security audit and validation

```bash
# Generate base64 payload on your laptop:
echo "echo '$(base64 < scripts/01_ssh_lockdown.sh)' | base64 -d | sudo bash"

# Or with internet access:
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/01_ssh_lockdown.sh | sudo bash
```

**Protected users that are never touched:**
- `blackteam` — competition infrastructure account
- `blueteam` — our operational account
- `root` — system administrator (SSH blocked but console access preserved)
- All 24 scoring users from the competition list

**Key Files to Check After Running:**
- `/etc/ssh/sshd_config` - Hardened SSH configuration with AllowUsers whitelist
- `/etc/ssh/sshd_config.backup` - Original SSH config backup for recovery
- `/etc/sudoers` - Clean sudo configuration (only root + sudo/wheel groups)
- `/etc/sudoers.d/` - All files disabled with .disabled extension
- `/home/*//.ssh/authorized_keys` - Scoring and team public keys deployed
- `/var/log/auth.log` - SSH authentication attempts and results
- `/etc/passwd` - Non-protected users have /sbin/nologin shell
- `/etc/shadow` - Non-protected users have locked passwords (!)

**Helpful Commands:**
- `systemctl status sshd` - Check SSH service status and recent restarts
- `sshd -t` - Test SSH configuration file syntax for errors
- `tail -f /var/log/auth.log` - Monitor real-time SSH authentication attempts
- `w` - See current SSH sessions and login times
- `last` - Recent login history with usernames and IPs
- `grep "AllowUsers" /etc/ssh/sshd_config` - Verify user whitelist
- `getent passwd | grep nologin` - List locked user accounts
- `ps aux | grep -E "(nc|ncat|socat)"` - Check for remaining reverse shells

**Common Problems & Fixes:**
- **Locked out of SSH**: Use Proxmox console, edit `/etc/ssh/sshd_config`, add your user to `AllowUsers` line
- **SSH won't restart**: Check `sshd -t` for config errors, restore from `/etc/ssh/sshd_config.backup` if needed
- **Can't sudo as blueteam**: Verify blueteam is in sudo group: `groups blueteam`, add if missing: `usermod -aG sudo blueteam`
- **Scoring user can't login**: Check if user in AllowUsers list and authorized_keys deployed correctly
- **Root console access broken**: Root account preserved for console, never locked by script

**Expected output indicators:**
- "SSH configuration hardened successfully"
- "X users locked, Y SSH sessions killed"
- "Z reverse shell processes terminated"
- "SSH service restarted and validated"
- List of protected vs locked accounts

**Critical**: Take VM snapshot immediately after completion and verify you can SSH in before proceeding.

---

## Script 02 - Fail2ban Deployment (Internet Required)

Installs and configures fail2ban with aggressive settings to automatically detect and ban malicious IP addresses attempting brute force attacks on SSH, web services, FTP, and other protocols. Essential first line of defense against automated attacks.

**What it does in detail:**
- Detects and installs fail2ban package (apt/yum/dnf based on distro)
- Backs up original configuration files
- Creates custom jail.local with aggressive ban settings
- Configures SSH jail with 3 attempts, 1-hour ban, monitors auth.log
- Sets up HTTP/HTTPS jails monitoring Apache/Nginx error logs
- Configures FTP jail for vsftpd and proftpd services
- Sets up postfix/dovecot jails for mail server protection
- Enables recursive DNS query blocking for BIND
- Configures custom filters for common web exploits
- Sets ban time to 3600 seconds (1 hour) for first offense
- Implements progressive ban times for repeat offenders
- Configures email notifications for bans (if mail configured)
- Creates custom actions for firewall integration
- Sets up log rotation for fail2ban logs
- Starts and enables fail2ban service
- Validates all jails are active and monitoring

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/02_fail2ban_deploy.sh | sudo bash
```

**Active jails configured:**
- `sshd` - SSH brute force protection (port 22)
- `apache-auth` - Apache authentication failures  
- `apache-badbots` - Malicious bot detection
- `apache-noscript` - Script injection attempts
- `apache-overflows` - Buffer overflow attempts
- `nginx-http-auth` - Nginx authentication failures
- `nginx-limit-req` - Rate limiting violations
- `vsftpd` - FTP brute force protection
- `postfix` - Mail server abuse protection
- `dovecot` - IMAP/POP3 brute force protection

**Key Files to Check After Running:**
- `/etc/fail2ban/jail.local` - Main fail2ban configuration with custom settings
- `/var/log/fail2ban.log` - Ban/unban activity logs and service status
- `/etc/fail2ban/filter.d/` - Attack pattern definitions and regex filters
- `/etc/fail2ban/action.d/` - Ban action scripts (iptables/firewall rules)
- `/etc/fail2ban/jail.d/` - Individual jail configuration files
- `/var/lib/fail2ban/fail2ban.sqlite3` - Ban database (IP history)

**Helpful Commands:**
- `fail2ban-client status` - Show all active jails and their status
- `fail2ban-client status sshd` - Detailed SSH jail status with banned IPs
- `fail2ban-client status apache-auth` - Web server protection status
- `fail2ban-client unban IP_ADDRESS` - Manual unban of specific IP
- `fail2ban-client set sshd banip IP_ADDRESS` - Manual ban of IP
- `tail -f /var/log/fail2ban.log` - Monitor real-time ban activity
- `fail2ban-client reload` - Reload configuration without losing bans
- `iptables -L -n | grep f2b` - Show current fail2ban firewall rules
- `fail2ban-client get sshd bantime` - Check current ban time settings

**Common Problems & Fixes:**
- **Banned your own IP**: `fail2ban-client unban YOUR_IP` or restart fail2ban service
- **Service won't start**: Check `/var/log/fail2ban.log` for config syntax errors
- **Not blocking attacks**: Verify jail active with `fail2ban-client status JAIL_NAME`
- **Log file not found errors**: Check if monitored services are installed and log paths exist
- **Too many false positives**: Adjust maxretry and findtime in `/etc/fail2ban/jail.local`
- **Bans not persisting**: Check if iptables rules are being cleared by other services

**Expected output indicators:**
- "fail2ban installed and configured successfully"
- "X jails activated and monitoring"
- "Aggressive ban settings applied (1 hour ban time)"
- List of active jails and monitored log files
- "fail2ban service started and enabled"

**Monitoring after deployment:**
- Watch `/var/log/fail2ban.log` for immediate ban activity
- Verify scoring systems can still connect (whitelist if needed)
- Check that web services remain accessible to legitimate users
- Monitor iptables rules don't conflict with other firewall rules

---

## Script 03 - Kernel Hardening (T+0:07)

Applies sysctl security settings to harden the kernel against network attacks, disable unnecessary protocols, and improve system security posture. Prevents many common network-based exploits.

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/03_kernel_hardening.sh | sudo bash
```

**Key Files to Check After Running:**
- `/etc/sysctl.d/99-security.conf` - Applied security settings
- `/proc/sys/net/ipv4/ip_forward` - Should be 0 (disabled)
- `/proc/sys/net/ipv4/icmp_echo_ignore_broadcasts` - Should be 1 (enabled)

**Helpful Commands:**
- `sysctl -p` - Reload sysctl settings
- `sysctl net.ipv4.ip_forward` - Check IP forwarding status
- `sysctl -a | grep net.ipv4` - View all IPv4 kernel settings
- `cat /proc/sys/kernel/dmesg_restrict` - Check dmesg restrictions

**Common Problems & Fixes:**
- **Network connectivity issues**: Check if IP forwarding was needed, re-enable with `sysctl net.ipv4.ip_forward=1`
- **Application errors**: Some apps may need specific kernel features, check logs
- **Settings not applied**: Run `sysctl -p /etc/sysctl.d/99-security.conf`

---

## Script 04 - Firewall Lockdown (T+0:08)

Configures UFW or firewalld to block unnecessary network traffic while preserving access to scored services. This is critical but potentially disruptive - monitor the scoreboard closely after deployment.

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/04_firewall_lockdown.sh | sudo bash
```

**Key Files to Check After Running:**
- `/etc/ufw/user.rules` - UFW firewall rules
- `/etc/default/ufw` - UFW default policies
- `/var/log/ufw.log` - Blocked connection attempts

**Helpful Commands:**
- `ufw status verbose` - Show detailed firewall status
- `ss -tulpn | grep LISTEN` - Show listening services
- `ufw allow PORT/tcp comment 'SERVICE'` - Allow specific port
- `ufw delete RULE_NUMBER` - Remove firewall rule
- `tail -f /var/log/ufw.log` - Monitor blocked connections

**Common Problems & Fixes:**
- **Service goes red**: Check listening ports with `ss -tulpn`, add firewall rule: `ufw allow PORT/tcp`
- **Too restrictive**: Use `ufw status numbered` and `ufw delete NUMBER` to remove rules
- **Firewall not active**: Run `ufw enable` to activate

---

## Script 05 - Service Audit (T+0:15)

Reviews all running services and disables unnecessary ones to reduce attack surface while preserving functionality of scored services. Helps eliminate potential backdoors and reduces system resource usage.

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/05_service_audit.sh | sudo bash
```

**Key Files to Check After Running:**
- `/etc/systemd/system/` - Systemd service files
- `/var/log/syslog` - Service start/stop logs
- `/etc/init.d/` - Legacy init scripts

**Helpful Commands:**
- `systemctl list-units --type=service --state=running` - Active services
- `systemctl status SERVICE_NAME` - Check specific service
- `systemctl enable SERVICE_NAME` - Re-enable if needed
- `systemctl start SERVICE_NAME` - Start stopped service
- `journalctl -u SERVICE_NAME -f` - Monitor service logs

**Common Problems & Fixes:**
- **Scored service disabled**: `systemctl enable SERVICE_NAME && systemctl start SERVICE_NAME`
- **Dependencies broken**: Check `systemctl status SERVICE_NAME` for dependency errors
- **Service won't start**: Check logs with `journalctl -u SERVICE_NAME`

---

## Script 06 - File Integrity Monitoring (T+0:30)

Installs and configures AIDE (Advanced Intrusion Detection Environment) to monitor critical system files for unauthorized changes. Helps detect when attackers modify system files or plant backdoors.

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/06_file_integrity.sh | sudo bash
```

**Key Files to Check After Running:**
- `/etc/aide/aide.conf` - AIDE configuration file
- `/var/lib/aide/aide.db` - AIDE database of file checksums
- `/var/log/aide/aide.log` - AIDE scan results
- `/etc/cron.d/aide` - Scheduled integrity checks

**Helpful Commands:**
- `aide --check` - Manual integrity check
- `aide --update` - Update AIDE database
- `cat /var/log/aide/aide.log` - View integrity check results
- `aide --config-check` - Verify AIDE configuration

**Common Problems & Fixes:**
- **Database not initialized**: Run `aide --init` then `mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db`
- **Too many alerts**: Edit `/etc/aide/aide.conf` to exclude changing directories like `/tmp`
- **Scan taking too long**: Reduce monitored paths in configuration

---

## Script 07 - Log Monitoring Setup (T+0:35)

Sets up centralized logging and real-time log monitoring to detect suspicious activity and security events. Configures rsyslog and logwatch for better security visibility.

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/07_log_monitoring.sh | sudo bash
```

**Key Files to Check After Running:**
- `/etc/rsyslog.conf` - Centralized logging configuration
- `/etc/logwatch/conf/logwatch.conf` - Log analysis configuration
- `/var/log/security.log` - Centralized security events
- `/etc/cron.daily/logwatch` - Daily log analysis job

**Helpful Commands:**
- `logwatch --detail high --service sshd --range today` - SSH activity summary
- `tail -f /var/log/security.log` - Monitor security events
- `journalctl -f -u rsyslog` - Monitor logging service
- `logwatch --print --range today` - Daily security summary

**Common Problems & Fixes:**
- **Logs not centralizing**: Check `/etc/rsyslog.conf` syntax and restart `rsyslog`
- **Logwatch not running**: Check `/etc/cron.daily/logwatch` permissions
- **Disk space issues**: Configure log rotation in `/etc/logrotate.d/`

---

## Script 08 - Web Server Hardening (T+0:40)

Hardens Apache and Nginx web servers by removing dangerous modules, setting security headers, scanning for web shells, and applying secure configurations. Target this at web servers specifically.

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/08_web_hardening.sh | sudo bash
```

**Key Files to Check After Running:**
- `/etc/apache2/conf-enabled/security.conf` - Apache security settings
- `/etc/nginx/conf.d/security.conf` - Nginx security headers
- `/var/log/webshell-scan.log` - Web shell detection results
- `/etc/apache2/mods-enabled/` - Enabled Apache modules
- `/var/www/html/` - Web root directory (scanned for shells)

**Helpful Commands:**
- `apache2ctl configtest` - Test Apache configuration
- `nginx -t` - Test Nginx configuration
- `systemctl status apache2` - Check Apache status
- `systemctl status nginx` - Check Nginx status
- `grep -r "eval\|base64_decode" /var/www/` - Manual web shell scan

**Common Problems & Fixes:**
- **Web service won't start**: Check config with `apache2ctl configtest` or `nginx -t`
- **Website broken**: Check if required modules were disabled, re-enable with `a2enmod MODULE`
- **Permission errors**: Check web directory permissions and ownership
- **Headers not working**: Verify security headers with browser dev tools

---

## Script 09 - Database Hardening (T+0:45)

Secures MySQL, PostgreSQL, and other database services by changing default passwords, removing test databases, disabling remote access, and applying security configurations. Run on database servers only.

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/09_database_hardening.sh | sudo bash
```

**Key Files to Check After Running:**
- `/etc/mysql/mysql.conf.d/mysqld.cnf` - MySQL security configuration
- `/etc/postgresql/*/main/postgresql.conf` - PostgreSQL configuration
- `/var/log/mysql/error.log` - MySQL error logs
- `/var/log/postgresql/postgresql-*-main.log` - PostgreSQL logs
- `/root/.mysql_history` - Should be cleared/protected

**Helpful Commands:**
- `mysql -u root -p` - Test MySQL root login
- `sudo -u postgres psql` - Test PostgreSQL access
- `systemctl status mysql` - Check MySQL status
- `systemctl status postgresql` - Check PostgreSQL status
- `netstat -tulpn | grep :3306` - Check MySQL network binding
- `netstat -tulpn | grep :5432` - Check PostgreSQL network binding

**Common Problems & Fixes:**
- **Can't connect to database**: Check if script changed bind address, may need to allow network access
- **Application can't connect**: Verify application database user wasn't removed
- **Service won't start**: Check error logs for configuration issues
- **Password not working**: Script generates new passwords, check script output or logs

---

## Script 10 - Final Security Audit (T+1:00)

Performs a comprehensive security audit and vulnerability scan of the system, generating a detailed report of security posture and any remaining issues that need attention.

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/10_final_audit.sh | sudo bash
```

**Key Files to Check After Running:**
- `/root/security-audit-$(date +%Y%m%d).log` - Complete audit report
- `/tmp/lynis-report.dat` - Lynis security scan results
- `/var/log/audit-summary.log` - Summary of findings
- `/root/open-ports.log` - Network services audit

**Helpful Commands:**
- `cat /root/security-audit-*.log` - View full audit report
- `lynis show details WARNING-ID` - Get details on specific warnings
- `ss -tulpn` - Verify open ports against audit report
- `systemctl list-units --failed` - Check for failed services

**Common Problems & Fixes:**
- **High-risk findings**: Review audit report and address critical security issues first
- **Network services exposed**: Use firewall rules to restrict access to necessary services only
- **Weak configurations**: Follow audit recommendations to strengthen configurations
- **Audit tool errors**: Check if audit tools installed correctly, may need manual installation

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