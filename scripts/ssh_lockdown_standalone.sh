#!/bin/bash
#
# SELF-CONTAINED SSH Lockdown — paste into Proxmox console, no files needed.
# Usage: sudo bash (then paste), or: echo '<base64>' | base64 -d | sudo bash
#

set -euo pipefail

# ============================================================================
# EMBEDDED DATA — no external files required
# ============================================================================

SCORING_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcM4aDj8Y4COv+f8bd2WsrIynlbRGgDj2+q9aBeW1Umj5euxnO1vWsjfkpKnyE/ORsI6gkkME9ojAzNAPquWMh2YG+n11FB1iZl2S6yuZB7dkVQZSKpVYwRvZv2RnYDQdcVnX9oWMiGrBWEAi4jxcYykz8nunaO2SxjEwzuKdW8lnnh2BvOO9RkzmSXIIdPYgSf8bFFC7XFMfRrlMXlsxbG3u/NaFjirfvcXKexz06L6qYUzob8IBPsKGaRjO+vEdg6B4lH1lMk1JQ4GtGOJH6zePfB6Gf7rp31261VRfkpbpaDAznTzh7bgpq78E7SenatNbezLDaGq3Zra3j53u7XaSVipkW0S3YcXczhte2J9kvo6u6s094vrcQfB9YigH4KhXpCErFk08NkYAEJDdqFqXIjvzsro+2/EW1KKB9aNPSSM9EZzhYc+cBAl4+ohmEPej1m15vcpw3k+kpo1NC2rwEXIFxmvTme1A2oIZZBpgzUqfmvSPwLXF0EyfN9Lk= SCORING KEY DO NOT REMOVE"

KIERAN_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0= me@dunkirk.sh"

SCORING_USERS=(
    alexander_hamilton archimedes aristotle benjamin_franklin
    charles_darwin eleanor_roosevelt florence_nightingale friedrich_nietzsche
    hippocrates immanuel_kant jean_jacques_rousseau john_adams
    louis_xiv mahatma_gandhi marie_antoinette mother_teresa
    peter_the_great plato rene_descartes sigmund_freud
    socrates theodore_roosevelt voltaire winston_churchill
)

PROTECTED_USERS=(
    "blackteam"
    "blueteam"
    "root"
)

# Additional allowed SSH users — fill in before comp
ALLOWED_USERS=(
    # "alice"
    # "bob"
)

# ============================================================================
# PRE-FLIGHT
# ============================================================================

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_SUFFIX=".bak.$(date +%s)"

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

ALL_PROTECTED=("${PROTECTED_USERS[@]}" "${ALLOWED_USERS[@]}" "${SCORING_USERS[@]}")

is_protected() {
    local check="$1"
    for u in "${ALL_PROTECTED[@]}"; do
        [[ "$u" == "$check" ]] && return 0
    done
    return 1
}

echo "========================================="
echo "  SSH LOCKDOWN (STANDALONE)"
echo "========================================="
echo "[*] Protected users: ${ALL_PROTECTED[*]}"
echo ""

# ============================================================================
# 1. CREATE BLUETEAM USER & SET PASSWORDS
# ============================================================================

echo "[1] Setting up blueteam user and passwords"

read -sp "    Enter password for root: " ROOT_PW
echo ""
read -sp "    Enter password for blueteam: " BLUETEAM_PW
echo ""

if ! id "blueteam" &>/dev/null; then
    useradd -m -s /bin/bash blueteam
    echo "    -> Created blueteam user"
fi

SUDO_GROUP="sudo"
grep -q "^wheel:" /etc/group && SUDO_GROUP="wheel"

usermod -aG "$SUDO_GROUP" blueteam 2>/dev/null || true
echo "    -> blueteam added to $SUDO_GROUP"

echo "root:${ROOT_PW}" | chpasswd
echo "    -> root password set"
echo "blueteam:${BLUETEAM_PW}" | chpasswd
echo "    -> blueteam password set"

unset ROOT_PW BLUETEAM_PW

# ============================================================================
# 2. BACKUP
# ============================================================================

echo "[2] Backing up $SSHD_CONFIG"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}${BACKUP_SUFFIX}"

# ============================================================================
# 3. HARDENED sshd_config
# ============================================================================

echo "[3] Writing hardened sshd_config"
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
ChallengeResponseAuthentication no
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

Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

Subsystem sftp /usr/lib/openssh/sftp-server
SSHD_EOF

ALLOW_LINE="AllowUsers"
for u in "${ALL_PROTECTED[@]}"; do
    ALLOW_LINE+=" $u"
done
echo "$ALLOW_LINE" >> "$SSHD_CONFIG"
echo "    -> $ALLOW_LINE"

# ============================================================================
# 4. SUDOERS CLEANUP
# ============================================================================

echo "[4] Cleaning sudoers"

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
    echo "    -> /etc/sudoers replaced (root + %${SUDO_GROUP} only)"
else
    echo "    -> WARNING: generated sudoers invalid, keeping original"
fi
rm -f /tmp/sudoers.new

echo "[4b] Wiping /etc/sudoers.d/"
if [[ -d /etc/sudoers.d ]]; then
    for f in /etc/sudoers.d/*; do
        [[ -f "$f" ]] && mv "$f" "${f}.disabled" && echo "    -> Disabled: $f"
    done
fi

echo "[4c] Removing non-protected users from ${SUDO_GROUP} group"
for member in $(getent group "$SUDO_GROUP" | cut -d: -f4 | tr ',' ' '); do
    if [[ "$member" != "root" && "$member" != "blueteam" && "$member" != "blackteam" ]]; then
        gpasswd -d "$member" "$SUDO_GROUP" 2>/dev/null || true
        echo "    -> Removed $member from $SUDO_GROUP"
    else
        echo "    -> Keeping $member in $SUDO_GROUP"
    fi
done

# ============================================================================
# 5. NUKE UNAUTHORIZED KEYS
# ============================================================================

echo "[5] Cleaning unauthorized SSH keys"
for homedir in /home/*/; do
    username=$(basename "$homedir")
    rm -f "$homedir/.ssh/authorized_keys2"
    if ! is_protected "$username"; then
        rm -rf "$homedir/.ssh"
        echo "    -> Wiped .ssh for $username"
    fi
