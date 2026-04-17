#!/bin/bash
#
# 03 - Audit & Lockdown
# Disable unnecessary services, scan for threats, report findings
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/03_audit.sh | sudo bash
#

set -euo pipefail

# ============================================================================
# COLORS
# ============================================================================

RED='\033[1;31m'
YEL='\033[1;33m'
GRN='\033[1;32m'
GRAY='\033[2m'
BOLD='\033[1m'
RST='\033[0m'

CRITICAL=0
WARN=0

# ============================================================================
# CONFIGURATION — edit these for your competition
# ============================================================================

# Services that are being scored — add/remove for your image
SCORED_SERVICES=(
    "apache2" "httpd" "nginx" "mysql" "mariadb" "postgresql"
    "named" "bind9" "vsftpd" "proftpd" "dovecot" "postfix"
    "samba" "smbd" "nmbd" "snmpd"
)

# ============================================================================
# PREFLIGHT
# ============================================================================

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

# ============================================================================
# LOCKDOWN ACTIONS (silent)
# ============================================================================

DISABLE_SERVICES=(
    "cups" "cups-browsed" "bluetooth" "avahi-daemon"
    "nfs-client" "rpcbind" "rpc-gssd" "rpc-svcgssd"
    "postfix" "sendmail" "telnet" "rsh" "rlogin"
    "finger" "talk" "ntalk" "tftp" "xinetd"
)

for service in "${DISABLE_SERVICES[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
        systemctl disable "$service" 2>/dev/null || true
        systemctl stop "$service" 2>/dev/null || true
    fi
done

if ! grep -q "/run/shm" /etc/fstab; then
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
fi

# ============================================================================
# AUDIT
# ============================================================================

echo -e "${GRN}[+] Checking suspicious services${RST}"
systemctl list-units --type=service --state=running --no-pager | \
    grep -E "\.service.*running" | awk '{print $1}' | \
    while read -r service; do
        service_file=$(systemctl show -p FragmentPath "$service" 2>/dev/null | cut -d= -f2)
        if [[ "$service_file" =~ (^/tmp/|^/home/|^/var/tmp/|^/dev/shm/) ]]; then
            echo -e "  ${RED}${service} (${service_file})${RST}"
            ((CRITICAL++))
        elif [[ "$service" =~ (shell|reverse|backdoor|hack|exploit) ]]; then
            echo -e "  ${RED}${service} (${service_file})${RST}"
            ((CRITICAL++))
        else
            echo -e "${GRAY}  ${service}${RST}"
        fi
    done

echo -e "${GRN}[+] Checking UID 0 accounts${RST}"
awk -F: '$3 == 0 {print $1}' /etc/passwd | while read -r user; do
    if [[ "$user" != "root" ]]; then
        echo -e "  ${RED}${user}${RST}"
        ((CRITICAL++))
    else
        echo -e "${GRAY}  ${user}${RST}"
    fi
done

echo -e "${GRN}[+] Checking SUID binaries${RST}"
SUID_FOUND=0
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    echo -e "  ${RED}${f} (removed)${RST}"
    rm -f "$f"
    SUID_FOUND=1
done < <(find /tmp /var/tmp /dev/shm -perm -4000 -type f 2>/dev/null)
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    echo -e "  ${YEL}${f}${RST} (review — may be legitimate)"
    ((WARN++))
done < <(find /opt -perm -4000 -type f 2>/dev/null)
[[ "$SUID_FOUND" -eq 0 ]] && echo -e "${GRAY}  (clean)${RST}"

echo -e "${GRN}[+] Checking listening ports${RST}"
ss -tulpn 2>/dev/null | grep LISTEN | awk '{printf "  %s %s\n", $5, $7}' | sort -u | while read -r line; do
    port=$(echo "$line" | awk '{print $1}' | sed 's/.*://')
    if ! [[ "$port" =~ ^(22|53|80|443|3306|5432|25|110|143|993|995|21)$ ]]; then
        echo -e "  ${RED}${line}${RST}"
        ((WARN++))
    else
        echo -e "${GRAY}  ${line}${RST}"
    fi
done

