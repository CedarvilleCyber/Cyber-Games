#!/bin/bash
#
# @ - Gravwell Centralized Logging Setup
# Optional: Add centralized log ingestion to Gravwell
# Run this AFTER deploying log monitoring (07_log_monitoring.sh)
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/@gravwell_setup.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  GRAVWELL CENTRALIZED LOGGING"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

HOST=$(hostname)

# ── Configuration ────────────────────────────────────────────────────────────
if [[ -z "${GRAVWELL_HOST:-}" ]]; then
    echo ""
    read -rp "[?] Gravwell indexer IP/hostname: " GRAVWELL_HOST
fi

if [[ -z "${GRAVWELL_SECRET:-}" ]]; then
    read -rp "[?] Gravwell ingest secret: " GRAVWELL_SECRET
    echo ""
fi

if [[ -z "$GRAVWELL_HOST" || -z "$GRAVWELL_SECRET" ]]; then
    echo "[!] Gravwell host and secret are required"
    exit 1
fi

# Test connectivity
echo "[1] Testing connectivity to Gravwell indexer"
if timeout 5 bash -c "</dev/tcp/${GRAVWELL_HOST}/4023" 2>/dev/null; then
    echo "    -> Gravwell reachable at ${GRAVWELL_HOST}:4023"
else
    echo "    [!] Warning: Cannot reach ${GRAVWELL_HOST}:4023"
    echo "    [!] Continuing anyway — check network/firewall"
fi

# ============================================================================
# Install Gravwell File Follower
# ============================================================================
echo "[2] Installing Gravwell File Follower"

# Check if already installed
if command -v gravwell_file_follow > /dev/null 2>&1; then
    echo "    -> File Follower already installed"
else
    # Add Gravwell repository
    curl -fsSL https://update.gravwell.io/debian/update.gravwell.io.gpg.key 2>/dev/null | \
        gpg --dearmor -o /usr/share/keyrings/gravwell-archive-keyring.gpg 2>/dev/null || {
        echo "    [!] Failed to add Gravwell GPG key"
    }

    echo "deb [signed-by=/usr/share/keyrings/gravwell-archive-keyring.gpg] https://update.gravwell.io/debian/ community main" \
        > /etc/apt/sources.list.d/gravwell.list 2>/dev/null || {
        echo "    [!] Failed to add Gravwell repository"
    }

    apt-get update -qq > /dev/null 2>&1

    if apt-get install -y -qq gravwell-file-follow > /dev/null 2>&1; then
        echo "    -> Gravwell File Follower installed"
    else
        echo ""
        echo "[!] Automatic install failed. Manual installation:"
        echo "    1. Download from: https://www.gravwell.io/download"
        echo "    2. Install: dpkg -i gravwell-file-follow_*.deb"
        echo "    3. Re-run this script"
        exit 1
    fi
fi

# ============================================================================
# Configure File Follower
# ============================================================================
echo "[3] Configuring Gravwell File Follower"

mkdir -p /opt/gravwell/etc

cat > /opt/gravwell/etc/file_follow.conf << GWEOF
[Global]
Ingest-Secret=${GRAVWELL_SECRET}
Cleartext-Backend-Target=${GRAVWELL_HOST}:4023
Log-Level=WARN
State-Store-Location=/opt/gravwell/etc/file_follow.state

# Falco runtime detection events
[Follower "falco"]
    Base-Directory="/var/log/falco/"
    File-Filter="events.log"
    Tag-Name=falco
    Assume-Local-Timezone=true

# System authentication logs
[Follower "auth"]
    Base-Directory="/var/log/"
    File-Filter="auth.log"
    Tag-Name=auth
    Assume-Local-Timezone=true

# System logs
[Follower "syslog"]
    Base-Directory="/var/log/"
    File-Filter="syslog"
    Tag-Name=syslog
    Assume-Local-Timezone=true

# AIDE file integrity checks
[Follower "aide"]
    Base-Directory="/var/log/"
    File-Filter="aide-check.log"
    Tag-Name=aide
    Assume-Local-Timezone=true

# Kernel logs
[Follower "kern"]
    Base-Directory="/var/log/"
    File-Filter="kern.log"
    Tag-Name=kern
    Assume-Local-Timezone=true

# Cron logs
[Follower "cron"]
    Base-Directory="/var/log/"
    File-Filter="cron.log"
    Tag-Name=cron
    Assume-Local-Timezone=true
GWEOF

echo "    -> Configuration written"

# ============================================================================
# Start Gravwell File Follower
# ============================================================================
echo "[4] Starting Gravwell File Follower"

systemctl daemon-reload
systemctl enable gravwell_file_follow > /dev/null 2>&1
systemctl restart gravwell_file_follow

sleep 2

if systemctl is-active --quiet gravwell_file_follow; then
    echo "    -> File Follower running"
else
    echo "    [!] File Follower failed to start"
    echo "    Check logs: journalctl -u gravwell_file_follow -n 50"
    exit 1
fi

# ============================================================================
# Verification
# ============================================================================
echo ""
echo "========================================="
echo "  GRAVWELL INTEGRATION ACTIVE"
echo "========================================="
echo ""
echo "[+] Logs being sent to: ${GRAVWELL_HOST}:4023"
echo ""
echo "Ingested data streams:"
echo "  • tag=falco   — Falco runtime detection events"
echo "  • tag=auth    — SSH/authentication logs"
echo "  • tag=syslog  — System logs"
echo "  • tag=aide    — AIDE file integrity checks"
echo "  • tag=kern    — Kernel logs"
echo "  • tag=cron    — Cron logs"
echo ""
echo "Useful Gravwell queries:"
echo ""
echo "  # High-severity Falco alerts"
echo "  tag=falco json priority rule output | grep -e priority \"Critical\" \"Error\" | table"
echo ""
echo "  # AIDE file changes"
echo "  tag=aide grep -e \"Added\" \"Removed\" \"Changed\" | table"
echo ""
echo "  # SSH login attempts"
echo "  tag=auth grep -e \"Failed password\" \"Accepted publickey\" | table"
echo ""
echo "  # Timeline of all security events"
echo "  tag=falco,auth,aide count by time | chart count"
echo ""
echo "  # Failed SSH by source IP"
echo "  tag=auth grep \"Failed password\" | regex \"from (?P<ip>\\S+)\" | count by ip | table"
echo ""
echo "Check service status:"
echo "  systemctl status gravwell_file_follow"
echo "  journalctl -u gravwell_file_follow -f"
