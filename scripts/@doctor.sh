#!/bin/bash
#
# @doctor.sh - Service diagnostic expert system
# Adapted from DSU-DefSec/cyber (https://github.com/DSU-DefSec/cyber)
# Checks why services are down, validates configs, scans logs for failure patterns
# Usage: sudo ./doctor.sh
# Supports: Apache, Nginx, OpenSSH, PostgreSQL, vsftpd, Samba, BIND DNS
#

set -euo pipefail

# ============================================================================
# COLORS
# ============================================================================

RED='\033[1;31m'
YEL='\033[1;33m'
GRN='\033[1;32m'
CYN='\033[0;36m'
BOLD='\033[1m'
RST='\033[0m'

# ============================================================================
# OS DETECTION
# ============================================================================

OS_FLAVOR=""
APACHE_SVC="apache2"
DNS_SVC="bind9"
SSH_SVC="sshd"
SAMBA_SVC="smbd"

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                OS_FLAVOR="debian"
                APACHE_SVC="apache2"
                DNS_SVC="bind9"
                SSH_SVC="ssh"
                SAMBA_SVC="smbd"
                ;;
            rocky|rhel|centos|almalinux|fedora)
                OS_FLAVOR="rhel"
                APACHE_SVC="httpd"
                DNS_SVC="named"
                SSH_SVC="sshd"
                SAMBA_SVC="smb"
                ;;
            *)
                OS_FLAVOR="unknown"
                ;;
        esac
    fi
}

# ============================================================================
# HELPERS
# ============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}=========================================${RST}"
    echo -e "${BOLD}  DIAGNOSTICS: $1${RST}"
    echo -e "${BOLD}=========================================${RST}"
}

print_issue() { echo -e "  ${RED}[ISSUE] $1${RST}"; }
print_ok()    { echo -e "  ${GRN}[OK]   $1${RST}"; }
print_fix()   { echo -e "  ${CYN}[FIX]  $1${RST}"; }

check_service_status() {
    local svc="$1"
    if systemctl is-active --quiet "$svc"; then
        print_ok "$svc is running"
        return 0
    else
        local result=$(systemctl show "$svc" -p Result --value 2>/dev/null || echo "unknown")
        local exit_code=$(systemctl show "$svc" -p ExecMainStatus --value 2>/dev/null || echo "?")
        local restarts=$(systemctl show "$svc" -p NRestarts --value 2>/dev/null || echo "0")
        print_issue "$svc is NOT running (result=$result, exit=$exit_code, restarts=$restarts)"
        [[ "$restarts" -gt 3 ]] && print_issue "$svc has restarted $restarts times — crashlooping?"
        return 1
    fi
}

check_port() {
    local port="$1"
    ss -tulpn 2>/dev/null | grep -q ":$port " && return 0 || return 1
}

check_listen_address() {
    local port="$1" name="$2"
    local listen_line
    listen_line=$(ss -tulpn 2>/dev/null | grep ":$port " || true)
    if [ -z "$listen_line" ]; then
        print_issue "$name is NOT listening on port $port"
        return 1
    fi
    if echo "$listen_line" | grep -qE "0\.0\.0\.0:$port|\*:$port|\[::\]:$port|:::$port"; then
        print_ok "$name listening on all interfaces (port $port)"
        return 0
    fi
    if echo "$listen_line" | grep -qE "127\.0\.0\.1:$port|\[::1\]:$port|::1:$port"; then
        print_issue "$name only listening on localhost (port $port) — scoring engines cannot reach it"
        return 1
    fi
    print_ok "$name listening on external interface (port $port)"
    return 0
}

diagnose_from_logs() {
    local svc="$1"
    echo -e "  ${CYN}[*] Recent logs for $svc:${RST}"
    echo -e "  ${CYN}─────────────────────────────${RST}"

    local logs
    logs=$(journalctl -u "$svc" -p err --no-pager -n 40 2>/dev/null || true)
    if [ -z "$logs" ]; then
        logs=$(journalctl -u "$svc" --no-pager -n 40 2>/dev/null || true)
    fi

    if [ -z "$logs" ]; then
        echo -e "  ${YEL}[!] No journal entries found${RST}"
        return
    fi

    echo "$logs" | sed 's/^/  /'
    echo -e "  ${CYN}─────────────────────────────${RST}"

    local found=0
    if echo "$logs" | grep -qi "address already in use"; then
        print_issue "Port/address conflict — another process holds the port"
        found=1
    fi
    if echo "$logs" | grep -qi "permission denied"; then
        print_issue "Permission denied — check file ownership, SELinux, or capabilities"
        found=1
    fi
    if echo "$logs" | grep -qi "no such file\|file not found\|cannot open"; then
        print_issue "Missing file — config references a path that doesn't exist"
        found=1
    fi
    if echo "$logs" | grep -qi "syntax error\|unexpected end\|invalid command\|unknown directive"; then
        print_issue "Configuration syntax error"
        found=1
    fi
    if echo "$logs" | grep -qi "segfault\|segmentation fault\|core dumped"; then
        print_issue "Service crashed (segfault/core dump)"
        found=1
    fi
    if echo "$logs" | grep -qi "out of memory\|oom\|cannot allocate"; then
        print_issue "Out of memory condition"
        found=1
    fi
    if echo "$logs" | grep -qi "bind.*failed\|could not bind\|failed to listen"; then
        print_issue "Could not bind to port"
        found=1
    fi
    if echo "$logs" | grep -qiE "ssl.*error|tls.*error|certificate.*error|certificate.*expired"; then
        print_issue "TLS/certificate error"
        found=1
    fi

    [[ "$found" -eq 0 ]] && echo -e "  ${YEL}[!] No common failure patterns matched — review logs above${RST}"
}