done
rm -f /root/.ssh/authorized_keys2
rm -f /etc/ssh/authorized_keys /etc/ssh/authorized_keys2

echo "[5b] Removing planted private keys (skipping protected users)"
for homedir in /root /home/*; do
    [[ -d "$homedir" ]] || continue
    username=$(basename "$homedir")
    if is_protected "$username"; then
        echo "    -> Skipping $username (protected)"
        continue
    fi
    find "$homedir" -type f \( -name "id_rsa*" -o -name "id_ed25519*" -o -name "id_ecdsa*" -o -name "id_dsa*" \) 2>/dev/null | while read -r keyfile; do
        echo "    -> Removing: $keyfile"
        rm -f "$keyfile"
    done
done

# ============================================================================
# 6. DEPLOY KEYS (inline — no files needed)
# ============================================================================

echo "[6] Deploying keys"

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
        echo "    -> $user: scoring key"
    fi
done

add_key_inline "$KIERAN_KEY" "blueteam"
echo "    -> blueteam: kieran key"

# ============================================================================
# 7. KILL NON-PROTECTED SESSIONS & REVERSE SHELLS
# ============================================================================

echo "[7] Killing non-protected sessions"
MY_PID=$$
MY_PPID=$(ps -o ppid= -p $MY_PID | tr -d ' ')

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    sess_user=$(echo "$line" | awk '{print $1}')
    sess_pid=$(echo "$line" | awk '{print $2}')
    [[ "$sess_pid" == "$MY_PID" || "$sess_pid" == "$MY_PPID" ]] && continue
    if ! is_protected "$sess_user"; then
        echo "    -> KILL $sess_user (PID $sess_pid)"
        kill -9 "$sess_pid" 2>/dev/null || true
    fi
done < <(ps aux | grep '[s]shd.*@' || true)

echo "[7b] Killing reverse shells and suspicious processes"
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    sus_pid=$(echo "$line" | awk '{print $2}')
    sus_cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
    [[ "$sus_pid" == "$MY_PID" || "$sus_pid" == "$MY_PPID" ]] && continue
    echo "    -> KILL PID $sus_pid: $sus_cmd"
    kill -9 "$sus_pid" 2>/dev/null || true
done < <(ps aux | grep -E 'nc[[:space:]].*-[ec]|ncat[[:space:]]|bash.*\/dev\/tcp|sh.*\/dev\/tcp|python.*socket|perl.*socket|ruby.*socket|socat' | grep -v grep || true)

echo "[7c] Killing processes with deleted executables"
for pid in $(ls -l /proc/*/exe 2>/dev/null | grep '(deleted)' | awk -F'/' '{print $3}'); do
    [[ "$pid" == "$MY_PID" || "$pid" == "$MY_PPID" ]] && continue
    echo "    -> KILL deleted-exe PID: $pid"
    kill -9 "$pid" 2>/dev/null || true
done

# ============================================================================
# 8. LOCK NON-PROTECTED ACCOUNTS
# ============================================================================

echo "[8] Locking non-protected accounts"
while IFS=: read -r username _ uid _ _ homedir shell; do
    [[ "$uid" -lt 1000 && "$username" != "root" ]] && continue
    [[ "$shell" == */nologin || "$shell" == */false ]] && continue
    if ! is_protected "$username"; then
        passwd -l "$username" 2>/dev/null || true
        usermod -s /sbin/nologin "$username" 2>/dev/null || true
        echo "    -> Locked $username"
    fi
done < /etc/passwd

# ============================================================================
# 9. DISABLE INCLUDE OVERRIDES
# ============================================================================

echo "[9] Disabling sshd_config.d"
if [[ -d /etc/ssh/sshd_config.d ]]; then
    for f in /etc/ssh/sshd_config.d/*.conf; do
        [[ -f "$f" ]] && mv "$f" "${f}.disabled"
    done
fi

# ============================================================================
# 10. RESTART SSHD
# ============================================================================

echo "[10] Restarting sshd"
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true

# ============================================================================
# 11. VALIDATE
# ============================================================================

echo ""
echo "[11] Validation"
sshd -t 2>&1 && echo "    sshd_config: OK" || echo "    sshd_config: FAILED"
echo "    Sessions:"
who 2>/dev/null || echo "    (none)"
grep "^AllowUsers" "$SSHD_CONFIG"

# ============================================================================
# 12. SECURITY AUDIT
# ============================================================================

echo ""
echo "[12] Security audit"

echo "    UID 0 accounts (only root should exist):"
awk -F: '$3 == 0 {print "       " $1}' /etc/passwd

echo "    SUID files in temp directories:"
SUID_TEMP=$(find /tmp /var/tmp /dev/shm -perm -4000 -type f 2>/dev/null)
if [[ -n "$SUID_TEMP" ]]; then
    echo "$SUID_TEMP" | while read -r f; do
        echo "       [!] $f"
        rm -f "$f"
        echo "           REMOVED"
    done
else
    echo "       (clean)"
fi

echo "    Listening ports:"
ss -tulpn 2>/dev/null | grep LISTEN | awk '{printf "       %s %s\n", $5, $7}' | sort -u

echo ""
echo "========================================="
echo "  LOCKDOWN COMPLETE"
echo "========================================="
