# runbook

## links

- [nebula ips](https://nebula-dashboard.kieran-fdb.workers.dev/)

## follow this

first off setup network on your machine and change your password.

next run lockdown

```bash
curl -fSsl https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/refs/heads/main/scripts/01_ssh_lockdown.sh | bash
```

make the tmp folder immutable and latter as you edit services also make their configuration immutable

```bash
chattr +i /tmp
```

next run the audit script

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/03_audit.sh | sudo bash
```

if anything flags and looks eggregious then either fix it or flag it with someone else and have them fix it.

next setup fail2ban

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/02_fail2ban.sh | sudo bash
```

now download the repo and setup the watch script

```bash
git clone https://github.com/CedarvilleCyber/Cyber-Games.git && cd Cyber-Games && bash tools/setup.sh
```

and run

```bash
cd scripts
sudo bash ./watchdog.sh
```
