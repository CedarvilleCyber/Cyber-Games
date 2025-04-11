# First Fifteen (Command-Only Version)
- **IMPORTANT**: For more detailed instructions, see [First_Fifteen.md](./First_Fifteen.md)
## Machine Documentation
- Screenshot Results
```Shell
hostnamectl status
ip a
whoami
```
## Immediate Backups
- Run as root
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
## Initial Hardening
  ### User Creation
- Sign in as new user
```Shell
adduser blueteam
usermod -a -G sudo blueteam
exit
```
  ### Limiting Root Access
```Shell
sudo passwd -l root
sudo passwd -l redteam
sudo vi /etc/passwd

sudo visudo
grep -w sudo /etc/group
grep -w wheel /etc/group
grep -w ssh /etc/group
grep -w blueteam /etc/group
```
  ### Hardening SSH
- See [First_Fifteen.md](./First_Fifteen.md) for what to edit
```Shell
sudo vi /etc/ssh/sshd_config
```
## Post Internet Access
```Shell
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
