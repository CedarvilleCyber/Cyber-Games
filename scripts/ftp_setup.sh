#!/bin/bash
#
# @ftp_setup.sh - FTP server setup for scoring
# Creates scoring group, configures vsftpd with user whitelist
# Usage: sudo bash ftp_setup.sh
#

set -euo pipefail

# ============================================================================
# CONFIGURATION — edit these for your competition
# ============================================================================

SCORING_USERS=(
    "stephen_fair"
)
SCORING_DIRECTORY="/home/stephen_fair/test"

# ============================================================================
# SETUP
# ============================================================================

# Detect config path (Debian vs RHEL)
if [[ -d /etc/vsftpd ]]; then
    CONFIG="/etc/vsftpd/vsftpd.conf"
else
    CONFIG="/etc/vsftpd.conf"
fi

USERLIST="/etc/vsftpd.userlist"

# Detect nologin path
NOLOGIN=$(command -v nologin 2>/dev/null || ls /usr/sbin/nologin /sbin/nologin 2>/dev/null | head -1)

echo "[+] Creating scoring group"
groupadd scoring 2>/dev/null || true

echo "[+] Creating scoring directory at $SCORING_DIRECTORY"
mkdir -p "$SCORING_DIRECTORY"
chown root:scoring "$SCORING_DIRECTORY"
chmod 2770 "$SCORING_DIRECTORY"

echo "[+] Assigning scoring users to group and userlist"
> "$USERLIST"
for user in "${SCORING_USERS[@]}"; do
    usermod -aG scoring "$user" 2>/dev/null || true
    echo "$user" >> "$USERLIST"
    usermod -s "${NOLOGIN:-/usr/sbin/nologin}" "$user" 2>/dev/null || true
    usermod -d "$SCORING_DIRECTORY" "$user" 2>/dev/null || true
done

echo "[+] Writing vsftpd config to $CONFIG"
cat > "$CONFIG" << EOF
listen=YES
anonymous_enable=NO
local_enable=YES
local_umask=002
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40020
userlist_enable=YES
userlist_file=$USERLIST
userlist_deny=NO
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
EOF

echo "[+] Restarting vsftpd"
systemctl restart vsftpd 2>/dev/null || systemctl restart vsftpd 2>/dev/null || true
echo ""
echo "FTP setup complete"