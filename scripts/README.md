# [scripts](.)
This directory exists to store scripts that will be run on competition day.

## [backups.sh](./backups.sh)
- This script performs both local and remote backups of important directories.
- Author: Christopher Reed
- Must be run with sudo.
## [ssh_keys.sh](./ssh_keys.sh)
- This script adds the public scoring key to each scoring user and David's public key to the blueteam user.
- Author: Christopher Reed
- Must be run with sudo.
- Uses:
  - [ssh_scoring_users.txt](../dynamic_files/ssh_scoring_users.txt): List of SSH scoring users
  - [scoring_key.pub](../dynamic_files/scoring_users.txt): Public Scoring Key
  - [david_key.pub](../dynamic_files/david_key.pub): David's Public Key
## [websetup.sh](./websetup.sh)
- This script aids in web server cronjob management.
- Author: Ryan Speulstra
