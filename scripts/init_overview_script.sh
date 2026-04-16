#!/bin/bash
#
#
# INITIAL SYSTEM CHECK for...
# 	- tampered kernel
#       - changed shell
#       - OS type
#       - file immutability
#       - existing cronjobs

echo ""
echo "#############################"
echo "------ INITIAL SCRIPT -------"
echo "#############################"
echo ""
echo ""
# CLEAR /tmp DIRECTORY
sudo rm -rf /tmp
sudo rm -rf /etc/ld.so.preload
echo "--/tmp + /etc/ld.so.preload DIRECTORY CLEARED--"
echo ""
# PRINT OS type
echo "--YOUR OS--" && uname -a
echo ""
# PRINT active users
echo "--ACTIVE USERS--" && w
echo ""
# PRINT active connections
echo "--ACTIVE CONNECTIONS (OUTBOUND + INBOUND)--" && ss -tulnp
echo ""
# CHECK for tainted kernel
echo "--TAINTED KERNEL?--" && sysctl kernel.tainted
echo ""
# PRINT kernel messages for taint into taint.txt
echo "**CHECK 'TAINT' KERNEL MESSAGES AND REMOVE MODULES IF NECESSARY!!**"
echo ""
# REMOVE all immutable files
echo "REMOVING IMMUTABLE FILES FROM /etc AND /usr (MAY TAKE A SECOND)..."
sudo chattr -R -i /etc /usr 2>/dev/null
echo "->DONE"
echo ""
# CHANGE default shell for current user to /bin/bash (for saftey)
echo "CHANGING DEFAULT SHELL TO /bin/bash..."
echo -n "**ERROR MESSAGES: " && sudo usermod -s /bin/bash $(whoami)
echo "->DONE"
echo ""
# CRUSH cronjobs for whole system + STOP/DISABLE/MASK cron
echo "SQUASHING ALL CRONTABS & BLOCKING CRON..."
sudo rm -f /etc/crontab
sudo rm -f /etc/cron.d/*
sudo rm -f /etc/cron.daily/*
sudo rm -f /etc/cron.hourly/*
sudo rm -f /etc/cron.weekly/*
sudo rm -f /etc/cron.monthly/*
sudo systemctl stop cron
sudo systemctl disable cron
sudo systemctl mask cron
echo "->DONE"
echo ""

