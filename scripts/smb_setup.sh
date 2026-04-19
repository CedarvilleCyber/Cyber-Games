#!/bin/bash
#
# @smb_setup.sh - SMB server setup for scoring
# Creates scoring group, configures smbd with sole permissions to a group
# and adds users to the Samba password database for authentication
# Usage: sudo bash smb_setup.sh
#

set -euo pipefail

# ============================================================================
# CONFIGURATION — edit these for your competition
# ============================================================================

SCORING_USERS=(
    "gloucester"
    "scituate"
    "leicester"
    "leominster"
    "tewksbury"
)
SCORING_DIRECTORY="/mnt/files"
CONFIG="/etc/samba/smb.conf"

# ============================================================================
# SETUP
# ============================================================================

NOLOGIN=$(command -v nologin 2>/dev/null || ls /usr/sbin/nologin /sbin/nologin 2>/dev/null | head -1)

echo "[+] Creating scoring group"
groupadd scoring

echo "[+] Creating scoring directory at $SCORING_DIRECTORY"
mkdir -p "$SCORING_DIRECTORY"
chown root:scoring "$SCORING_DIRECTORY"
chmod 2770 "$SCORING_DIRECTORY"

echo "[+] Assigning scoring users to group and entering them into Samba password database"
for i in "${SCORING_USERS[@]}"; do
   user="${SCORING_USERS[$i]}"
   usermod -aG scoring "$user" 2>/dev/null || true
   usermod -s "${NOLOGIN:-/usr/sbin/nologin}" "$user" 2>/dev/null || true
   usermod -d "$SCORING_DIRECTORY" "$user" 2>/dev/null || true
   smbpasswd -e "$user"
done

echo "[+] Writing smbd config to $CONFIG"
cat > "$CONFIG" << EOF
[global]
        workgroup = SAMBA
        security = user
        passdb backend = tdbsam
        map to guest = never
        min protocol = NT1
        max protocol = SMB3
        log file = /var/log/samba/log.%m
        log level = 1

[files]
        path = @SCORING_DIRECTORY
        valid users = @scoring
        read only = No
        guest ok = No
        veto files = /*.exe/*.com/*.dll/*.bat/*.vbs/*.sh/*.php/
        delete veto files = yes
        create mask = 0660
        force create mode = 0660
        directory mask = 0770
        force directory mode = 0770
        force group = scoring
EOF

echo "[+] Check config file for any errors"
testparm -s

echo "[+] Restarting smbd"
systemctl enable smbd
systemctl restart smbd 2>/dev/null || systemctl restart smbd 2>/dev/null || true
echo ""
echo "SMB setup complete"
