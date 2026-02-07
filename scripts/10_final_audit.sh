#!/bin/bash
#
# 10 - Final Security Audit
# Comprehensive system security check and vulnerability scan
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/10_final_audit.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  FINAL SECURITY AUDIT"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

AUDIT_LOG="/var/log/security-audit-$(date +%Y%m%d-%H%M).log"
echo "Audit results will be logged to: $AUDIT_LOG"

{
echo "=== SECURITY AUDIT STARTED: $(date) ==="
echo ""

echo "[1] SYSTEM OVERVIEW"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime)"
echo ""

echo "[2] USER ACCOUNT AUDIT"
echo "Users with login shells:"
awk -F: '$7 !~ /nologin|false/ {printf "%-15s UID:%-8s Shell:%s\n", $1, $3, $7}' /etc/passwd

echo ""
echo "Users with UID 0 (should only be root):"
awk -F: '$3 == 0 {print $1}' /etc/passwd

echo ""
echo "Recently created users (last 7 days):"
find /home -maxdepth 1 -type d -mtime -7 -exec basename {} \; 2>/dev/null | grep -v "^home$" | while read user; do
    if id "$user" &>/dev/null; then
        echo "  $user (created: $(stat -c %y /home/$user | cut -d' ' -f1))"
    fi
done

echo ""
echo "Password file integrity:"
pwck -r 2>/dev/null || echo "Password file check completed with warnings"
grpck -r 2>/dev/null || echo "Group file check completed with warnings"

echo ""
echo "[3] PRIVILEGE ESCALATION AUDIT"
echo "SUID binaries:"
find / -perm -4000 -type f 2>/dev/null | while read file; do
    echo "  $file"
done

echo ""
echo "SGID binaries:"
find / -perm -2000 -type f 2>/dev/null | head -10

echo ""
echo "World-writable directories:"
find / -type d -perm -002 2>/dev/null | grep -v -E "^/(tmp|var/tmp|dev/shm|proc|sys)" | head -10

echo ""
echo "Files with no owner:"
find / -nouser -o -nogroup 2>/dev/null | head -10

echo ""
echo "[4] NETWORK SECURITY AUDIT"
echo "Listening services:"
ss -tulpn | grep LISTEN | sort

echo ""
echo "Active network connections:"
ss -tupn | grep ESTAB | head -10

echo ""
echo "Firewall status:"
if command -v ufw &>/dev/null; then
    ufw status verbose
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --list-all
else
    echo "No supported firewall detected"
fi

echo ""
echo "Network interfaces:"
ip addr show | grep -E "^[0-9]|inet "

echo ""
echo "[5] SERVICE AUDIT"
echo "Running services:"
systemctl list-units --type=service --state=running --no-pager | grep "\.service.*running"

echo ""
echo "Enabled services:"
systemctl list-unit-files --type=service --state=enabled --no-pager | grep enabled

echo ""
echo "Failed services:"
systemctl --failed --no-pager

echo ""
echo "[6] FILE SYSTEM AUDIT"
echo "Mount points and options:"
mount | grep -v -E "^(proc|sys|dev|run|cgroup)"

echo ""
echo "Disk usage:"
df -h | grep -v -E "^(udev|tmpfs|dev)"

echo ""
echo "Files modified in last 24 hours (system directories):"
find /etc /bin /sbin /usr/bin /usr/sbin -type f -mtime -1 2>/dev/null | head -10

echo ""
echo "Large files (>100MB) in temp directories:"
find /tmp /var/tmp /dev/shm -type f -size +100M -ls 2>/dev/null

echo ""
echo "[7] PROCESS AUDIT"
echo "Processes by CPU usage:"
ps aux --sort=-%cpu | head -10

echo ""
echo "Processes by memory usage:"
ps aux --sort=-%mem | head -10

echo ""
echo "Suspicious processes:"
ps aux | grep -E "nc.*-[el]|bash.*tcp|sh.*tcp|python.*socket|perl.*socket" | grep -v grep

echo ""
echo "Processes running as root:"
ps aux | awk '$1 == "root" {print $2, $11}' | head -15

echo ""
echo "[8] SECURITY CONFIGURATION AUDIT"
echo "SSH configuration status:"
sshd -t && echo "SSH config: OK" || echo "SSH config: ERROR"
grep -E "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AllowUsers)" /etc/ssh/sshd_config

echo ""
echo "Sudo configuration:"
if visudo -cf /etc/sudoers; then
    echo "Sudoers config: OK"
else
    echo "Sudoers config: ERROR"
fi

echo ""
echo "Kernel security parameters:"
sysctl net.ipv4.ip_forward net.ipv4.icmp_echo_ignore_all kernel.dmesg_restrict kernel.kptr_restrict

