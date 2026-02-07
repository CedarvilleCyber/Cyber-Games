#!/bin/bash
#
# 04 - Firewall Lockdown
# Configure UFW/firewalld for competition security
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/04_firewall_lockdown.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  FIREWALL LOCKDOWN"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

# Prompt for scored services
echo "[!] IMPORTANT: You need to know which services are being scored!"
echo "    Common scored services: SSH(22), HTTP(80), HTTPS(443), DNS(53), MySQL(3306)"
echo "    Check your competition documentation for the full list."
echo ""

read -p "Continue with firewall setup? (yes/no): " confirm
[[ "$confirm" != "yes" ]] && { echo "Aborted."; exit 0; }

# Detect firewall system
if command -v ufw &>/dev/null; then
    FIREWALL="ufw"
elif command -v firewall-cmd &>/dev/null; then
    FIREWALL="firewalld"
else
    echo "[1] Installing UFW"
    if command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y ufw
        FIREWALL="ufw"
    elif command -v dnf &>/dev/null; then
        systemctl enable firewalld && systemctl start firewalld
        FIREWALL="firewalld"
    else
        echo "[!] Cannot install firewall - manual setup required"
        exit 1
    fi
fi

echo "[1] Configuring $FIREWALL"

if [[ "$FIREWALL" == "ufw" ]]; then
    # UFW Configuration
    echo "    Setting up UFW..."
    
    # Reset to clean state
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Always allow SSH (critical!)
    ufw allow 22/tcp comment 'SSH'
    
    # Common scored services - CUSTOMIZE THESE
    echo ""
    echo "    Adding common scored services (customize as needed):"
    
    # Web services
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    echo "      -> HTTP/HTTPS added"
    
    # DNS
    ufw allow 53/tcp comment 'DNS-TCP'
    ufw allow 53/udp comment 'DNS-UDP'
    echo "      -> DNS added"
    
    # Uncomment/add others as needed:
    # ufw allow 21/tcp comment 'FTP'
    # ufw allow 25/tcp comment 'SMTP'
    # ufw allow 110/tcp comment 'POP3'
    # ufw allow 143/tcp comment 'IMAP'
    # ufw allow 993/tcp comment 'IMAPS'
    # ufw allow 995/tcp comment 'POP3S'
    # ufw allow 3306/tcp comment 'MySQL'
    # ufw allow 5432/tcp comment 'PostgreSQL'
    
    # Enable logging
    ufw logging on
    
    # Enable firewall
    ufw --force enable
    
    echo "[2] UFW Status:"
    ufw status verbose

elif [[ "$FIREWALL" == "firewalld" ]]; then
    # Firewalld Configuration
    echo "    Setting up firewalld..."
    
    # Ensure firewalld is running
    systemctl enable firewalld
    systemctl start firewalld
    
    # Set default zone to drop (deny all by default)
    firewall-cmd --set-default-zone=drop
    
    # Add SSH to drop zone (critical!)
    firewall-cmd --zone=drop --add-service=ssh --permanent
    
    # Add common scored services
    echo ""
    echo "    Adding common scored services (customize as needed):"
    
    # Web services
    firewall-cmd --zone=drop --add-service=http --permanent
    firewall-cmd --zone=drop --add-service=https --permanent
    echo "      -> HTTP/HTTPS added"
    
    # DNS
    firewall-cmd --zone=drop --add-service=dns --permanent
    echo "      -> DNS added"
    
    # Uncomment/add others as needed:
    # firewall-cmd --zone=drop --add-service=ftp --permanent
    # firewall-cmd --zone=drop --add-service=smtp --permanent
    # firewall-cmd --zone=drop --add-service=pop3 --permanent
    # firewall-cmd --zone=drop --add-service=imap --permanent
    # firewall-cmd --zone=drop --add-port=3306/tcp --permanent  # MySQL
    # firewall-cmd --zone=drop --add-port=5432/tcp --permanent  # PostgreSQL
    
    # Reload configuration
    firewall-cmd --reload
    
    echo "[2] Firewalld Status:"
    firewall-cmd --list-all
fi

echo "[3] Current listening ports:"
ss -tulpn | grep LISTEN | awk '{printf "    %-20s %s\n", $5, $7}' | sort -u

echo "[4] Testing critical services"
echo "    SSH connection test (should work):"
if ss -tulpn | grep -q ":22 "; then
    echo "      -> SSH listening on port 22 ✓"
else
    echo "      -> WARNING: SSH not detected on port 22!"
fi

echo ""
echo "========================================="
echo "  FIREWALL LOCKDOWN COMPLETE"
echo "========================================="
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Test that all scored services still work"
echo "2. Check competition scoreboard for any red services"
echo "3. Add/remove firewall rules as needed for your specific services"
echo ""
echo "Firewall commands:"
if [[ "$FIREWALL" == "ufw" ]]; then
    echo "  View status: ufw status verbose"
    echo "  Add rule: ufw allow 3306/tcp comment 'MySQL'"
    echo "  Remove rule: ufw delete allow 3306/tcp"
    echo "  View logs: tail -f /var/log/ufw.log"
else
    echo "  View status: firewall-cmd --list-all"
    echo "  Add rule: firewall-cmd --zone=drop --add-port=3306/tcp --permanent && firewall-cmd --reload"
    echo "  Remove rule: firewall-cmd --zone=drop --remove-port=3306/tcp --permanent && firewall-cmd --reload"
    echo "  View logs: journalctl -u firewalld -f"
fi