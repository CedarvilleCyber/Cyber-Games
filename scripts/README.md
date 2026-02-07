# [scripts](.)
This directory exists to store scripts that will be run on competition day.

## Table of Contents
- [backups.sh](#backupssh) - Local and remote backups of important directories
- [ssh_keys.sh](#ssh_keyssh) - Add public scoring and team keys to users
- [websetup.sh](#websetupsh) - Web server cronjob management

## [backups.sh](./backups.sh)
- This script performs both local and remote backups of important directories.
- Author: Christopher Reed
- Must be run with sudo.

**Key Files Created/Used:**
- `/root/backups/` - Local backup directory
- `/root/backups/etc_backup.txt` - Backup log for /etc
- `/root/backups/home_backup.txt` - Backup log for /home
- `/root/backups/var_backup.txt` - Backup log for /var/log
- `/root/backups/lib_backup.txt` - Backup log for /lib/systemd
- `/root/backups/bin_backup.txt` - Backup log for /usr/bin
- `/root/backups/sbin_backup.txt` - Backup log for /usr/sbin
- `/root/backups/curr_backup.txt` - Current remote backup log
- `/root/backup_key` - SSH key for remote backups
- `backups@192.168.2.15:~/backups/` - Remote backup location
## [ssh_keys.sh](./ssh_keys.sh)
- This script adds the public scoring key to each scoring user and David's public key to the blueteam user.
- Author: Christopher Reed
- Must be run with sudo.
- Uses:
  - [ssh_scoring_users.txt](../dynamic_files/ssh_scoring_users.txt): List of SSH scoring users
  - [scoring_key.pub](../dynamic_files/scoring_users.txt): Public Scoring Key
  - [david_key.pub](../dynamic_files/david_key.pub): David's Public Key

**Key Files Created/Used:**
- `/home/{user}/.ssh/` - SSH directories created for each scoring user
- `/home/{user}/.ssh/authorized_keys` - Authorized keys files for each user
- `/home/{user}/.ssh/scoring_key.pub` - Copied scoring key for each user
- `/home/blueteam/.ssh/david_key.pub` - David's public key for blueteam
- `../dynamic_files/scoring_users.txt` - Input file with scoring usernames
- `../dynamic_files/scoring_key.pub` - Input scoring public key
- `../dynamic_files/david_key.pub` - Input David's public key
- SSH and SSHD services enabled and restarted
## [websetup.sh](./websetup.sh)
- This script aids in web server cronjob management.
- Author: Ryan Speulstra

**Key Files Created/Used:**
- Crontab entries modified (removes all existing, adds new)
- `*/10 * * * * sudo systemctl restart {service}` - New cronjob added
- Apache2 or Nginx service detection and startup
- System hostname and user information displayed
- Current user's crontab completely replaced
