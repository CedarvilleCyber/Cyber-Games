#!/bin/bash
#
# 07 - Log Monitoring Setup
# Configure centralized logging and monitoring
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/07_log_monitoring.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  LOG MONITORING SETUP"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

echo "[!] Note: Gravwell provides centralized logging in competition"
echo "[!] This script focuses on local security monitoring"

echo "[1] Configuring enhanced local logging"

# Backup original config
cp /etc/rsyslog.conf "/etc/rsyslog.conf.backup.$(date +%s)"

echo "    -> Enhancing local rsyslog configuration"

echo "[2] Enhancing local logging rules"

cat >> /etc/rsyslog.conf << 'RSYSLOG_RULES'

# Enhanced logging for security events
# SSH events
auth,authpriv.*    /var/log/auth.log

# Kernel messages
kern.*             /var/log/kern.log

# Cron events
cron.*             /var/log/cron.log

# Mail events
mail.*             /var/log/mail.log

# All critical and alert messages
*.crit;*.alert     /var/log/critical.log
RSYSLOG_RULES

echo "[3] Configuring log rotation"

cat > /etc/logrotate.d/security-logs << 'LOGROTATE_CONF'
/var/log/auth.log /var/log/kern.log /var/log/critical.log /var/log/cron.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}

/var/log/remote/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}
LOGROTATE_CONF

echo "[4] Creating monitoring scripts"

# Real-time security monitoring
cat > /usr/local/bin/security-monitor.sh << 'MONITOR_SCRIPT'
#!/bin/bash

LOG_FILE="/var/log/security-monitor.log"

echo "Security monitoring started at $(date)" >> "$LOG_FILE"

# Monitor auth.log for security events
tail -F /var/log/auth.log | while read line; do
    # SSH events
    if echo "$line" | grep -E "(Failed password|Invalid user|Accepted publickey|Accepted password|Connection closed)"; then
        echo "$(date): SSH: $line" >> "$LOG_FILE"
    fi
    
    # sudo events
    if echo "$line" | grep -E "(sudo|su):"; then
        echo "$(date): SUDO: $line" >> "$LOG_FILE"
    fi
    
    # User changes
    if echo "$line" | grep -E "(useradd|userdel|usermod|passwd)"; then
        echo "$(date): USER: $line" >> "$LOG_FILE"
    fi
done &

# Monitor for suspicious processes
while true; do
    # Check for reverse shells
    if ps aux | grep -E "nc.*-[el]|bash.*tcp|sh.*tcp|python.*socket" | grep -v grep; then
        echo "$(date): SUSPICIOUS PROCESS DETECTED" >> "$LOG_FILE"
        ps aux | grep -E "nc.*-[el]|bash.*tcp|sh.*tcp|python.*socket" | grep -v grep >> "$LOG_FILE"
    fi
    
    # Check for new SUID files
    if find /tmp /var/tmp /dev/shm /opt -perm -4000 -type f 2>/dev/null; then
        echo "$(date): NEW SUID FILES IN TEMP LOCATIONS" >> "$LOG_FILE"
        find /tmp /var/tmp /dev/shm /opt -perm -4000 -type f -ls 2>/dev/null >> "$LOG_FILE"
    fi
    
    sleep 60
done &

echo "Monitoring processes started (PID: $!)"
MONITOR_SCRIPT

chmod +x /usr/local/bin/security-monitor.sh

# Create alert script
cat > /usr/local/bin/security-alert.sh << 'ALERT_SCRIPT'
#!/bin/bash

# This script processes security events and can send alerts
# Customize for your competition notification method

ALERT_LOG="/var/log/security-alerts.log"

# Function to send alert (customize this)
send_alert() {
    local message="$1"
    echo "$(date): ALERT - $message" >> "$ALERT_LOG"
    
    # Examples of alert methods (uncomment and configure as needed):
    # echo "$message" | mail -s "Security Alert - $(hostname)" admin@domain.com
    # curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" SLACK_WEBHOOK_URL
    # logger -p local0.alert "SECURITY: $message"
}

# Check for brute force attacks
ssh_failures=$(grep "Failed password" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l)
if [[ $ssh_failures -gt 10 ]]; then
    send_alert "High SSH failures detected: $ssh_failures attempts today"
fi

# Check for privilege escalation
sudo_failures=$(grep "authentication failure" /var/log/auth.log | grep sudo | grep "$(date '+%b %d')" | wc -l)
if [[ $sudo_failures -gt 5 ]]; then
    send_alert "Multiple sudo authentication failures: $sudo_failures today"
fi

# Check for new users
if tail -100 /var/log/auth.log | grep -q "useradd"; then
    new_users=$(tail -100 /var/log/auth.log | grep "useradd")
    send_alert "New user account created: $new_users"
fi
ALERT_SCRIPT

chmod +x /usr/local/bin/security-alert.sh

echo "[5] Setting up automated monitoring"

# Add to crontab
if ! crontab -l 2>/dev/null | grep -q "security-alert"; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/security-alert.sh") | crontab -
    echo "    -> Security alerts scheduled every 5 minutes"
fi

# Create systemd service for continuous monitoring
cat > /etc/systemd/system/security-monitor.service << 'SERVICE_FILE'
[Unit]
Description=Security Event Monitor
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/security-monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_FILE

echo "[6] Starting services"

# Restart rsyslog to apply changes
systemctl restart rsyslog

# Enable and start security monitor
systemctl daemon-reload
systemctl enable security-monitor
systemctl start security-monitor

echo "[7] Note: Gravwell handles centralized logging in competition"

echo ""
echo "========================================="
echo "  LOG MONITORING ACTIVE"
echo "========================================="
echo ""
echo "Log files:"
echo "  Security events: /var/log/security-monitor.log"
echo "  Security alerts: /var/log/security-alerts.log"
echo "  Authentication: /var/log/auth.log"
echo "  Critical events: /var/log/critical.log"

echo ""
echo "Commands:"
echo "  Real-time auth monitoring: tail -f /var/log/auth.log"
echo "  View security monitor: tail -f /var/log/security-monitor.log"
echo "  Check service status: systemctl status security-monitor"
echo "  Manual alert check: /usr/local/bin/security-alert.sh"