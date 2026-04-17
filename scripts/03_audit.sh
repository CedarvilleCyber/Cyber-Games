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

# Use temp files for counters (subshell-safe)
CRITICAL_FILE=$(mktemp)
WARN_FILE=$(mktemp)
FINDS_FILE=$(mktemp)
echo 0 > "$CRITICAL_FILE"
echo 0 > "$WARN_FILE"
trap 'rm -f "$CRITICAL_FILE" "$WARN_FILE" "$FINDS_FILE"' EXIT
incr_critical() { echo $(( $(cat "$CRITICAL_FILE") + 1 )) > "$CRITICAL_FILE"; }
incr_warn() { echo $(( $(cat "$WARN_FILE") + 1 )) > "$WARN_FILE"; }
get_critical() { cat "$CRITICAL_FILE"; }
get_warn() { cat "$WARN_FILE"; }

# ============================================================================
# CONFIGURATION — edit these for your competition
# ============================================================================

# Services that are being scored — add/remove for your image
SCORED_SERVICES=(
    "apache2" "httpd" "nginx" "mysql" "mariadb" "postgresql"
    "named" "bind9" "vsftpd" "proftpd" "dovecot" "postfix"
    "samba" "smbd" "nmbd" "snmpd"
)

# Known SUID binaries that are legitimate
KNOWN_SUID='/usr/bin/(passwd|sudo|su|chsh|chfn|gpasswd|newgrp|mount|umount|pkexec|crontab|at|ssh-agent|fusermount.?)$|/usr/lib/(openssh/ssh-keysign|dbus-1.0/dbus-daemon-launch-helper|polkit-1/polkit-agent-helper-1|snapd/snap-confine|eject/dmcrypt-get-device)|/usr/(libexec|sbin)/(pt_chown|unix_chkpwd|mount\.nfs)|/sbin/(mount\.nfs|unix_chkpwd)|/bin/(su|mount|umount|ping|fusermount)'

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
    "cron" "crond"
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
            echo "${service}" >> "$FINDS_FILE"
            incr_critical
        elif [[ "$service" =~ (shell|reverse|backdoor|hack|exploit) ]]; then
            echo -e "  ${RED}${service} (${service_file})${RST}"
            echo "${service}" >> "$FINDS_FILE"
            incr_critical
        else
            echo -e "${GRAY}  ${service}${RST}"
        fi
    done

echo -e "${GRN}[+] Checking UID 0 accounts${RST}"
awk -F: '$3 == 0 {print $1}' /etc/passwd | while read -r user; do
    if [[ "$user" != "root" ]]; then
        echo -e "  ${RED}${user}${RST}"
        echo "extra UID 0: $user" >> "$FINDS_FILE"
        incr_critical
    else
        echo -e "${GRAY}  ${user}${RST}"
    fi
done

echo -e "${GRN}[+] Checking user default shells${RST}"
VALID_SHELLS="/bin/bash|/bin/sh|/usr/bin/bash|/usr/bin/sh|/sbin/nologin|/usr/sbin/nologin|/bin/false|/usr/bin/false|/bin/dash|/usr/bin/dash|/bin/zsh|/usr/bin/zsh|/bin/rbash|/usr/bin/rbash"
while IFS=: read -r username _ uid _ _ _ shell; do
    [[ "$uid" -lt 1000 && "$username" != "root" ]] && continue
    if ! echo "$shell" | grep -qE "^(${VALID_SHELLS})$"; then
        echo -e "  ${RED}${username}: ${shell}${RST}"
        echo "nonstandard shell: $username ($shell)" >> "$FINDS_FILE"
        incr_critical
    else
        echo -e "${GRAY}  ${username}: ${shell}${RST}"
    fi
done < /etc/passwd

echo -e "${GRN}[+] Checking nologin binaries for shell swap${RST}"
for nologin in /sbin/nologin /usr/sbin/nologin /bin/false /usr/bin/false; do
    [[ -x "$nologin" ]] || continue
    if strings "$nologin" 2>/dev/null | grep -qiE '(/bin/sh|/bin/bash|/dev/tcp|socat|nc -e|bash -i)'; then
        echo -e "  ${RED}${nologin} contains shell strings — backdoor${RST}"
        echo "$nologin contains shell strings" >> "$FINDS_FILE"
        incr_critical
    elif [[ "$nologin" == *nologin ]] && ! strings "$nologin" 2>/dev/null | grep -qiE '(not available|not allowed|account)'; then
        echo -e "  ${RED}${nologin} missing denial strings — possible shell swap${RST}"
        echo "$nologin missing denial strings" >> "$FINDS_FILE"
        incr_critical
    else
        echo -e "${GRAY}  ${nologin} (OK)${RST}"
    fi
