#!/bin/bash
#
# SELF-CONTAINED SSH Lockdown — paste into Proxmox console, no files needed.
# Usage: sudo bash (then paste), or: echo '<base64>' | base64 -d | sudo bash
#

set -euo pipefail

# ============================================================================
# COLORS
# ============================================================================

RED='\033[1;31m'
YEL='\033[1;33m'
GRN='\033[1;32m'
GRAY='\033[2m'
BOLD='\033[1m'
RST='\033[0m'

# ============================================================================
# EMBEDDED DATA — no external files required
# ============================================================================

SCORING_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcM4aDj8Y4COv+f8bd2WsrIynlbRGgDj2+q9aBeW1Umj5euxnO1vWsjfkpKnyE/ORsI6gkkME9ojAzNAPquWMh2YG+n11FB1iZl2S6yuZB7dkVQZSKpVYwRvZv2RnYDQdcVnX9oWMiGrBWEAi4jxcYykz8nunaO2SxjEwzuKdW8lnnh2BvOO9RkzmSXIIdPYgSf8bFFC7XFMfRrlMXlsxbG3u/NaFjirfvcXKexz06L6qYUzob8IBPsKGaRjO+vEdg6B4lH1lMk1JQ4GtGOJH6zePfB6Gf7rp31261VRfkpbpaDAznTzh7bgpq78E7SenatNbezLDaGq3Zra3j53u7XaSVipkW0S3YcXczhte2J9kvo6u6s094vrcQfB9YigH4KhXpCErFk08NkYAEJDdqFqXIjvzsro+2/EW1KKB9aNPSSM9EZzhYc+cBAl4+ohmEPej1m15vcpw3k+kpo1NC2rwEXIFxmvTme1A2oIZZBpgzUqfmvSPwLXF0EyfN9Lk= SCORING KEY DO NOT REMOVE"

# ============================================================================
# TEAM SSH KEYS — Add your team member keys here
# ============================================================================
# Copy/paste public keys below. Format: "ssh-rsa/ssh-ed25519 AAAAA... comment"

KIERAN_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICqdma6oGDS8cqEgA+2kFwQaKZ64/Zo+h4AngQxj6mpt kieranklukas@cedarville.edu"
DAVID_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpsK7SawD1oUPJt+wg9Zozygy5G8LUcTn9MUZ7nxw9U david"
KALEB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFTx+ePBnQHZzHx4Tre1faoT1Kofn4ZA4HbKgo2mjhdn kalebkorner@Kalebs-MacBook-Pro.local"
NATHAN_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINpKIhN7knpnqlOB2vXRlrc+f76pR1T4F165IkFVDVjw nwkar@AnnoyingLaptop"
JOE_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPOTGLUg1PeA1rP+c0fh9S+I2k6jNpcQDGGfRKpStsr1 josep@JoeSystem"
ABBY_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTUSqi8BYVgUWPmAITcKmfdT2bzpWroUU/4ddJqf5nr awurster232@cedarville.edu"
NOAH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJf7gez/H6qjOOPnGeyKZ08f3Ax89KZ4/F9MaeM8BXws nmmar@Kearney"
DANIEL_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJguU0jBNg+7G6cMMXK8SX8IwfSPx6p2qcPAvwj2g+Q+ danie@DB-Lenovo"
MICAH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPbtiN8k4yVhmcVUmwvGkGwE+Nw01O9ZeSOQklVPWqnX micah@WindowReMi"

# Add more team member keys here:
# NEWKEY="ssh-rsa AAAAB3... user@example.com"
# NEWKEY2="ssh-ed25519 AAAAC3... user2@example.com"

# Add team member keys to this array (uncomment and add as needed):
TEAM_KEYS=(
    "$KIERAN_KEY"
    "$DAVID_KEY"
    "$KALEB_KEY"
    "$NATHAN_KEY"
    "$JOE_KEY"
    "$ABBY_KEY"
    "$NOAH_KEY"
    "$DANIEL_KEY"
    "$MICAH_KEY"
    # "$NEWKEY"
    # "$NEWKEY2"
)

