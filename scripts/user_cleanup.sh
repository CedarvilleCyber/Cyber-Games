#!/bin/bash
#
# User Cleanup - Remove unauthorized users
# Kills and removes all users except scoring users and whitelisted accounts
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/user_cleanup.sh | sudo bash
#

set -euo pipefail

# ============================================================================
# CONFIGURATION - Customize for your competition
# ============================================================================

# Scoring users - NEVER remove these
SCORING_USERS=(
  clancy
  todd_k
  torch_bearer
  ned
  trash
  blurry_face
  nico
  keons
  sacarvo
  listo
  lisdn
  reisdro
  vetomo
  nills
  vialists
  simone_weil
  henri_cartan
  claude_chevalley
)

# Protected system and team accounts
PROTECTED_USERS=(
  root
  blueteam
  blackteam*
  daemon
  bin
  sys
  sync
  games
  man
  lp
  mail
  news
  uucp
  proxy
  www-data
  backup
  list
  irc
  gnats
  nobody
  systemd-network
  systemd-resolve
  messagebus
  systemd-timesync
  syslog
  _apt
  tss
  uuidd
  tcpdump
  landscape
  pollinate
  sshd
  fwupd-refresh
)

# Additional whitelisted users - add legitimate users here
WHITELISTED_USERS=(
  # "alice"
  # "bob"
)

# ============================================================================
# PREFLIGHT
# ============================================================================

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

# Combine all protected users
ALL_PROTECTED=("${PROTECTED_USERS[@]}" "${SCORING_USERS[@]}" "${WHITELISTED_USERS[@]}")

is_protected() {
    local check="$1"
    for u in "${ALL_PROTECTED[@]}"; do
        # Support wildcard patterns (e.g., "blackteam*")
        if [[ "$u" == *\* ]]; then
            local prefix="${u%\*}"
            [[ "$check" == "$prefix"* ]] && return 0
        else
            [[ "$u" == "$check" ]] && return 0
        fi
    done
    return 1
}

echo "========================================="
echo "  USER CLEANUP"
echo "========================================="
echo ""
echo "[!] This will remove ALL users except:"
echo "    - Scoring users (${#SCORING_USERS[@]} users)"
echo "    - Protected system accounts (${#PROTECTED_USERS[@]} accounts)"
echo "    - Whitelisted users (${#WHITELISTED_USERS[@]} users)"
echo ""

read -p "Continue? (type 'YES' to confirm): " confirm
[[ "$confirm" != "YES" ]] && { echo "Aborted."; exit 0; }

echo ""

# ============================================================================
# 1. FIND UNAUTHORIZED USERS
# ============================================================================

echo "[1] Scanning for unauthorized users..."
UNAUTHORIZED=()

while IFS=: read -r username _ uid _ _ homedir shell; do
    # Skip users with UID < 1000 (system users) unless they have a login shell
    if [[ "$uid" -lt 1000 && "$username" != "root" ]]; then
        [[ "$shell" == */nologin || "$shell" == */false ]] && continue
    fi

    # Check if user is protected
    if ! is_protected "$username"; then
        UNAUTHORIZED+=("$username")
        echo "    -> Found: $username (UID: $uid)"
    fi
done < /etc/passwd

if [[ ${#UNAUTHORIZED[@]} -eq 0 ]]; then
    echo "    -> No unauthorized users found!"
    exit 0
fi

echo ""
echo "    Total unauthorized users: ${#UNAUTHORIZED[@]}"
echo ""

# ============================================================================
# 2. KILL ALL PROCESSES
# ============================================================================

echo "[2] Killing processes for unauthorized users..."
MY_PID=$$

for user in "${UNAUTHORIZED[@]}"; do
    PIDS=$(ps -u "$user" -o pid= 2>/dev/null || true)
    if [[ -n "$PIDS" ]]; then
        for pid in $PIDS; do
            [[ "$pid" -eq "$MY_PID" ]] && continue
            echo "    -> Killing PID $pid ($user)"
            kill -9 "$pid" 2>/dev/null || true
        done
    fi
done

# ============================================================================
# 3. REMOVE USER ACCOUNTS
# ============================================================================

echo "[3] Removing user accounts..."

for user in "${UNAUTHORIZED[@]}"; do
    # Lock account first
    passwd -l "$user" 2>/dev/null || true

    # Set shell to nologin
    usermod -s /sbin/nologin "$user" 2>/dev/null || true

    # Remove from sudo/wheel groups
    gpasswd -d "$user" sudo 2>/dev/null || true
    gpasswd -d "$user" wheel 2>/dev/null || true

    # Delete user and home directory
    userdel -r "$user" 2>/dev/null || {
        # If userdel fails, try without removing home
        userdel "$user" 2>/dev/null || true
        # Manually remove home directory
        [[ -d "/home/$user" ]] && rm -rf "/home/$user"
    }

    echo "    -> Removed: $user"
done

# ============================================================================
# 4. AUDIT RESULTS
# ============================================================================

echo ""
echo "[4] Final audit"

echo "    Remaining human users:"
while IFS=: read -r username _ uid _ _ homedir shell; do
    [[ "$uid" -ge 1000 || "$username" == "root" ]] || continue
    [[ "$shell" == */nologin || "$shell" == */false ]] && continue
    echo "       $username (UID: $uid)"
done < /etc/passwd

echo ""
echo "    Active sessions:"
who 2>/dev/null || echo "       (none)"

echo ""
echo "========================================="
echo "  USER CLEANUP COMPLETE"
echo "========================================="
echo ""
echo "Removed ${#UNAUTHORIZED[@]} unauthorized user(s)"
echo ""
