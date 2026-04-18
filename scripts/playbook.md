# runbook

## links

- [nebula ips](https://nebula-dashboard.kieran-fdb.workers.dev/)
- [score sheet](https://docs.google.com/spreadsheets/d/14kZkKCNFD5ob11aKo5WmjuUN0gXy-cKMvj7LjQG3rjg/edit?gid=1945677410#gid=1945677410)

## follow this

### firewall down no internet for this section

first off setup network on your machine.

next run lockdown (if you don't have internet have kieran generate the base64 blob and ssh into your machine via spice and then paste the command; same goes for all the remaining commands)

```bash
curl -fSsl https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/refs/heads/main/scripts/01_ssh_lockdown.sh | bash
```

lockdown creates a `blueteam` user with a locked password — you must set it manually:

```bash
passwd blueteam
passwd root
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

### firewall goes up here and you get internet access

now download the repo and setup the watch script

```bash
git clone https://github.com/CedarvilleCyber/Cyber-Games.git && cd Cyber-Games && bash tools/setup.sh
```

and run

```bash
cd scripts
sudo bash ./watchdog.sh
```

next you are going to want to install nebula; you will need an enrollment ticket which kieran can generate for you the command you get should look like this

```bash
curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/@dn_install.sh | sudo bash -s weird-long-token-here #test
```

now as you setup scripts you can run the doctor and fruit scripts and they will audit your service configuration and point out any problems