SCORING_USERS=(
  clancy
  todd_k
  torch_bearer
  ned
  trash
  blurry_face
  nico
  keons
  sacarvo
  listo
  lisdn
  reisdro
  vetomo
  nills
  vialists
  simone_weil
  henri_cartan
  claude_chevalley
)

PROTECTED_USERS=(
    "blackteam*"
    "blueteam"
    "root"
)

# Additional allowed SSH users — fill in before comp
ALLOWED_USERS=(
    # "alice"
    # "bob"
)

# Additional whitelisted users — never delete these even with --delete-users
WHITELISTED_USERS=(
    # "alice"
    # "bob"
)

# ============================================================================
# PRE-FLIGHT
# ============================================================================

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_SUFFIX=".bak.$(date +%s)"

if [[ $(id -u) -ne 0 ]]; then
    echo -e "${RED}[!] Run this script as root.${RST}"
    exit 1
fi

ALL_PROTECTED=("${PROTECTED_USERS[@]}" ${ALLOWED_USERS[@]+"${ALLOWED_USERS[@]}"} "${SCORING_USERS[@]}" ${WHITELISTED_USERS[@]+"${WHITELISTED_USERS[@]}"})

is_protected() {
    local check="$1"
    for u in "${ALL_PROTECTED[@]}"; do
        # Support wildcard patterns (e.g., "blackteam*")
        if [[ "$u" == *\* ]]; then
            local prefix="${u%\*}"
            [[ "$check" == "$prefix"* ]] && return 0
        else
            [[ "$u" == "$check" ]] && return 0
        fi
    done
    return 1
}

echo -e "${BOLD}=========================================${RST}"
echo -e "${BOLD}  SSH LOCKDOWN${RST}"
echo -e "${BOLD}=========================================${RST}"
echo -e "${GRAY}Protected users: ${ALL_PROTECTED[*]}${RST}"
echo ""

# ============================================================================
# 1. CREATE BLUETEAM USER & SET PASSWORDS
# ============================================================================

echo -e "${GRN}[+] Setting up blueteam user and passwords${RST}"

# Check if passwords provided via environment variables
if [[ -n "${ROOT_PASSWORD:-}" && -n "${BLUETEAM_PASSWORD:-}" ]]; then
    ROOT_PW="$ROOT_PASSWORD"
    BLUETEAM_PW="$BLUETEAM_PASSWORD"
    echo -e "${GRAY}  Using passwords from environment variables${RST}"
# Check if we can read from terminal (not piped)
elif [[ -t 0 ]]; then
    read -sp "    Enter password for root: " ROOT_PW < /dev/tty
    echo ""
    read -sp "    Enter password for blueteam: " BLUETEAM_PW < /dev/tty
    echo ""
else
    # Script is piped - generate random passwords
    ROOT_PW=$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)
    BLUETEAM_PW=$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)

    echo ""
    echo -e "${RED}${BOLD}╔════════════════════════════════════════════════════════════════╗${RST}"
    echo -e "${RED}${BOLD}║         GENERATED PASSWORDS - COPY/SCREENSHOT NOW!             ║${RST}"
    echo -e "${RED}${BOLD}╠════════════════════════════════════════════════════════════════╣${RST}"
    echo -e "${RED}${BOLD}║  root password:     ${ROOT_PW}                           ║${RST}"
    echo -e "${RED}${BOLD}║  blueteam password: ${BLUETEAM_PW}                           ║${RST}"
    echo -e "${RED}${BOLD}╚════════════════════════════════════════════════════════════════╝${RST}"
    echo ""
    echo -e "${RED}[!] Passwords NOT saved to disk — copy them NOW${RST}"
    echo -e "${GRAY}    Waiting 10 seconds...${RST}"
    echo ""

    sleep 10
fi

# Validate passwords are not empty
if [[ -z "$ROOT_PW" || -z "$BLUETEAM_PW" ]]; then
    echo -e "${RED}[!] ERROR: Passwords cannot be empty${RST}"
    exit 1
fi

if ! id "blueteam" &>/dev/null; then
    useradd -m -s /bin/bash blueteam
    echo -e "${GRAY}  Created blueteam user${RST}"
fi

SUDO_GROUP="sudo"
grep -q "^wheel:" /etc/group && SUDO_GROUP="wheel"

