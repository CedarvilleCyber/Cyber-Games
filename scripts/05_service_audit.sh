#!/bin/bash
#
# 05 - Service Audit & Lockdown
# Disable unnecessary services and audit what's running
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/05_service_audit.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  SERVICE AUDIT & LOCKDOWN"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

echo "[1] Current running services:"
systemctl list-units --type=service --state=running --no-pager | grep -E "\.service.*running" | awk '{print $1}' | sort

echo ""
echo "[2] Analyzing services for security risks..."

# Services commonly safe to disable in competitions
DISABLE_SERVICES=(
    "cups"              # Printing
    "cups-browsed"      # Printer discovery
    "bluetooth"         # Bluetooth
    "avahi-daemon"      # Network service discovery
    "nfs-client"        # NFS client
    "rpcbind"          # RPC services
    "rpc-gssd"         # NFS GSS daemon
    "rpc-svcgssd"      # NFS service GSS daemon
    "postfix"          # Mail server (if not scored)
    "sendmail"         # Mail server (if not scored)
    "telnet"           # Insecure remote access
    "rsh"              # Insecure remote shell
    "rlogin"           # Insecure remote login
    "finger"           # User information service
    "talk"             # Chat service
    "ntalk"            # Network talk
    "tftp"             # Trivial FTP (if not scored)
    "xinetd"           # Super-server (review what it's serving)
)

# Services to review carefully (may be scored)
REVIEW_SERVICES=(
    "apache2"          # Web server
    "httpd"            # Web server (RHEL)
    "nginx"            # Web server
    "mysql"            # Database
    "mariadb"          # Database
    "postgresql"       # Database
    "named"            # DNS server
    "bind9"            # DNS server
    "vsftpd"           # FTP server
    "proftpd"          # FTP server
    "dovecot"          # Mail server
    "postfix"          # Mail server
    "samba"            # File sharing
    "smbd"             # Samba daemon
    "nmbd"             # NetBIOS daemon
    "snmpd"            # SNMP
)

echo "[3] Disabling potentially unnecessary services:"
for service in "${DISABLE_SERVICES[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
        echo "    -> Disabling $service"
        systemctl disable "$service" 2>/dev/null || true
        systemctl stop "$service" 2>/dev/null || true
    fi
done

echo ""
echo "[4] Services that may be scored (review manually):"
for service in "${REVIEW_SERVICES[@]}"; do
    if systemctl is-active "$service" &>/dev/null; then
        status=$(systemctl is-active "$service")
        echo "    -> $service: $status"
    fi
done

echo ""
echo "[5] Checking for suspicious/unknown services:"
# Look for services not in standard paths or with suspicious names
systemctl list-units --type=service --state=running --no-pager | \
    grep -E "\.service.*running" | \
    awk '{print $1}' | \
    while read service; do
        # Get service file path
        service_file=$(systemctl show -p FragmentPath "$service" 2>/dev/null | cut -d= -f2)
        
        # Check if it's in a suspicious location or has suspicious names
        if [[ "$service_file" =~ (tmp|home|var/tmp|dev/shm) ]] || \
           [[ "$service" =~ (shell|reverse|backdoor|hack|exploit) ]]; then
            echo "    [!] SUSPICIOUS: $service ($service_file)"
        fi
    done

echo ""
echo "[6] Checking xinetd services (if installed):"
if [[ -d /etc/xinetd.d ]]; then
    for conf in /etc/xinetd.d/*; do
        if [[ -f "$conf" && ! "$conf" =~ (README|CVS) ]]; then
            if grep -q "disable.*no" "$conf"; then
                echo "    -> Active xinetd service: $(basename "$conf")"
            fi
        fi
    done
else
    echo "    -> xinetd not installed"
fi

echo ""
echo "[7] Checking for services listening on unusual ports:"
echo "    Unusual listening ports (not 22,53,80,443,3306,5432):"
ss -tulpn | grep LISTEN | \
    awk '{print $5}' | \
    sed 's/.*://' | \
    sort -u | \
    while read port; do
        if ! [[ "$port" =~ ^(22|53|80|443|3306|5432|25|110|143|993|995|21)$ ]]; then
            service_info=$(ss -tulpn | grep ":$port " | awk '{print $7}')
            echo "      Port $port: $service_info"
        fi
    done

echo ""
echo "[8] Checking systemd timers (potential persistence):"
systemctl list-timers --no-pager | grep -v "^$" | head -10

echo ""
echo "[9] Securing remaining services:"

# Disable unnecessary network protocols
echo "    -> Disabling IPv6 (if not needed):"
if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.d/99-security.conf 2>/dev/null; then
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/99-security.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/99-security.conf
    sysctl -p /etc/sysctl.d/99-security.conf >/dev/null
    echo "        IPv6 disabled"
fi

# Secure shared memory
echo "    -> Securing shared memory:"
if ! grep -q "/run/shm" /etc/fstab; then
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
    echo "        Shared memory secured (effective after reboot)"
fi

echo ""
echo "========================================="
echo "  SERVICE AUDIT COMPLETE"
echo "========================================="
echo ""
echo "REVIEW REQUIRED:"
echo "1. Check that all scored services are still running"
echo "2. Verify suspicious services (if any) are legitimate"
echo "3. Consider disabling services marked for review if not scored"
echo ""
echo "Quick service commands:"
echo "  systemctl status SERVICE_NAME"
echo "  systemctl stop SERVICE_NAME"
echo "  systemctl disable SERVICE_NAME"
echo "  systemctl enable SERVICE_NAME"
echo "  systemctl start SERVICE_NAME"