#!/bin/bash

add_key () {
	KEY=$1
	USER=$2
	SSH_DIR="/home/${USER}/.ssh"
	AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
	if [ ! -d ${SSH_DIR} ]; then
		mkdir -p ${SSH_DIR}
		chmod 700 ${SSH_DIR}
		chown "${USER}:${USER}" 
	fi
	cp ${KEY} ${SSH_DIR}
	chmod 600 ${SSH_DIR}
	chown "${USER}:${USER}" ${AUTHORIZED_KEYS}
}

if [ $(id -u) != 0 ]
then
    echo "You must run this script with sudo!"
    exit 1
fi

cd /home/blueteam/Cyber-Games
# Add scoring SSH key to each scoring user
for user in $(./dynamic_files/scoring_users.txt); do
    add_key ./dynamic_files/scoring_key.pub $user
done
# Add SSH key for David to do hardening
add_key ./dynamic_files/david_key.pub blueteam

# Enable and restart services
systemctl enable ssh
systemctl enable sshd
systemctl restart ssh
systemctl restart sshd