usermod -aG "$SUDO_GROUP" blueteam 2>/dev/null || true
echo -e "${GRAY}  blueteam added to ${SUDO_GROUP}${RST}"

echo "root:${ROOT_PW}" | chpasswd
echo -e "${GRAY}  root password set${RST}"
echo "blueteam:${BLUETEAM_PW}" | chpasswd
echo -e "${GRAY}  blueteam password set${RST}"

unset ROOT_PW BLUETEAM_PW

# ============================================================================
# 2. BACKUP
# ============================================================================

echo -e "${GRN}[+] Backing up ${SSHD_CONFIG}${RST}"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}${BACKUP_SUFFIX}"

# ============================================================================
# 3. HARDENED sshd_config
# ============================================================================

echo -e "${GRN}[+] Writing hardened sshd_config${RST}"
cat > "$SSHD_CONFIG" << 'SSHD_EOF'
Protocol 2
Port 22
AddressFamily any
ListenAddress 0.0.0.0

PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
UsePAM yes

HostbasedAuthentication no
IgnoreRhosts yes
GSSAPIAuthentication no
KerberosAuthentication no

MaxAuthTries 3
MaxSessions 3
MaxStartups 3:50:10
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
PermitUserEnvironment no
GatewayPorts no

SyslogFacility AUTH
LogLevel VERBOSE

Subsystem sftp SFTP_SERVER_PLACEHOLDER
SSHD_EOF

# Resolve SFTP server path (differs between Debian and RHEL)
SFTP_SERVER=$(ls /usr/lib/openssh/sftp-server /usr/libexec/openssh/sftp-server 2>/dev/null | head -1)
sed -i "s|SFTP_SERVER_PLACEHOLDER|${SFTP_SERVER:-/usr/lib/openssh/sftp-server}|" "$SSHD_CONFIG"

ALLOW_LINE="AllowUsers"
for u in "${ALL_PROTECTED[@]}"; do
    ALLOW_LINE+=" $u"
done
echo "$ALLOW_LINE" >> "$SSHD_CONFIG"
echo -e "${GRAY}  ${ALLOW_LINE}${RST}"

echo -e "${GRN}[+] Locking down file permissions${RST}"
chmod 644 /etc/passwd
chown root:root /etc/passwd
chmod 640 /etc/shadow
chown root:shadow /etc/shadow 2>/dev/null || chown root:root /etc/shadow
chmod 644 /etc/group
chown root:root /etc/group
chmod 600 /etc/ssh/sshd_config
chown root:root /etc/ssh/sshd_config
chmod 600 /etc/sudoers
chown root:root /etc/sudoers
echo -e "${GRAY}  /etc/passwd:      644 root:root${RST}"
echo -e "${GRAY}  /etc/shadow:      640 root:shadow${RST}"
echo -e "${GRAY}  /etc/group:       644 root:root${RST}"
echo -e "${GRAY}  /etc/ssh/sshd_config: 600 root:root${RST}"
echo -e "${GRAY}  /etc/sudoers:     600 root:root${RST}"

# ============================================================================
# 4. SUDOERS CLEANUP
# ============================================================================

echo -e "${GRN}[+] Cleaning sudoers${RST}"

cp /etc/sudoers "/etc/sudoers${BACKUP_SUFFIX}"

cat > /tmp/sudoers.new << SUDOERS_EOF
Defaults    env_reset
Defaults    mail_badpass
Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

root    ALL=(ALL:ALL) ALL
%${SUDO_GROUP}    ALL=(ALL:ALL) ALL
SUDOERS_EOF

if visudo -cf /tmp/sudoers.new &>/dev/null; then
    cp /tmp/sudoers.new /etc/sudoers
    chmod 440 /etc/sudoers
    echo -e "${GRAY}  /etc/sudoers replaced (root + %${SUDO_GROUP} only)${RST}"
else
    echo -e "${YEL}  WARNING: generated sudoers invalid, keeping original${RST}"
fi
rm -f /tmp/sudoers.new

