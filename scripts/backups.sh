#!/bin/bash

# backup.sh
# Performs both local and remote backups
local_backup () {
	case $1 in 
		/etc)
			DIR_SHORT="etc"
			;;
		/home)
			DIR_SHORT="home"
			;;
		/var/log)
			DIR_SHORT="var"
			;;
		/lib/systemd)
			DIR_SHORT="lib"
			;;
		/usr/bin)
			DIR_SHORT="bin"
			;;
		/usr/sbin)
			DIR_SHORT="sbin"
			;;
		# Absolute Directory Path)
			# DIR_SHORT="<short, identifiable name>"
			#;;
		*)
			echo "Bad Directory" >2
			exit 1
			;;
	esac
	LOG="${LOCAL_DIR}/${DIR_SHORT}_backup.txt"
	# rsync -abv --delete backs up files, forcing consistency, while keeping backups of deleted files (appended with ~)
	# --log-file logs what is done
	# > /dev/null removes command line output
	rsync -abv --delete --log-file=${LOG} $1 ${LOCAL_DIR} > /dev/null
	printf "\n\nSEARCHABLE TEXT\n\n\n" >> ${LOG}
}

remote_backup () {
	LOG="${LOCAL_DIR}/curr_backup.txt"
	# rsync -abv --delete backs up files, forcing consistency, while keeping backups of deleted files (appended with ~)
	# --log-file logs what is done
	# -e uses SSH
	# > /dev/null removes command line output
	rsync -abv --delete --log-file={LOG} -e "ssh -i ${SSH_KEY}" ${LOCAL_DIR} ${REMOTE_DIR} > /dev/null
	printf "\n\nSEARCHABLE TEXT\n\n\n" >> ${LOG}
	scp -i ${SSH_KEY} ${LOG} ${REMOTE_DIR}/curr_backup.txt
}

init_remote_backup () {
	# Get SSH key
	scp ${BACKUP_SERVER}/../backup_key ~
#	chown root:root ~/backup_key
#	mv ~/backup_key ${SSH_KEY}
	
	LOG="${LOCAL_DIR}/init_backup.txt"
	rsync -abv --delete --log-file={LOG} -e "ssh -i ${SSH_KEY}"
	scp -i ${SSH_KEY} ${LOG} ${BACKUP_SERVER}/init/${HOSTNAME}_init_backup.txt
}

# Verifies sudo was used
if [ $(id -u) != 0 ]
then
    echo "You must run this script with sudo!"
    exit 1
fi
# Makes sure environment variables are set
if [ -z ${TEAM_NUM} ]
then
	echo "You must set TEAM_NUM environment variable in /etc/environment!"
	exit 1
fi

# Declare Variables
BACKUP_SERVER="backups@192.168.${TEAM_NUM}.15:~/backups"
REMOTE_DIR="${BACKUP_SERVER}/${HOSTNAME}"
LOCAL_DIR="/root/backups"
SSH_KEY="/root/backup_key"

# Ensure backup directory exists
if [ ! -d ${LOCAL_DIR} ]
then
	mkdir /root/backups
fi
# Ensure SSH key exists
if [ ! -e ${SSH_KEY} ]
then
	init_remote_backup
fi

local_backup /etc
local_backup /home
local_backup /var/log
local_backup /lib/systemd
local_backup /usr/bin
local_backup /usr/sbin

remote_backup