# ============================================================================
# SERVICE DIAGNOSTICS
# ============================================================================

diag_apache() {
    print_header "Apache ($APACHE_SVC)"

    if ! check_service_status "$APACHE_SVC"; then
        echo -e "  ${CYN}[*] Running syntax validation...${RST}"
        if [[ "$OS_FLAVOR" == "rhel" ]]; then
            apachectl configtest 2>&1 | sed 's/^/  /' || true
        else
            apache2ctl configtest 2>&1 | sed 's/^/  /' || true
        fi
        if check_port 80 || check_port 443; then
            print_issue "Another process is using port 80 or 443"
            ss -tulpn | grep -E ":80 |:443 " | sed 's/^/  /'
            print_fix "Kill the conflicting process, then start $APACHE_SVC"
        fi
        diagnose_from_logs "$APACHE_SVC"
        return
    fi

    check_listen_address 80 "Apache"
}

diag_nginx() {
    print_header "Nginx"

    if ! check_service_status "nginx"; then
        echo -e "  ${CYN}[*] Running syntax test...${RST}"
        nginx -t 2>&1 | sed 's/^/  /' || true
        if check_port 80; then
            print_issue "Port 80 is occupied by another service"
            ss -tulpn | grep ":80 " | sed 's/^/  /'
            print_fix "Kill the conflicting process, then start nginx"
        fi
        diagnose_from_logs "nginx"
        return
    fi

    check_listen_address 80 "Nginx"
}

diag_openssh() {
    print_header "OpenSSH ($SSH_SVC)"

    if ! check_service_status "$SSH_SVC"; then
        echo -e "  ${CYN}[*] Testing sshd_config syntax...${RST}"
        sshd -t 2>&1 | sed 's/^/  /' || true
        diagnose_from_logs "$SSH_SVC"
        return
    fi

    check_listen_address 22 "OpenSSH"

    if grep -qE "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        print_issue "PermitRootLogin is set to YES"
        print_fix "Set PermitRootLogin no in /etc/ssh/sshd_config"
    fi
}

diag_postgres() {
    print_header "PostgreSQL"

    if ! check_service_status "postgresql"; then
        diagnose_from_logs "postgresql"
        return
    fi

    check_listen_address 5432 "PostgreSQL"
}

diag_vsftpd() {
    print_header "vsftpd (FTP)"

    if ! check_service_status "vsftpd"; then
        if [ -f /etc/vsftpd.conf ] || [ -f /etc/vsftpd/vsftpd.conf ]; then
            print_ok "vsftpd config file exists"
        else
            print_issue "vsftpd config file not found"
        fi
        diagnose_from_logs "vsftpd"
        return
    fi

    check_listen_address 21 "vsftpd"

    local conf=""
    [ -f /etc/vsftpd.conf ] && conf="/etc/vsftpd.conf"
    [ -f /etc/vsftpd/vsftpd.conf ] && conf="/etc/vsftpd/vsftpd.conf"
    if [ -n "$conf" ]; then
        if grep -qi "^anonymous_enable=YES" "$conf"; then
            print_issue "Anonymous FTP access is enabled"
        fi
        if grep -qi "^local_enable=NO" "$conf"; then
            print_issue "Local user login is disabled (local_enable=NO)"
            print_fix "Set local_enable=YES in $conf"
        fi
    fi
}

diag_samba() {
    print_header "Samba ($SAMBA_SVC)"

    if ! check_service_status "$SAMBA_SVC"; then
        if command -v testparm >/dev/null; then
            testparm -s /etc/samba/smb.conf 2>&1 | sed 's/^/  /' || true
        fi
        diagnose_from_logs "$SAMBA_SVC"
        return
    fi

    check_listen_address 445 "Samba"
}

diag_dns() {
    print_header "BIND DNS ($DNS_SVC)"

    if ! check_service_status "$DNS_SVC"; then
        if command -v named-checkconf >/dev/null; then
            named-checkconf 2>&1 | sed 's/^/  /' || true
        fi
        diagnose_from_logs "$DNS_SVC"
        return
    fi

    check_listen_address 53 "BIND DNS"

    if command -v named-checkzone >/dev/null; then
        print_ok "Use 'named-checkzone <domain> <zonefile>' to validate individual zones"
    fi
}

diag_mysql() {
    print_header "MySQL/MariaDB"

    if ! check_service_status "mysql"; then
        if ! check_service_status "mariadb"; then
            diagnose_from_logs "mysql"
            diagnose_from_logs "mariadb"
            return
        fi
    fi

    check_listen_address 3306 "MySQL/MariaDB"
}

# ============================================================================
# MAIN
# ============================================================================

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

detect_os

echo -e "${BOLD}=========================================${RST}"
echo -e "${BOLD}  SERVICE DOCTOR${RST}"
echo -e "${BOLD}=========================================${RST}"
echo -e "${GRAY}  OS: ${OS_FLAVOR:-unknown}${RST}"
echo ""

diag_apache
diag_nginx
diag_openssh
diag_postgres
diag_vsftpd
diag_samba
diag_dns
diag_mysql

echo ""
echo -e "${BOLD}=========================================${RST}"
echo -e "${BOLD}  DIAGNOSTICS COMPLETE${RST}"
echo -e "${BOLD}=========================================${RST}"