echo -e "${GRN}[+] Wiping /etc/sudoers.d/${RST}"
if [[ -d /etc/sudoers.d ]]; then
    for f in /etc/sudoers.d/*; do
        [[ -f "$f" ]] && mv "$f" "${f}.disabled" && echo -e "  ${RED}${f} disabled${RST}"
    done
fi

echo -e "${GRN}[+] Removing non-protected users from ${SUDO_GROUP}${RST}"
for member in $(getent group "$SUDO_GROUP" | cut -d: -f4 | tr ',' ' '); do
    if ! is_protected "$member"; then
        gpasswd -d "$member" "$SUDO_GROUP" 2>/dev/null || true
        echo -e "  ${RED}${member} removed from ${SUDO_GROUP}${RST}"
    else
        echo -e "${GRAY}  ${member} kept in ${SUDO_GROUP}${RST}"
    fi
done

# ============================================================================
# 5. NUKE UNAUTHORIZED KEYS
# ============================================================================

echo -e "${GRN}[+] Cleaning unauthorized SSH keys${RST}"
for homedir in /home/*/; do
    username=$(basename "$homedir")
    rm -f "$homedir/.ssh/authorized_keys2"
    if ! is_protected "$username"; then
        rm -rf "$homedir/.ssh"
        echo -e "  ${RED}Wiped .ssh for ${username}${RST}"
    fi
done
rm -f /root/.ssh/authorized_keys2
rm -f /etc/ssh/authorized_keys /etc/ssh/authorized_keys2

echo -e "${GRN}[+] Removing planted private keys${RST}"
for homedir in /root /home/*; do
    [[ -d "$homedir" ]] || continue
    username=$(basename "$homedir")
    if is_protected "$username"; then
        echo -e "${GRAY}  ${username} (protected)${RST}"
        continue
    fi
    find "$homedir" -type f \( -name "id_rsa*" -o -name "id_ed25519*" -o -name "id_ecdsa*" -o -name "id_dsa*" \) 2>/dev/null | while read -r keyfile; do
        echo -e "  ${RED}${keyfile} removed${RST}"
        rm -f "$keyfile"
    done
done

# ============================================================================
# 6. DEPLOY KEYS (inline — no files needed)
# ============================================================================

echo -e "${GRN}[+] Deploying keys${RST}"

add_key_inline() {
    local key_content="$1"
    local user="$2"
    local ssh_dir="/home/${user}/.ssh"
    local ak_file="${ssh_dir}/authorized_keys"

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    if [[ -f "$ak_file" ]]; then
        grep -qF "$key_content" "$ak_file" 2>/dev/null || echo "$key_content" >> "$ak_file"
    else
        echo "$key_content" > "$ak_file"
    fi

    chmod 600 "$ak_file"
    chown -R "${user}:${user}" "$ssh_dir"
}

for user in "${SCORING_USERS[@]}"; do
    if id "$user" &>/dev/null; then
        add_key_inline "$SCORING_KEY" "$user"
        echo -e "${GRAY}  ${user}: scoring key${RST}"
    fi
done

# Deploy all team member keys to blueteam user
for team_key in "${TEAM_KEYS[@]}"; do
    if [[ -n "$team_key" ]]; then
        add_key_inline "$team_key" "blueteam"
        key_comment=$(echo "$team_key" | awk '{print $NF}')
        echo -e "${GRAY}  blueteam: ${key_comment}${RST}"
    fi
done

# ============================================================================
# 7. KILL NON-PROTECTED SESSIONS & REVERSE SHELLS
# ============================================================================

echo -e "${GRN}[+] Killing non-protected sessions${RST}"
MY_PID=$$
MY_PPID=$(ps -o ppid= -p $MY_PID | tr -d ' ')

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    sess_user=$(echo "$line" | awk '{print $1}')
    sess_pid=$(echo "$line" | awk '{print $2}')
    [[ "$sess_pid" == "$MY_PID" || "$sess_pid" == "$MY_PPID" ]] && continue
    if ! is_protected "$sess_user"; then
        echo -e "  ${RED}KILL ${sess_user} (PID ${sess_pid})${RST}"
        kill -9 "$sess_pid" 2>/dev/null || true
    fi
done < <(ps aux | grep '[s]shd.*@' || true)

echo -e "${GRN}[+] Killing reverse shells and suspicious processes${RST}"
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    sus_pid=$(echo "$line" | awk '{print $2}')
    sus_cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
    [[ "$sus_pid" == "$MY_PID" || "$sus_pid" == "$MY_PPID" ]] && continue
    echo -e "  ${RED}PID ${sus_pid}: ${sus_cmd}${RST}"
    kill -9 "$sus_pid" 2>/dev/null || true
done < <(ps aux | grep -E 'nc[[:space:]].*-[ec]|ncat[[:space:]]|bash.*\/dev\/tcp|sh.*\/dev\/tcp|python.*socket|perl.*socket|ruby.*socket|socat' | grep -v grep || true)

echo -e "${GRN}[+] Killing processes with deleted executables${RST}"
for pid in $(ls -l /proc/*/exe 2>/dev/null | grep '(deleted)' | awk -F'/' '{print $3}'); do
    [[ "$pid" == "$MY_PID" || "$pid" == "$MY_PPID" ]] && continue
    echo -e "  ${RED}PID ${pid} (deleted exe)${RST}"
    kill -9 "$pid" 2>/dev/null || true
