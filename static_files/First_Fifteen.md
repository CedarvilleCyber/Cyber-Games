# First 15 Checklist

## Machine Documentation
```Shell
hostnamectl status
ip a
whoami
```
- Screenshot
## Immediate Backups
- Run as root user (`sudo su` if not already root)
```Shell
export DIR="/root/backups"
mkdir ${DIR}
init_backup() { rsync -av $1 ${DIR} --log-file=${DIR}/$2_init_backup.txt > /dev/null; }
init_backup /etc etc
init_backup /home home
init_backup /var/log var
init_backup /lib/systemd lib
init_backup /usr/bin bin
init_backup /usr/sbin sbin
```

- Add any additional important directories
## Initial Hardening
- Commands to run (explained below)
```Shell
# Create User
adduser blueteam
# Replace with wheel on Rocky
usermod -a -G sudo blueteam
# Exit out and sign in as new user
exit

# Lock root and remove shell
# Do the same for redteam user if it exists
sudo passwd -l root
sudo passwd -l redteam
sudo vi /etc/passwd

# Remove Extraneous Sudoers
sudo visudo
grep -w sudo /etc/group
grep -w wheel /etc/group
grep -w ssh /etc/group
grep -w blueteam /etc/group

# Harden SSH
sudo vi /etc/ssh/sshd_config

# Optional order: Service, Online, SSH: More initial points
#               : Online, SSH, Service: Faster hardening
# Service is set according to your own checklist
# Online is Networking according to your machine
# Once Networking is set up, the floodgates open (including Red Team)
sudo apt update -y
sudo apt upgrade -y
cd ~
git clone https://github.com/CedarvilleCyber/Cyber-Games
cd Cyber-Games
chmod 700 . ./scripts ./dynamic_files
chmod 400 ./dynamic_files/* ./scripts/README.md
chmod 700 ./scripts/*.sh
sudo ./scripts/passwords.sh
sudo ./scripts/ssh_keys.sh
sudo ./scripts/backups.sh
```
- Extra Users
	- Add extra sudo user (`blueteam`)
		- `adduser blueteam`
		- `usermod -a -G <sudo/wheel> blueteam`
			- `sudo`: Ubuntu
			- `wheel`: Rocky
	- Exit out and sign in as `blueteam`
	- Disable root user
		- `passwd -l root`
		- Change `/etc/passwd`
			- Change root's shell (last field) from `/bin/bash` to `/sbin/nologin`
	- Remove extraneous sudoers
		- Check `/etc/sudoers` with `visudo`
			- Ensure sensible `secure_path`
			- Ensure only `root` shows up under `User privilege specification`
			- Comment out `%admin` line
			- Ensure only `%sudo` shows up
				- `%wheel` may show up in place of `%sudo` on Rocky
			- Delete `#includedir /etc/sudoers.d` line
		- Check `/etc/sudoers.d/`
			- If anything is in there that looks important, ask the captain
		- Check `/etc/group`
			- `grep -w sudo /etc/group`
			- `grep -w wheel /etc/group`
			- `grep -w ssh /etc/group`
			- `grep -w blueteam /etc/group`
			- Also check service users for your service (e.g. `bind` for DNS)
		- `sudo gpasswd -d <username> <sudo/wheel>`
			- `sudo`: Ubuntu
			- `wheel`: Rocky
- SSH
	- Edit `/etc/ssh/sshd_config`
		- Comment out `Include`s
			- Only comment out if unused
		- `PubkeyAuthentication yes`
			- On by default, but easy target for Red Team
		- `PermitRootLogin no`
		- `AuthorizedKeysFile .ssh/authorized_keys`
			- Remove authorized_keys2
		- `PasswordAuthentication no`
		- `PermitEmptyPasswords no`
		- `ChallengeResponseAuthentication no`
		- `UsePAM no`
		- `UseDNS no`
		- `X11Forwarding no`
	- `/etc/ssh/ssh_config`
		- Less necessary, but still good in case Red Team finds a way in
		- Lydia Only: change port to 2222
		- Only change after getting backup SSH key
			- Sent via `scp`, which requires SSH
	- Restart services
## Networking Setup
- Set up appropriately for OS
- Reference [Networking.md](./Networking.md) if necessary
- Once your network is set up, Red Team can start attacking
```Shell
apt update -y
apt upgrade -y
cd ~
git clone https://github.com/CedarvilleCyber/Cyber-Games
cd Cyber-Games
chmod 500 . ./scripts ./dynamic_files
chmod 400 ./dynamic_files ./scripts/README.md
chmod 700 ./scripts/*.sh
```
## SSH
```Shell
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
```
## Individual Service
- Get it set up according to your own checklist
## Continual Backups
- Edit `/etc/environment`
	- Remove anything malicious
	- Ensure sensible PATH
```
TEAM_NUM="<team_number>"
```
- Get backup key
	- `scp backups@192.168.${TEAM_NUM}.15:~/backup_key ~`
- Move SSH key #fix by tossing into init remote backup

- Backup script (run w/ sudo) #fix 
	- Add any important directories