echo ""
echo "Password policies:"
chage -l root 2>/dev/null | grep -E "(Maximum|Minimum|Warning)"

echo ""
echo "[9] LOG ANALYSIS"
echo "Recent authentication failures:"
grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5

echo ""
echo "Recent successful logins:"
grep "Accepted" /var/log/auth.log 2>/dev/null | tail -5

echo ""
echo "Recent sudo usage:"
grep "sudo:" /var/log/auth.log 2>/dev/null | tail -5

echo ""
echo "System errors (last 24 hours):"
journalctl --since "24 hours ago" --priority=err --no-pager | head -5

echo ""
echo "[10] SECURITY TOOLS STATUS"
echo "Fail2ban status:"
if command -v fail2ban-client &>/dev/null; then
    fail2ban-client status
    echo "Active bans:"
    fail2ban-client banned
else
    echo "Fail2ban not installed"
fi

echo ""
echo "AIDE status:"
if command -v aide &>/dev/null; then
    if [[ -f /var/lib/aide/aide.db ]]; then
        echo "AIDE database exists"
        echo "Last AIDE check:"
        ls -la /var/log/aide-* 2>/dev/null | tail -1
    else
        echo "AIDE installed but database not initialized"
    fi
else
    echo "AIDE not installed"
fi

echo ""
echo "[11] VULNERABILITY SCAN"
echo "Checking for common vulnerabilities..."

# Check for CVE-2021-4034 (PwnKit)
if [[ -u /usr/bin/pkexec ]]; then
    echo "[!] pkexec is SUID - check for CVE-2021-4034 (PwnKit)"
fi

# Check for weak SSH keys
echo "Checking SSH host keys:"
for key in /etc/ssh/ssh_host_*_key.pub; do
    if [[ -f "$key" ]]; then
        keytype=$(awk '{print $1}' "$key")
        keysize=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $1}')
        echo "  $keytype: $keysize bits"
        
        if [[ "$keytype" == "ssh-rsa" && "$keysize" -lt 2048 ]]; then
            echo "    [!] Weak RSA key size: $keysize"
        fi
    fi
done

echo ""
echo "Checking for default/weak passwords:"
# This is basic - in real scenarios you'd use tools like john or hashcat
if grep -q "password" /etc/shadow 2>/dev/null; then
    echo "[!] Found literal 'password' in shadow file"
fi

echo ""
echo "Checking for suspicious cron jobs:"
for crontab in /etc/crontab /etc/cron.d/* /var/spool/cron/*; do
    if [[ -f "$crontab" ]]; then
        echo "Cron file: $crontab"
        grep -E "(nc|netcat|bash.*tcp|curl.*sh|wget.*sh)" "$crontab" 2>/dev/null && echo "  [!] Suspicious cron entry found"
    fi
done

echo ""
echo "[12] RECOMMENDATIONS"
echo "Based on this audit, consider:"

# Check if any basic hardening is missing
if ! systemctl is-active fail2ban &>/dev/null; then
    echo "- Install and configure fail2ban"
fi

if ! command -v aide &>/dev/null; then
    echo "- Install AIDE for file integrity monitoring"
fi

if ss -tulpn | grep -q ":23\|:21\|:513\|:514\|:512"; then
    echo "- Disable insecure services (telnet, ftp, rsh, rlogin)"
fi

if awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd | grep -q .; then
    echo "- Remove non-root accounts with UID 0"
fi

if find /tmp /var/tmp -perm -4000 -type f 2>/dev/null | grep -q .; then
    echo "- Remove SUID files from temp directories"
fi

echo ""
echo "=== SECURITY AUDIT COMPLETED: $(date) ==="

} | tee "$AUDIT_LOG"

echo ""
echo "========================================="
echo "  SECURITY AUDIT COMPLETE"
echo "========================================="
echo ""
echo "Full audit log saved to: $AUDIT_LOG"
echo ""
echo "CRITICAL ISSUES TO REVIEW:"
echo "1. Any non-root users with UID 0"
echo "2. Suspicious processes or network connections"
echo "3. Recently modified system files"
echo "4. Authentication failures in logs"
echo "5. Weak or missing security configurations"
echo ""
echo "NEXT STEPS:"
echo "1. Address any critical issues found"
echo "2. Set up regular monitoring of key metrics"
echo "3. Implement incident response procedures"
echo "4. Schedule regular security audits"
echo ""
echo "Competition-specific:"
echo "- Monitor scoreboard for service availability"
echo "- Check logs regularly for red team activity"
echo "- Maintain backup access methods"
echo "- Document all changes for team coordination"