done

# ============================================================================
# 8. REMOVE NON-PROTECTED ACCOUNTS
# ============================================================================

echo -e "${GRN}[+] Removing non-protected accounts${RST}"
while IFS=: read -r username _ uid _ _ homedir shell; do
    [[ "$uid" -lt 1000 && "$username" != "root" ]] && continue
    [[ "$shell" == */nologin || "$shell" == */false ]] && continue
    if ! is_protected "$username"; then
        # Kill all processes owned by this user
        PIDS=$(ps -u "$username" -o pid= 2>/dev/null || true)
        if [[ -n "$PIDS" ]]; then
            for pid in $PIDS; do
                [[ "$pid" -eq "$MY_PID" ]] && continue
                kill -9 "$pid" 2>/dev/null || true
            done
        fi
        # Remove from sudo/wheel groups
        gpasswd -d "$username" "$SUDO_GROUP" 2>/dev/null || true
        gpasswd -d "$username" wheel 2>/dev/null || true
        # Delete user and home directory
        userdel -r "$username" 2>/dev/null || {
            userdel "$username" 2>/dev/null || true
            [[ -d "/home/$username" ]] && rm -rf "/home/$username"
        }
        echo -e "  ${RED}${username} removed${RST}"
    fi
done < /etc/passwd

# ============================================================================
# 9. PURGE TEMP DIRECTORIES
# ============================================================================

echo -e "${GRN}[+] Purging temp directories${RST}"
find /tmp /var/tmp /dev/shm -mindepth 1 -delete 2>/dev/null || true
echo -e "${GRAY}  /tmp /var/tmp /dev/shm cleared${RST}"

# ============================================================================
# 10. DISABLE INCLUDE OVERRIDES
# ============================================================================

echo -e "${GRN}[+] Disabling sshd_config.d${RST}"
if [[ -d /etc/ssh/sshd_config.d ]]; then
    for f in /etc/ssh/sshd_config.d/*.conf; do
        [[ -f "$f" ]] && mv "$f" "${f}.disabled"
    done
fi

# ============================================================================
# 11. RESTART SSHD
# ============================================================================

echo -e "${GRN}[+] Restarting sshd${RST}"
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true

# ============================================================================
# 12. VALIDATE
# ============================================================================

echo ""
echo -e "${GRN}[+] Validation${RST}"
sshd -t 2>&1 && echo -e "${GRAY}  sshd_config: OK${RST}" || echo -e "${RED}  sshd_config: FAILED${RST}"
echo -e "${GRAY}  Sessions:${RST}"
who 2>/dev/null || echo -e "${GRAY}  (none)${RST}"

echo ""
echo -e "${BOLD}=========================================${RST}"
echo -e "${GRN}${BOLD}  LOCKDOWN COMPLETE${RST}"
echo -e "${BOLD}=========================================${RST}"
echo ""
echo -e "${YEL}[!] Take a VM snapshot now!${RST}"
echo -e "${GRAY}    This locks in your hardened state for quick recovery${RST}"
echo -e "${GRAY}    if the red team breaks something later.${RST}"