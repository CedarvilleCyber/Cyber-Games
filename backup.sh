#!/bin/bash

# backup.sh
# Author: Christopher Reed
# Performs both local and remote backups

# Verifies sudo was used
if [ $(id -u) != 0 ]
then
    echo "You must be sudo to run this script!"
    exit 1
fi

# Makes sure environment variables are set
if [ -n ${BACKUP_USER} ] && [ -n ${TEAM_NUM} ]
then
	# Declare Variables
	BACKUP_SERVER="${BACKUP_USER}@192.168.${TEAM_NUM}.15:~/backups"
	ETC_FILE="/backups/etc_backup.txt"
	HOME_FILE="/backups/home_backup.txt"
	REMOTE_FILE="/backups/curr_backup.txt"
	SSH_KEY="/root/backup_key"
	
	# rsync -abv --delete backs up files, forcing consistency, while keeping backups of deleted files (appended with ~)
	# --log-file logs what is done
	# > /dev/null removes command line output
	
	# Local Backups
	rsync -abv --delete /etc/ /backups/etc --log-file=${ETC_FILE} > /dev/null
	printf "\n\nSEARCHABLE TEXT\n\n" >> ${ETC_FILE}
	rsync -abv --delete /home/ /backups/home --log-file=${HOME_FILE} > /dev/null
	printf "\n\nSEARCHABLE TEXT\n\n" >> ${HOME_FILE}
	
	# Remote Backup
	# Remove # after first run (required to establish connection)
	rsync -abv --delete /backups/ ${BACKUP_SERVER}/${HOSTNAME} --log-file=${REMOTE_FILE} -e "ssh -i ${SSH_KEY}" #> /dev/null
	printf "\n\nSEARCHABLE TEXT\n\n" >> ${REMOTE_FILE}
	scp -i ${SSH_KEY} ${REMOTE_FILE} ${BACKUP_SERVER}/curr_${HOSTNAME}_backup.txt
else
	echo "Specify team number and backup user as environment variables."
fi
