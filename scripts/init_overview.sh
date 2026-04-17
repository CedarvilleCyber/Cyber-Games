#!/bin/bash
#
# @init_overview.sh - Initial machine cleanup
# Clears common persistence mechanisms, removes immutability, nukes cron
# Usage: sudo bash init_overview.sh
#

set -euo pipefail

echo ""
echo "#############################"
echo "------ INITIAL SCRIPT -------"
echo "#############################"
echo ""

# CLEAR /tmp contents (not the directory itself)
echo "[+] Clearing /tmp and /etc/ld.so.preload"
find /tmp -mindepth 1 -delete 2>/dev/null || true
rm -f /etc/ld.so.preload
echo "    done"
echo ""

# PRINT OS type
echo "[+] System info"
uname -a
echo ""

# PRINT active users
echo "[+] Active users"
w
echo ""

# PRINT active connections
echo "[+] Active connections"
ss -tulnp
echo ""

# CHECK for tainted kernel
echo "[+] Tainted kernel check"
sysctl kernel.tainted 2>/dev/null || echo "    (not available)"
echo "    **CHECK 'TAINT' KERNEL MESSAGES AND REMOVE MODULES IF NECESSARY!!**"
echo ""

# REMOVE all immutable files
echo "[+] Removing immutable flags from /etc and /usr"
chattr -R -ia /etc /usr 2>/dev/null || true
echo "    done"
echo ""

# CHANGE default shell for current user to /bin/bash
echo "[+] Changing default shell to /bin/bash"
NOLOGIN=$(command -v nologin 2>/dev/null || echo "/usr/sbin/nologin")
usermod -s /bin/bash "$(whoami)" 2>/dev/null || true
echo "    done"
echo ""

# CRUSH cronjobs + STOP/DISABLE/MASK cron (try both names)
echo "[+] Squashing all crontabs and blocking cron"
rm -f /etc/crontab
rm -f /etc/cron.d/*
rm -f /etc/cron.daily/*
rm -f /etc/cron.hourly/*
rm -f /etc/cron.weekly/*
rm -f /etc/cron.monthly/*
for svc in cron crond; do
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    systemctl mask "$svc" 2>/dev/null || true
done
echo "    done"
echo ""

echo "============================="
echo "  INITIAL CLEANUP COMPLETE"
echo "============================="