done

echo -e "${GRN}[+] Checking /etc/shells${RST}"
if grep -qE '^/(s?bin|usr/(s?bin)?)/(nologin|false)$' /etc/shells 2>/dev/null; then
    echo -e "  ${RED}/etc/shells lists nologin/false${RST}"
    echo "/etc/shells lists nologin/false" >> "$FINDS_FILE"
    incr_critical
else
    echo -e "${GRAY}  (clean)${RST}"
fi

echo -e "${GRN}[+] Checking system accounts with passwords${RST}"
awk -F: '($2 !~ /^[!*]/ && $2 != "") {print $1}' /etc/shadow 2>/dev/null | while read -r u; do
    uid=$(id -u "$u" 2>/dev/null || true)
    [[ -z "$uid" || "$uid" -ge 1000 || "$u" == "root" ]] && continue
    echo -e "  ${RED}${u} (uid=${uid})${RST}"
    echo "system account with password: $u" >> "$FINDS_FILE"
    incr_critical
done

echo -e "${GRN}[+] Checking /etc/hosts hijacking${RST}"
HOSTS_SUSPECT=$(grep -vE '^\s*(#|$)' /etc/hosts 2>/dev/null | \
    grep -vE '^\s*(127\.|::1|ff02::|fe00::|255\.255\.255\.255)' || true)
if [[ -n "$HOSTS_SUSPECT" ]]; then
    while IFS= read -r line; do
        echo -e "  ${YEL}${line}${RST}"
    done <<< "$HOSTS_SUSPECT"
    incr_warn
else
    echo -e "${GRAY}  (clean)${RST}"
fi

echo -e "${GRN}[+] Checking binary integrity${RST}"
. /etc/os-release 2>/dev/null || true
IS_DEB=0; IS_RPM=0
[[ "${ID:-}" == ubuntu || "${ID:-}" == debian ]] && IS_DEB=1
[[ "${ID:-}" == rocky || "${ID_LIKE:-}" == *rhel* ]] && IS_RPM=1

if (( IS_DEB )); then
    if command -v debsums &>/dev/null; then
        debsums -c 2>/dev/null | grep -E '/(s?bin|lib|lib64)/' | while read -r l; do
            echo -e "  ${RED}debsums: ${l}${RST}"
            echo "debsums: $l" >> "$FINDS_FILE"
            incr_critical
        done
    elif command -v dpkg &>/dev/null; then
        dpkg -V 2>/dev/null | awk '$1 ~ /^..5/ && $2 != "c" {print}' | \
            grep -E '/(s?bin|lib|lib64)/' | while read -r l; do
            echo -e "  ${RED}dpkg -V: ${l}${RST}"
            echo "dpkg -V: $l" >> "$FINDS_FILE"
            incr_critical
        done
    else
        echo -e "${GRAY}  (no package verification tool available)${RST}"
    fi
elif (( IS_RPM )); then
    if command -v rpm &>/dev/null; then
        rpm -Va 2>/dev/null | awk '$1 ~ /^.{0,8}[5SM]/ && $2 != "c" {print}' | \
            grep -E '/(s?bin|lib|lib64)/' | while read -r l; do
            echo -e "  ${RED}rpm -Va: ${l}${RST}"
            echo "rpm -Va: $l" >> "$FINDS_FILE"
            incr_critical
        done
    else
        echo -e "${GRAY}  (no package verification tool available)${RST}"
    fi
else
    echo -e "${GRAY}  (no package verification tool available)${RST}"
fi

echo -e "${GRN}[+] Checking ld.so.preload and library injection${RST}"
if [[ -f /etc/ld.so.preload ]]; then
    echo -e "  ${RED}/etc/ld.so.preload: $(cat /etc/ld.so.preload)${RST}"
    echo "/etc/ld.so.preload: $(cat /etc/ld.so.preload)" >> "$FINDS_FILE"
    incr_critical
