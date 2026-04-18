#!/bin/bash
#
# 02 - Fail2ban Deployment
# Run after SSH lockdown when internet is available
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/02_fail2ban_deploy.sh | sudo bash
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

if [[ $(id -u) -ne 0 ]]; then
    echo -e "${RED}[!] Run this script as root.${RST}"
    exit 1
fi

echo -e "${BOLD}=========================================${RST}"
echo -e "${BOLD}  FAIL2BAN DEPLOYMENT${RST}"
echo -e "${BOLD}=========================================${RST}"

echo -e "${GRN}[+] Installing fail2ban${RST}"

# Detect OS and install
if command -v apt-get &>/dev/null; then
    apt-get update -qq
    apt-get install -y fail2ban
elif command -v dnf &>/dev/null; then
    dnf install -y epel-release
    dnf install -y fail2ban
elif command -v yum &>/dev/null; then
    yum install -y epel-release
    yum install -y fail2ban
else
    echo -e "${RED}[!] Unsupported OS - install fail2ban manually${RST}"
    exit 1
fi

echo -e "${GRN}[+] Configuring fail2ban${RST}"

# Backup original config
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup 2>/dev/null || true

# Write hardened config
cat > /etc/fail2ban/jail.local << 'F2B_EOF'
[DEFAULT]
# Ignore Nebula IPs
ignoreip = 127.0.0.1/8 ::1 172.16.0.0/12

# Ban for 1 hour
bantime = 3600

# Check for attacks over 10 minutes
findtime = 600

# Allow 3 failed attempts
maxretry = 3

# Email notifications (configure SMTP separately)
# destemail = admin@your-domain.com
# sender = fail2ban@your-domain.com
# sendername = Fail2Ban

[sshd]
enabled = true
port = 22
filter = sshd
logpath = AUTHLOG_PLACEHOLDER
maxretry = 3
bantime = 3600
findtime = 600

[apache-auth]
enabled = false
port = http,https
filter = apache-auth
logpath = APACHE_ERROR_LOG_PLACEHOLDER
maxretry = 6

[apache-badbots]
enabled = false
port = http,https
filter = apache-badbots
logpath = APACHE_ACCESS_LOG_PLACEHOLDER
maxretry = 2

[nginx-http-auth]
enabled = false
port = http,https
filter = nginx-http-auth
logpath = NGINX_ERROR_LOG_PLACEHOLDER
maxretry = 6
F2B_EOF

# Resolve log paths (differ between Debian and RHEL)
AUTH_LOG=$(test -f /var/log/auth.log && echo /var/log/auth.log || echo /var/log/secure)
APACHE_ERROR_LOG=$(test -f /var/log/apache2/error.log && echo /var/log/apache2/error.log || echo /var/log/httpd/error_log)
APACHE_ACCESS_LOG=$(test -f /var/log/apache2/access.log && echo /var/log/apache2/access.log || echo /var/log/httpd/access_log)
NGINX_ERROR_LOG=$(test -f /var/log/nginx/error.log && echo /var/log/nginx/error.log || echo /var/log/nginx/error.log)

sed -i "s|AUTHLOG_PLACEHOLDER|${AUTH_LOG}|" /etc/fail2ban/jail.local
sed -i "s|APACHE_ERROR_LOG_PLACEHOLDER|${APACHE_ERROR_LOG}|" /etc/fail2ban/jail.local
sed -i "s|APACHE_ACCESS_LOG_PLACEHOLDER|${APACHE_ACCESS_LOG}|" /etc/fail2ban/jail.local
sed -i "s|NGINX_ERROR_LOG_PLACEHOLDER|${NGINX_ERROR_LOG}|" /etc/fail2ban/jail.local

# Add systemd backend on systems without syslog files
if [[ ! -f /var/log/auth.log && ! -f /var/log/secure ]]; then
    sed -i 's/^\[sshd\]/[sshd]\nbackend = systemd/' /etc/fail2ban/jail.local
fi

echo -e "${GRN}[+] Starting fail2ban service${RST}"
systemctl enable fail2ban
systemctl start fail2ban

echo -e "${GRN}[+] Checking fail2ban status${RST}"
sleep 3
fail2ban-client status

echo ""
echo -e "${BOLD}=========================================${RST}"
echo -e "${GRN}${BOLD}  FAIL2BAN DEPLOYED${RST}"
echo -e "${BOLD}=========================================${RST}"
echo ""
echo -e "${GRAY}Monitor with:${RST}"
echo -e "${GRAY}  fail2ban-client status sshd${RST}"
echo -e "${GRAY}  fail2ban-client get sshd banned${RST}"
echo -e "${GRAY}  tail -f /var/log/fail2ban.log${RST}"