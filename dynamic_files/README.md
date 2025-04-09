# [dynamic_files](.)
This directory exists to store files with data that will change on competition day.

### [scoring_users.txt](./scoring_users.txt)
- This file contains a list of all scoring users who need to login using SSH.
- Syntax is one user per line
- Used by:
  - [ssh_keys.sh](../scripts/ssh_keys.sh)
### [scoring_key.pub](./scoring_key.pub)
- This file contains the scoring public key.
- Used by:
  - [ssh_keys.sh](../scripts/ssh_keys.sh)
### [david_key.pub](./david_key.pub)
- This file contains the public key that allows David to do remote hardening.
- `from=""` should include router IP and IP of David's machines
- Used by:
  - [ssh_keys.sh](../scripts/ssh_keys.sh)
