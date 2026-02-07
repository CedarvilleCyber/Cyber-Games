#!/bin/bash
#
# 02 - Fail2ban Deployment
# Run after SSH lockdown when internet is available
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/02_fail2ban_deploy.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  FAIL2BAN DEPLOYMENT"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

echo "[1] Installing fail2ban"

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
    echo "[!] Unsupported OS - install fail2ban manually"
    exit 1
fi

echo "[2] Configuring fail2ban"

# Backup original config
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup 2>/dev/null || true

# Write hardened config
cat > /etc/fail2ban/jail.local << 'F2B_EOF'
[DEFAULT]
# Ban for 1 hour
bantime = 3600

# Check for attacks over 10 minutes
findtime = 600

# Allow 3 failed attempts
maxretry = 3

# Ignore private networks (adjust as needed)
ignoreip = 127.0.0.1/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

# Email notifications (configure SMTP separately)
# destemail = admin@your-domain.com
# sender = fail2ban@your-domain.com
# sendername = Fail2Ban

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600

[apache-auth]
enabled = false
port = http,https
filter = apache-auth
logpath = /var/log/apache2/error.log
maxretry = 6

[apache-badbots]
enabled = false
port = http,https
filter = apache-badbots
logpath = /var/log/apache2/access.log
maxretry = 2

[nginx-http-auth]
enabled = false
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 6
F2B_EOF

echo "[3] Starting fail2ban service"
systemctl enable fail2ban
systemctl start fail2ban
systemctl status fail2ban --no-pager

echo "[4] Checking fail2ban status"
sleep 3
fail2ban-client status

echo ""
echo "========================================="
echo "  FAIL2BAN DEPLOYED"
echo "========================================="
echo ""
echo "Monitor with:"
echo "  fail2ban-client status sshd"
echo "  fail2ban-client get sshd banned"
echo "  tail -f /var/log/fail2ban.log"