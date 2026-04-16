#!/bin/bash
#
#
# NCAE FTP SCRIPT
#
# this script will do the following:
#       - create the group "scoring"
#       - assign scoring users to the group "scoring"
#       - assign scoring users to the userlist "/etc/vsftpd.userlist"
#       - create scoring directory w/ correct permissions
#       - write correct "vsftpd.conf" file
#       - restart vsftpd service

SCORING_USERS=(
        "stephen_fair"
)
SCORING_DIRECTORY="/home/stephen_fair/test"
USERLIST="/etc/vsftpd.userlist"
CONFIG="/etc/vsftpd.conf"

# STEP 1: CREATE group 'scoring'
echo "[*] ADD SCORING GROUP"
sudo groupadd scoring
echo ""
# STEP 2: CREATE scoring directory
echo "[*] CREATING SCORING DIRECTORY AT $SCORING_DIRECTORY"
sudo mkdir -p "$SCORING_DIRECTORY"
sudo chown root:scoring "$SCORING_DIRECTORY"
sudo chmod 2770 "$SCORING_DIRECTORY"
echo ""
# STEPS 3 & 4: ASSIGN scoring users to group
echo "[*] ASSIGN SCORING USERS TO GROUP + USERLIST"
while IFS= read -r user; do
   [ -n "$user" ] || continue
   sudo usermod -aG scoring "$user"
   echo "$user" >> "$USERLIST"
   sudo usermod -s /usr/sbin/nologin "$user"
   sudo usermod -d "$SCORING_DIRECTORY" "$user"
done < "$file"
echo ""
# STEP 5: WRITE config file
cat > "$CONFIG" << EOF
listen=YES
# disable anonymous login
anonymous_enable=NO
# allow local system users to log in
local_enable=YES
# set file permission mask
local_umask=002
# allow write operations
write_enable=YES
# chroot users to their home directory
chroot_local_user=YES
allow_writeable_chroot=YES
# enable passive mode w/ ports equal to # of scoring users + 1
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40020
# lock down to specific users with a whitelist file
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
# log all activity
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
EOF
echo ""
# STEP 6: RESTART vsftpd
echo "[*] RESTARTING vsftpd"
sudo systemctl restart vsftpd
echo ""
echo "-----------DONE-----------"