if [[ -d /etc/xinetd.d ]]; then
    echo -e "${GRN}[+] Checking xinetd services${RST}"
    for conf in /etc/xinetd.d/*; do
        [[ -f "$conf" && ! "$conf" =~ (README|CVS) ]] || continue
        if grep -q "disable.*no" "$conf"; then
            echo -e "  ${RED}$(basename "$conf")${RST}"
            ((WARN++))
        fi
    done
fi

echo -e "${GRN}[+] Checking crontabs${RST}"
SUSPICIOUS_CRON_PATTERN='(nc |ncat|netcat|bash.*\/dev\/tcp|sh.*\/dev\/tcp|curl.*\|.*sh|wget.*\|.*sh|python.*socket|perl.*socket|ruby.*socket|socat|/tmp/|/dev/shm/)'

for crontab in /etc/crontab /etc/cron.d/*; do
    [[ -f "$crontab" ]] || continue
    SUSPICIOUS=$(grep -nE "$SUSPICIOUS_CRON_PATTERN" "$crontab" 2>/dev/null || true)
    if [[ -n "$SUSPICIOUS" ]]; then
        echo -e "  ${RED}${crontab}${RST}"
        while IFS= read -r line; do
            echo -e "  ${RED}${line}${RST}"
        done <<< "$SUSPICIOUS"
        ((CRITICAL++))
    else
        echo -e "${GRAY}  ${crontab} (clean)${RST}"
    fi
done

for usercrontab in /var/spool/cron/crontabs/* /var/spool/cron/*; do
    [[ -f "$usercrontab" ]] || continue
    user=$(basename "$usercrontab")
    echo -e "  ${RED}${user} crontab (should not exist during comp)${RST}"
    while IFS= read -r line; do
        echo -e "  ${RED}${line}${RST}"
    done < "$usercrontab"
    ((CRITICAL++))
done

if crontab -l 2>/dev/null | grep -q .; then
    echo -e "  ${RED}root crontab (should not exist during comp)${RST}"
    crontab -l 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${RED}${line}${RST}"
    done
    ((CRITICAL++))
else
    echo -e "${GRAY}  root crontab (clean)${RST}"
fi

echo -e "${GRN}[+] Checking systemd timers${RST}"
systemctl list-timers --no-pager --no-legend 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /\.timer$/) print $i}' | while read -r timer_name; do
    timer_unit=$(systemctl show -p FragmentPath "$timer_name" 2>/dev/null | cut -d= -f2)
    timer_cmd=$(systemctl show -p ExecStart "$timer_name" 2>/dev/null | cut -d= -f2-)
    if [[ "$timer_unit" =~ (^/tmp/|^/home/|^/var/tmp/|^/dev/shm/) ]] || [[ "$timer_cmd" =~ (^/tmp/|^/home/|^/var/tmp/|^/dev/shm/) ]]; then
        echo -e "  ${RED}${timer_name} → ${timer_cmd}${RST}"
        ((CRITICAL++))
    elif [[ "$timer_cmd" =~ (nc |ncat|netcat|socat|/dev/tcp|curl.*\|.*sh|wget.*\|.*sh|python.*socket|perl.*socket|ruby.*socket) ]]; then
        echo -e "  ${RED}${timer_name} → ${timer_cmd}${RST}"
        ((CRITICAL++))
    else
        echo -e "${GRAY}  ${timer_name}${RST}"
    fi
done

echo -e "${GRN}[+] Checking shell profiles${RST}"
BACKDOOR_PATTERN='(alias.*=\.*(nc|ncat|socat)|/dev/tcp|curl.*\|.*sh|wget.*\|.*sh|python.*socket|perl.*socket|ruby.*socket)'

for filepath in /root/.bashrc /root/.bash_profile /root/.profile /etc/bash.bashrc /etc/profile /etc/environment; do
    [[ -f "$filepath" ]] || continue
    FOUND=$(grep -nE "$BACKDOOR_PATTERN" "$filepath" 2>/dev/null || true)
    if [[ -n "$FOUND" ]]; then
        echo -e "  ${RED}${filepath}${RST}"
        while IFS= read -r line; do
            echo -e "  ${RED}${line}${RST}"
        done <<< "$FOUND"
        ((CRITICAL++))
    else
        echo -e "${GRAY}  ${filepath} (clean)${RST}"
    fi
done

for homedir in /home/*; do
    [[ -d "$homedir" ]] || continue
    for rcfile in .bashrc .bash_profile .profile .bash_login .bash_logout; do
        filepath="$homedir/$rcfile"
        [[ -f "$filepath" ]] || continue
        FOUND=$(grep -nE "$BACKDOOR_PATTERN" "$filepath" 2>/dev/null || true)
        if [[ -n "$FOUND" ]]; then
            echo -e "  ${YEL}${filepath}${RST}"
            while IFS= read -r line; do
                echo -e "  ${YEL}${line}${RST}"
            done <<< "$FOUND"
            ((WARN++))
        else
            echo -e "${GRAY}  ${filepath} (clean)${RST}"
        fi
    done
done

for sysfile in /etc/profile.d/*.sh; do
    [[ -f "$sysfile" ]] || continue
    FOUND=$(grep -nE "$BACKDOOR_PATTERN" "$sysfile" 2>/dev/null || true)
    if [[ -n "$FOUND" ]]; then
        echo -e "  ${YEL}${sysfile}${RST}"
        while IFS= read -r line; do
            echo -e "  ${YEL}${line}${RST}"
        done <<< "$FOUND"
        ((WARN++))
    else
        echo -e "${GRAY}  ${sysfile} (clean)${RST}"
    fi
done

echo -e "${GRN}[+] Checking scored services${RST}"
REVIEW_SERVICES=(
    "apache2" "httpd" "nginx" "mysql" "mariadb" "postgresql"
    "named" "bind9" "vsftpd" "proftpd" "dovecot" "postfix"
    "samba" "smbd" "nmbd" "snmpd"
)

SCORED_FOUND=0
for service in "${SCORED_SERVICES[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
        SCORED_FOUND=1
        if systemctl is-active "$service" &>/dev/null; then
            echo -e "${GRAY}  ${service} (running)${RST}"
        else
            echo -e "  ${YEL}${service}${RST} (enabled but not running)"
            ((WARN++))
        fi
    fi
done
[[ "$SCORED_FOUND" -eq 0 ]] && echo -e "${GRAY}  (none installed)${RST}"

echo -e "${GRN}[+] Checking SUID/SGID binaries system-wide${RST}"
echo -e "${GRAY}  (scanning — this may take a moment)${RST}"
SUID_UNUSUAL=0
find / -perm -4000 -type f 2>/dev/null | grep -vE '^/(usr|bin|sbin|lib)' | while read -r f; do
    echo -e "  ${YEL}${f}${RST}"
    ((WARN++))
    SUID_UNUSUAL=1
done
SGID_UNUSUAL=0
find / -perm -2000 -type f 2>/dev/null | grep -vE '^/(usr|bin|sbin|lib)' | while read -r f; do
    echo -e "  ${YEL}${f}${RST}"
    ((WARN++))
    SGID_UNUSUAL=1
done
[[ "$SUID_UNUSUAL" -eq 0 && "$SGID_UNUSUAL" -eq 0 ]] && echo -e "${GRAY}  (clean — all in /usr, /bin, /sbin, /lib)${RST}"

# PwnKit check
if [[ -u /usr/bin/pkexec ]]; then
    echo -e "  ${RED}/usr/bin/pkexec is SUID — check for CVE-2021-4034 (PwnKit)${RST}"
    ((CRITICAL++))
fi

echo -e "${GRN}[+] Checking world-writable directories${RST}"
find / -type d -perm -002 2>/dev/null | grep -v -E '^/(tmp|var/tmp|dev/shm|proc|sys)' | while read -r d; do
    echo -e "  ${YEL}${d}${RST}"
    ((WARN++))
done
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking recently modified system files (24h)${RST}"
find /etc /bin /sbin /usr/bin /usr/sbin -type f -mtime -1 2>/dev/null | while read -r f; do
    echo -e "${GRAY}  ${f}${RST}"
done
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking suspicious processes${RST}"
ps aux | grep -E 'nc[[:space:]].*-[ec]|ncat[[:space:]]|bash.*\/dev\/tcp|sh.*\/dev\/tcp|python.*socket|perl.*socket|ruby.*socket|socat' | grep -v grep | while read -r line; do
    echo -e "  ${RED}${line}${RST}"
    ((CRITICAL++))
done
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking active network connections${RST}"
ss -tupn 2>/dev/null | grep ESTAB | while read -r line; do
    echo -e "${GRAY}  ${line}${RST}"
done
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking recent auth failures${RST}"
FAILS=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 || true)
if [[ -n "$FAILS" ]]; then
    echo -e "  ${YEL}Recent failed logins:${RST}"
    while IFS= read -r line; do
        echo -e "  ${YEL}${line}${RST}"
    done <<< "$FAILS"
    ((WARN++))
else
    echo -e "${GRAY}  (none found)${RST}"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
if [[ "$CRITICAL" -gt 0 ]]; then
    echo -e "${RED}${BOLD}[!] ${CRITICAL} critical${RST}"
fi
if [[ "$WARN" -gt 0 ]]; then
    echo -e "${YEL}[*] ${WARN} warning(s)${RST}"
fi
if [[ "$CRITICAL" -eq 0 && "$WARN" -eq 0 ]]; then
    echo -e "${GRN}[+] Clean${RST}"
fi