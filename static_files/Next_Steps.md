# Post-SSH Lockdown: Next Steps

After deploying the SSH lockdown script, these are the priority hardening tasks to secure your systems further.

## Quick Priority List

1. **Fail2ban** - Automated intrusion prevention
2. **Kernel hardening** - Sysctl security settings
3. **Firewall lockdown** - Block unnecessary traffic
4. **Service audit** - Disable unused services
5. **File integrity monitoring** - Detect unauthorized changes
6. **Log monitoring** - Centralized logging and alerting

---

## 1. Fail2ban Setup

### Install and configure fail2ban for SSH protection

```bash
# Ubuntu/Debian
apt update && apt install -y fail2ban

# Rocky/RHEL
dnf install -y epel-release && dnf install -y fail2ban
```

### Basic configuration (`/etc/fail2ban/jail.local`)

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
```

### Enable and start

```bash
systemctl enable fail2ban
systemctl start fail2ban
systemctl status fail2ban
```

### Monitor bans

```bash
fail2ban-client status sshd
fail2ban-client get sshd banned
```

---

## 2. Kernel Hardening

### Apply security-focused sysctl settings

Create `/etc/sysctl.d/99-security.conf`:

```bash
# Network security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# ICMP protection
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ping requests
net.ipv4.icmp_echo_ignore_all = 1

# Kernel protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.kexec_load_disabled = 1

# Memory protection
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16

# File system protection
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
```

### Apply settings

```bash
sysctl -p /etc/sysctl.d/99-security.conf
sysctl --system
```

---

## 3. Firewall Lockdown

### UFW (Ubuntu/Debian)

```bash
# Install and enable
apt install -y ufw

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (be careful!)
ufw allow 22/tcp

# Allow specific services as needed
# ufw allow 80/tcp   # HTTP
# ufw allow 443/tcp  # HTTPS

# Enable firewall
ufw enable
ufw status verbose
```

### Firewalld (Rocky/RHEL)

```bash
# Enable firewalld
systemctl enable firewalld
systemctl start firewalld

# Set default zone to drop
firewall-cmd --set-default-zone=drop
firewall-cmd --zone=drop --add-service=ssh --permanent

# Add specific services as needed
# firewall-cmd --zone=drop --add-service=http --permanent
# firewall-cmd --zone=drop --add-service=https --permanent

# Reload configuration
firewall-cmd --reload
firewall-cmd --list-all
```

---

## 4. Service Audit & Hardening

### List and disable unnecessary services

```bash
# List all enabled services
systemctl list-unit-files --state=enabled

# Common services to consider disabling
systemctl disable cups          # Printing
systemctl disable bluetooth     # Bluetooth
systemctl disable avahi-daemon  # Network discovery
systemctl disable nfs-client    # NFS client
systemctl disable rpcbind       # RPC services
systemctl disable postfix       # Mail server (if not needed)

# Stop services immediately
systemctl stop cups bluetooth avahi-daemon
```

### Secure remaining services

```bash
# Secure NTP if needed
apt install -y chrony  # or dnf install chrony
systemctl enable chronyd
systemctl start chronyd

# Lock down file permissions on service configs
find /etc -name "*.conf" -type f -exec chmod 644 {} \;
find /etc -name "*.cfg" -type f -exec chmod 644 {} \;
```

---

## 5. File Integrity Monitoring

### Install and configure AIDE

```bash
# Ubuntu/Debian
apt install -y aide

# Rocky/RHEL
dnf install -y aide
```

### Initialize database

```bash
# Initialize AIDE database
aideinit

# Move database to final location
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### Create check script (`/usr/local/bin/aide-check.sh`)

```bash
#!/bin/bash
/usr/bin/aide --check | tee /var/log/aide-$(date +%Y%m%d).log
if [ $? -ne 0 ]; then
    echo "AIDE detected changes!" | mail -s "AIDE Alert" admin@domain.com
fi
```

### Schedule daily checks

```bash
# Add to crontab
echo "0 2 * * * root /usr/local/bin/aide-check.sh" >> /etc/crontab
```

---

## 6. Log Monitoring & Centralization

### Configure rsyslog for centralized logging

Edit `/etc/rsyslog.conf`:

```bash
# Log all auth events
auth,authpriv.*    /var/log/auth.log

# Log kernel messages
kern.*             /var/log/kern.log

# Remote logging (if you have a log server)
# *.* @@log-server.domain.com:514
```

### Set up log rotation

Create `/etc/logrotate.d/security-logs`:

```bash
/var/log/auth.log /var/log/kern.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}
```

### Monitor critical events

Create `/usr/local/bin/log-monitor.sh`:

```bash
#!/bin/bash
# Monitor for critical events
tail -F /var/log/auth.log | while read line; do
    echo "$line" | grep -E "(Failed password|Invalid user|Accepted publickey)" | \
    logger -t "SSH-MONITOR" -p auth.warning
done &
```

---

## 7. Additional Hardening

### Disable unused network protocols

```bash
# Disable IPv6 if not needed
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/99-security.conf

# Disable uncommon protocols
echo "install dccp /bin/true" >> /etc/modprobe.d/blacklist-rare-network.conf
echo "install sctp /bin/true" >> /etc/modprobe.d/blacklist-rare-network.conf
echo "install rds /bin/true" >> /etc/modprobe.d/blacklist-rare-network.conf
echo "install tipc /bin/true" >> /etc/modprobe.d/blacklist-rare-network.conf
```

### Secure shared memory

```bash
# Add to /etc/fstab
echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
```

### Set up automatic updates (carefully)

```bash
# Ubuntu/Debian - security updates only
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Rocky/RHEL - dnf automatic (security only)
dnf install -y dnf-automatic
systemctl enable dnf-automatic.timer
systemctl start dnf-automatic.timer
```

---

## Competition-Specific Notes

### Quick deployment script ideas

Consider creating scripts for:
- **One-liner fail2ban setup** (similar to SSH lockdown)
- **Kernel hardening in 30 seconds**
- **Service lockdown script** (disable common attack vectors)
- **Log monitoring alerts** (pipe to Discord/Slack)

### Monitoring during comp

Set up simple monitoring:
```bash
# Quick system status
watch -n 5 'ps aux --sort=-%cpu | head -10; echo "---"; ss -tulpn | grep LISTEN'

# Monitor fail2ban
watch -n 10 'fail2ban-client status; echo "---"; tail -5 /var/log/fail2ban.log'
```

### Emergency procedures

Document quick commands for:
- Viewing active connections: `ss -tulpn | grep LISTEN`
- Checking recent logins: `last -10`
- Monitoring processes: `ps aux --sort=-%cpu`
- Network activity: `netstat -antup`
- Fail2ban status: `fail2ban-client status sshd`

---

## Automation Ideas

Consider building these as additional standalone scripts:
1. `kernel_hardening.sh` - Apply all sysctl settings
2. `fail2ban_setup.sh` - Install and configure fail2ban
3. `service_lockdown.sh` - Disable unnecessary services
4. `firewall_lockdown.sh` - Configure UFW/firewalld
5. `monitoring_setup.sh` - Set up AIDE and log monitoring

Each script should be self-contained like the SSH lockdown, with embedded configs and no file dependencies.