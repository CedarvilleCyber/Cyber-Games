#!/bin/bash
#
# 06 - File Integrity Monitoring Setup
# Deploy AIDE for file integrity monitoring
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/06_file_integrity.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  FILE INTEGRITY MONITORING"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

echo "[1] Installing AIDE"

if command -v apt-get &>/dev/null; then
    apt-get update -qq
    apt-get install -y aide
elif command -v dnf &>/dev/null; then
    dnf install -y aide
elif command -v yum &>/dev/null; then
    yum install -y aide
else
    echo "[!] Unsupported OS - install AIDE manually"
    exit 1
fi

echo "[2] Configuring AIDE for competition environment"

# Backup original config
cp /etc/aide/aide.conf /etc/aide/aide.conf.backup 2>/dev/null || \
cp /etc/aide.conf /etc/aide.conf.backup 2>/dev/null || true

# Write competition-focused AIDE config
AIDE_CONF="/etc/aide/aide.conf"
[[ ! -f "$AIDE_CONF" ]] && AIDE_CONF="/etc/aide.conf"

cat > "$AIDE_CONF" << 'AIDE_EOF'
# AIDE configuration for NCAE competition

# Database paths
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new

# Verbose level
verbose=5

# Report settings
report_url=file:/var/log/aide.log

# Rule definitions
All=p+i+n+u+g+s+m+S+md5+sha1+rmd160
Norm=s+n+b+md5+sha1+rmd160

# Critical system directories
/boot Norm
/bin All
/sbin All
/lib All
/lib64 All
/opt All
/usr All
!/usr/src
!/usr/tmp

# Configuration directories
/etc All

# Critical files that red team often modifies
/etc/passwd All
/etc/shadow All
/etc/group All
/etc/gshadow All
/etc/sudoers All
/etc/sudoers.d All
/etc/ssh All
/etc/crontab All
/etc/cron.d All
/etc/cron.hourly All
/etc/cron.daily All
/etc/cron.weekly All
/etc/cron.monthly All

# Service configurations
/etc/apache2 All
/etc/httpd All
/etc/nginx All
/etc/mysql All
/etc/postgresql All

# System binaries that might be replaced
/bin/bash All
/bin/sh All
/bin/su All
/bin/sudo All
/usr/bin/ssh All
/usr/sbin/sshd All

# Logs (check for rotation/deletion)
/var/log Norm

# Exclude frequently changing directories
!/var/log/lastlog
!/var/log/wtmp
!/var/log/btmp
!/var/log/utmp
!/var/cache
!/var/tmp
!/tmp
!/proc
!/sys
!/dev
!/run
!/var/run
!/var/lock
!/var/lib/aide/aide.db
!/var/lib/aide/aide.db.new
!/var/lib/dpkg
!/var/lib/apt
!/var/lib/yum
!/var/lib/rpm
!/home/.*/.bash_history
!/root/.bash_history
AIDE_EOF

echo "[3] Initializing AIDE database (this may take a few minutes)"
echo "    Creating baseline of current system state..."

# Initialize the database
if command -v aideinit &>/dev/null; then
    aideinit
else
    aide --init
fi

# Move the new database to the expected location
if [[ -f /var/lib/aide/aide.db.new ]]; then
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    echo "    -> Database initialized successfully"
else
    echo "[!] Database initialization may have failed"
fi

echo "[4] Creating monitoring scripts"

# Create check script
cat > /usr/local/bin/aide-check.sh << 'CHECK_SCRIPT'
#!/bin/bash
LOG_FILE="/var/log/aide-$(date +%Y%m%d-%H%M).log"

echo "=== AIDE File Integrity Check - $(date) ===" | tee "$LOG_FILE"

if aide --check | tee -a "$LOG_FILE"; then
    echo "No changes detected" | tee -a "$LOG_FILE"
    exit 0
else
    echo "CHANGES DETECTED!" | tee -a "$LOG_FILE"
    
    # In competition, you might want to send alerts
    # echo "AIDE detected file changes on $(hostname)" | mail -s "AIDE Alert" admin@domain.com
    
    exit 1
fi
CHECK_SCRIPT

chmod +x /usr/local/bin/aide-check.sh

# Create update script (for when you make legitimate changes)
cat > /usr/local/bin/aide-update.sh << 'UPDATE_SCRIPT'
#!/bin/bash
echo "Updating AIDE database with current system state..."
aide --update
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
echo "AIDE database updated"
UPDATE_SCRIPT

chmod +x /usr/local/bin/aide-update.sh

echo "[5] Setting up automated checks"

# Add to root's crontab for regular monitoring
if ! crontab -l 2>/dev/null | grep -q "aide-check"; then
    (crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/aide-check.sh") | crontab -
    echo "    -> Added to crontab: check every 6 hours"
fi

echo "[6] Running initial check to verify setup"
if /usr/local/bin/aide-check.sh; then
    echo "    -> Initial check passed"
else
    echo "    -> Initial check detected changes (expected after installation)"
fi

echo ""
echo "========================================="
echo "  FILE INTEGRITY MONITORING ACTIVE"
echo "========================================="
echo ""
echo "Commands:"
echo "  Manual check: /usr/local/bin/aide-check.sh"
echo "  Update baseline: /usr/local/bin/aide-update.sh"
echo "  View logs: ls -la /var/log/aide-*"
echo ""
echo "IMPORTANT:"
echo "1. AIDE will detect ANY file changes - including legitimate ones"
echo "2. After making system changes, run aide-update.sh to update baseline"
echo "3. Logs are in /var/log/aide-* - check them regularly during competition"
echo "4. Large changes may indicate compromise - investigate immediately"