fi
for f in /etc/ld.so.conf.d/*.conf; do
    [[ -f "$f" ]] || continue
    if grep -vE '^\s*(#|$)' "$f" 2>/dev/null | grep -qE '^/(tmp|dev/shm|var/tmp|home)'; then
        echo -e "  ${RED}suspect ld.so path in ${f}${RST}"
        echo "suspect ld.so path: $f" >> "$FINDS_FILE"
        incr_critical
    fi
done
if [[ -n "${LD_PRELOAD:-}" ]]; then
    echo -e "  ${RED}LD_PRELOAD set in env: ${LD_PRELOAD}${RST}"
    echo "LD_PRELOAD: $LD_PRELOAD" >> "$FINDS_FILE"
    incr_critical
fi
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking ELF binaries in staging directories${RST}"
ELF_FOUND=0
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if file "$f" 2>/dev/null | grep -q ELF; then
        echo -e "  ${RED}ELF in staging: ${f}${RST}"
        echo "ELF in staging: $f" >> "$FINDS_FILE"
        incr_critical
        ELF_FOUND=1
    fi
done < <(find /tmp /dev/shm /var/tmp -type f 2>/dev/null)
[[ "$ELF_FOUND" -eq 0 ]] && echo -e "${GRAY}  (clean)${RST}"

echo -e "${GRN}[+] Checking kernel modules from unusual paths${RST}"
KMOD_FOUND=0
lsmod 2>/dev/null | awk 'NR>1 {print $1}' | while read -r m; do
    path=$(modinfo -n "$m" 2>/dev/null || true)
    [[ -z "$path" ]] && continue
    if [[ "$path" != /lib/modules/* && "$path" != /usr/lib/modules/* ]]; then
        echo -e "  ${RED}${m} → ${path}${RST}"
        echo "kmod unusual path: $m -> $path" >> "$FINDS_FILE"
        incr_critical
        KMOD_FOUND=1
    fi
done
[[ "$KMOD_FOUND" -eq 0 ]] && echo -e "${GRAY}  (clean)${RST}"

echo -e "${GRN}[+] Checking listening ports${RST}"
if command -v ss &>/dev/null; then
    LISTEN=$(ss -tlnp 2>/dev/null | tail -n +2)
else
    LISTEN=$(netstat -tlnp 2>/dev/null | tail -n +3)
fi
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    port=$(echo "$line" | grep -oP '(?<=[:\]])(\d+)(?=\s)' | tail -1)
    [[ -z "$port" ]] && continue
    pid=$(echo "$line" | grep -oP 'pid=\K\d+' || true)
    bin=$([[ -n "$pid" ]] && readlink /proc/"$pid"/exe 2>/dev/null || echo "unknown")
    if ! [[ "$port" =~ ^(22|53|80|443|3306|5432|25|110|143|993|995|21)$ ]]; then
        echo -e "  ${RED}:${port} → ${bin}${RST}"
        echo "unexpected listener: :$port -> $bin" >> "$FINDS_FILE"
        incr_warn
    else
        echo -e "${GRAY}  :${port} → ${bin}${RST}"
    fi
done <<< "$LISTEN"

echo -e "${GRN}[+] Checking for hidden ports (rootkit detection)${RST}"
if command -v ss &>/dev/null; then
    PROC_PORTS=$(awk 'NR>1 && $4=="0A" {printf "%d\n", strtonum("0x" substr($2, index($2,":")+1))}' \
        /proc/net/tcp /proc/net/tcp6 2>/dev/null | sort -nu)
    SS_PORTS=$(echo "$LISTEN" | grep -oP '(?<=[:\]])\d+(?=\s)' | sort -nu)
    HIDDEN_FOUND=0
    for p in $PROC_PORTS; do
        if ! echo "$SS_PORTS" | grep -qw "$p"; then
            echo -e "  ${RED}port ${p} in /proc/net/tcp but NOT in ss — possible rootkit${RST}"
            echo "hidden port: $p" >> "$FINDS_FILE"
            incr_critical
            HIDDEN_FOUND=1
        fi
    done
    [[ "$HIDDEN_FOUND" -eq 0 ]] && echo -e "${GRAY}  (clean)${RST}"
else
    echo -e "${GRAY}  (ss not available, skipping)${RST}"
fi

echo -e "${GRN}[+] Checking firewall NAT hijacking${RST}"
NAT_FOUND=0
if command -v nft &>/dev/null; then
    nft list ruleset 2>/dev/null | grep -iE 'dnat|redirect' | while read -r l; do
        echo -e "  ${RED}nftables NAT rule: ${l}${RST}"
        echo "nftables NAT: $l" >> "$FINDS_FILE"
        incr_critical
        NAT_FOUND=1
    done
fi
for ipt in iptables iptables-legacy; do
    command -v "$ipt" &>/dev/null || continue
    "$ipt" -t nat -S 2>/dev/null | grep -iE 'DNAT|REDIRECT' | while read -r l; do
        echo -e "  ${RED}${ipt} NAT rule: ${l}${RST}"
        echo "$ipt NAT: $l" >> "$FINDS_FILE"
        incr_critical
        NAT_FOUND=1
    done
done
[[ "$NAT_FOUND" -eq 0 ]] && echo -e "${GRAY}  (clean)${RST}"

if [[ -d /etc/xinetd.d ]]; then
    echo -e "${GRN}[+] Checking xinetd services${RST}"
    for conf in /etc/xinetd.d/*; do
        [[ -f "$conf" && ! "$conf" =~ (README|CVS) ]] || continue
        if grep -q "disable.*no" "$conf"; then
            echo -e "  ${RED}$(basename "$conf")${RST}"
            incr_warn
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
        echo "suspicious cron: $crontab" >> "$FINDS_FILE"
        incr_critical
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
    echo "user crontab: $user" >> "$FINDS_FILE"
    incr_critical
done

if crontab -l 2>/dev/null | grep -q .; then
    echo -e "  ${RED}root crontab (should not exist during comp)${RST}"
    crontab -l 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${RED}${line}${RST}"
    done
    echo "root crontab exists" >> "$FINDS_FILE"
    incr_critical
else
    echo -e "${GRAY}  root crontab (clean)${RST}"
fi

echo -e "${GRN}[+] Checking at jobs${RST}"
if command -v atq &>/dev/null; then
    AT_JOBS=$(atq 2>/dev/null || true)
    if [[ -n "$AT_JOBS" ]]; then
        while IFS= read -r line; do
            echo -e "  ${YEL}at job: ${line}${RST}"
        done <<< "$AT_JOBS"
        incr_warn
    else
        echo -e "${GRAY}  (none)${RST}"
    fi
else
    echo -e "${GRAY}  (at not available)${RST}"
fi

echo -e "${GRN}[+] Checking systemd timers${RST}"
systemctl list-timers --no-pager --no-legend 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /\.timer$/) print $i}' | while read -r timer_name; do
    timer_unit=$(systemctl show -p FragmentPath "$timer_name" 2>/dev/null | cut -d= -f2)
    timer_cmd=$(systemctl show -p ExecStart "$timer_name" 2>/dev/null | cut -d= -f2-)
    if [[ "$timer_unit" =~ (^/tmp/|^/home/|^/var/tmp/|^/dev/shm/) ]] || [[ "$timer_cmd" =~ (^/tmp/|^/home/|^/var/tmp/|^/dev/shm/) ]]; then
        echo -e "  ${RED}${timer_name} → ${timer_cmd}${RST}"
        echo "suspicious timer: $timer_name" >> "$FINDS_FILE"
        incr_critical
    elif [[ "$timer_cmd" =~ (nc |ncat|netcat|socat|/dev/tcp|curl.*\|.*sh|wget.*\|.*sh|python.*socket|perl.*socket|ruby.*socket) ]]; then
        echo -e "  ${RED}${timer_name} → ${timer_cmd}${RST}"
        echo "suspicious timer: $timer_name" >> "$FINDS_FILE"
        incr_critical
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
        echo "backdoor in profile: $filepath" >> "$FINDS_FILE"
        incr_critical
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
            incr_warn
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
        incr_warn
    else
        echo -e "${GRAY}  ${sysfile} (clean)${RST}"
    fi
done

echo -e "${GRN}[+] Checking SUID/SGID binaries${RST}"
echo -e "${GRAY}  (scanning — this may take a moment)${RST}"

# Temp dirs — remove on sight
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    echo -e "  ${RED}${f} (removed)${RST}"
    rm -f "$f"
    echo "SUID in temp: $f (removed)" >> "$FINDS_FILE"
    incr_critical
done < <(find /tmp /var/tmp /dev/shm -perm -4000 -type f 2>/dev/null)

# Nonstandard SUID with known-good whitelist
find /usr/bin/ /usr/sbin/ /bin/ /sbin/ -xdev -perm -4000 -type f 2>/dev/null | while read -r f; do
    if ! echo "$f" | grep -qE "$KNOWN_SUID"; then
        echo -e "  ${RED}unusual SUID: ${f}${RST}"
        echo "unusual SUID: $f" >> "$FINDS_FILE"
        incr_critical
    fi
done

# SUID in /home
find /home -xdev -perm -4000 -type f 2>/dev/null | while read -r f; do
    echo -e "  ${RED}SUID in /home: ${f}${RST}"
    echo "SUID in /home: $f" >> "$FINDS_FILE"
    incr_critical
done

# SUID in /opt (review)
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    echo -e "  ${YEL}${f} (review — may be legitimate)${RST}"
    incr_warn
done < <(find /opt -perm -4000 -type f 2>/dev/null)

# SGID outside standard paths
find / -perm -2000 -type f 2>/dev/null | grep -vE '^/(usr|bin|sbin|lib|lib64)' | while read -r f; do
    echo -e "  ${YEL}unusual SGID: ${f}${RST}"
    incr_warn
done

# PwnKit check
if [[ -u /usr/bin/pkexec ]]; then
    echo -e "  ${RED}/usr/bin/pkexec is SUID — check for CVE-2021-4034 (PwnKit)${RST}"
    echo "pkexec SUID (PwnKit)" >> "$FINDS_FILE"
    incr_critical
fi

echo -e "${GRN}[+] Checking elevated capabilities${RST}"
if command -v getcap &>/dev/null; then
    CAP_FOUND=0
    getcap -r / 2>/dev/null | grep -vE '(cap_net_bind_service|cap_net_raw)\+(ep|eip)$' | while read -r l; do
        [[ -n "$l" ]] || continue
        echo -e "  ${RED}${l}${RST}"
        echo "capability: $l" >> "$FINDS_FILE"
        incr_critical
        CAP_FOUND=1
    done
    [[ "$CAP_FOUND" -eq 0 ]] && echo -e "${GRAY}  (clean)${RST}"
else
    echo -e "${GRAY}  (getcap not available)${RST}"
fi

echo -e "${GRN}[+] Checking sudoers for NOPASSWD ALL${RST}"
NOPASSWD_FOUND=0
grep -rhsiE 'NOPASSWD.*ALL|ALL.*NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | \
    grep -v '^\s*#' | while read -r l; do
    echo -e "  ${RED}${l}${RST}"
    echo "sudoers NOPASSWD: $l" >> "$FINDS_FILE"
    incr_critical
    NOPASSWD_FOUND=1
done
[[ "$NOPASSWD_FOUND" -eq 0 ]] && echo -e "${GRAY}  (clean)${RST}"

echo -e "${GRN}[+] Checking PAM for pam_exec${RST}"
PAM_FOUND=0
grep -rhE '^\s*[^#].*pam_exec\.so' /etc/pam.d/ 2>/dev/null | while read -r l; do
    echo -e "  ${RED}${l}${RST}"
    echo "PAM pam_exec: $l" >> "$FINDS_FILE"
    incr_critical
    PAM_FOUND=1
done
[[ "$PAM_FOUND" -eq 0 ]] && echo -e "${GRAY}  (clean)${RST}"

echo -e "${GRN}[+] Checking sshd_config for dangerous directives${RST}"
for directive in "PermitRootLogin yes" "PermitEmptyPasswords yes" "GatewayPorts yes"; do
    if grep -qiE "^\s*${directive}" /etc/ssh/sshd_config 2>/dev/null; then
        echo -e "  ${RED}sshd_config: ${directive}${RST}"
        echo "sshd_config: $directive" >> "$FINDS_FILE"
        incr_critical
    fi
done
AKF=$(grep -iE '^\s*AuthorizedKeysFile' /etc/ssh/sshd_config 2>/dev/null | grep -v '\.ssh/authorized_keys' || true)
if [[ -n "$AKF" ]]; then
    echo -e "  ${RED}non-standard AuthorizedKeysFile: ${AKF}${RST}"
    echo "AuthorizedKeysFile: $AKF" >> "$FINDS_FILE"
    incr_critical
fi
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking SSH authorized keys${RST}"
while IFS=: read -r user _ _ _ _ homedir _; do
    [[ -d "$homedir" ]] || continue
    ak="$homedir/.ssh/authorized_keys"
    [[ -f "$ak" ]] || continue
    count=$(grep -cvE '^\s*(#|$)' "$ak" 2>/dev/null || echo 0)
    (( count )) || continue
    echo -e "  ${YEL}${user} — ${count} SSH key(s):${RST}"
    grep -vE '^\s*(#|$)' "$ak" | awk '{printf "       [%s] %s\n", $1, $3}' | while read -r kl; do
        echo -e "  ${YEL}${kl}${RST}"
    done
done < /etc/passwd

echo -e "${GRN}[+] Checking immutable files${RST}"
if command -v lsattr &>/dev/null; then
    IMMU_FOUND=0
    lsattr /etc/passwd /etc/shadow /etc/sudoers /etc/ssh/sshd_config 2>/dev/null | \
        grep -E '^\S*i\S*\s' | while read -r l; do
        echo -e "  ${RED}immutable: ${l}${RST}"
        echo "immutable: $l" >> "$FINDS_FILE"
        incr_critical
        IMMU_FOUND=1
    done
    [[ "$IMMU_FOUND" -eq 0 ]] && echo -e "${GRAY}  (clean)${RST}"
else
    echo -e "${GRAY}  (lsattr not available)${RST}"
fi

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
            incr_warn
        fi
    fi
done
[[ "$SCORED_FOUND" -eq 0 ]] && echo -e "${GRAY}  (none installed)${RST}"

echo -e "${GRN}[+] Checking world-writable directories${RST}"
find / -type d -perm -002 2>/dev/null | grep -v -E '^/(tmp|var/tmp|dev/shm|proc|sys)' | while read -r d; do
    echo -e "  ${YEL}${d}${RST}"
    incr_warn
done
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking recently modified system files (7 days)${RST}"
find /bin /sbin /usr/bin /usr/sbin /lib /lib64 -type f -mtime -7 2>/dev/null | while read -r f; do
    mod_time=$(stat -c %y "$f" 2>/dev/null | cut -d. -f1)
    echo -e "  ${YEL}${f} (${mod_time})${RST}"
done
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking suspicious processes${RST}"
ps aux | grep -E 'nc[[:space:]].*-[ec]|ncat[[:space:]]|bash.*\/dev\/tcp|sh.*\/dev\/tcp|python.*socket|perl.*socket|ruby.*socket|socat' | grep -v grep | while read -r line; do
    echo -e "  ${RED}${line}${RST}"
    echo "suspicious process: $(echo "$line" | awk '{print $2}')" >> "$FINDS_FILE"
    incr_critical
done

echo -e "${GRN}[+] Checking processes with deleted executables${RST}"
for pid in /proc/[0-9]*/exe; do
    readlink "$pid" 2>/dev/null | grep -q '(deleted)' || continue
    n=${pid#/proc/}; n=${n%/exe}
    cmd=$(ps -p "$n" -o cmd= 2>/dev/null || echo "unknown")
    echo -e "  ${RED}PID ${n} from deleted binary: ${cmd}${RST}"
    echo "deleted binary PID $n: $cmd" >> "$FINDS_FILE"
    incr_critical
done
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking active network connections${RST}"
ss -tupn 2>/dev/null | grep ESTAB | while read -r line; do
    echo -e "${GRAY}  ${line}${RST}"
done
echo -e "${GRAY}  (done)${RST}"

echo -e "${GRN}[+] Checking recent auth failures${RST}"
FAILS=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5; grep "Failed password" /var/log/secure 2>/dev/null | tail -5 || true)
if [[ -n "$FAILS" ]]; then
    echo -e "  ${YEL}Recent failed logins:${RST}"
    while IFS= read -r line; do
        echo -e "  ${YEL}${line}${RST}"
    done <<< "$FAILS"
    incr_warn
else
    echo -e "${GRAY}  (none found)${RST}"
fi

# ============================================================================
# SUMMARY
# ============================================================================

CRITICAL=$(get_critical)
WARN=$(get_warn)

echo ""
echo -e "${BOLD}=========================================${RST}"
echo -e "${BOLD}  AUDIT SUMMARY${RST}"
echo -e "${BOLD}=========================================${RST}"
echo ""

mapfile -t ALL_FINDS < "$FINDS_FILE"
if [[ ${#ALL_FINDS[@]} -gt 0 ]]; then
    for i in "${!ALL_FINDS[@]}"; do
        printf "  ${RED}${BOLD}[%2d]${R} %s\n" "$((i+1))" "${ALL_FINDS[$i]}"
    done
    echo ""
fi

if [[ "$CRITICAL" -gt 0 ]]; then
    echo -e "${RED}${BOLD}[!] ${CRITICAL} critical${RST}"
fi
if [[ "$WARN" -gt 0 ]]; then
    echo -e "${YEL}[*] ${WARN} warning(s)${RST}"
fi
if [[ "$CRITICAL" -eq 0 && "$WARN" -eq 0 ]]; then
    echo -e "${GRN}[+] Clean${RST}"
fi
