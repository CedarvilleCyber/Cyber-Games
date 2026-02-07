#!/bin/bash
#
# 07 - Log Monitoring & Intrusion Detection
# Deploy Falco (runtime detection) + AIDE (file integrity) + ntfy alerts
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/07_log_monitoring.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  LOG MONITORING & INTRUSION DETECTION"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

HOST=$(hostname)

# ── Configuration ────────────────────────────────────────────────────────────
# ntfy settings — override with env vars or will prompt
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

if [[ -z "${NTFY_TOPIC:-}" ]]; then
    echo ""
    read -rp "[?] ntfy topic name (e.g., blueteam-alerts): " NTFY_TOPIC
    echo ""
fi

NTFY_URL="${NTFY_SERVER}/${NTFY_TOPIC}"

echo "[*] Configuration:"
echo "    Host: ${HOST}"
echo "    ntfy: ${NTFY_URL}"
echo ""

# ============================================================================
# PHASE 1: inotifywait File Watcher (instant alerts for critical file changes)
# ============================================================================
echo "[1] Deploying inotifywait file watcher"

apt-get install -y -qq inotify-tools > /dev/null 2>&1 || {
    echo "    [!] inotify-tools install failed — may already be present"
}

# Create the watcher script
cat > /usr/local/bin/hids-filewatcher.sh << WATCHEOF
#!/bin/bash
NTFY_URL="${NTFY_URL}"
HOST="${HOST}"

# Critical files and directories to watch
WATCH_FILES="/etc/passwd /etc/shadow /etc/sudoers /etc/ssh/sshd_config /etc/crontab"
WATCH_DIRS="/etc/cron.d /root/.ssh /etc/sudoers.d /etc/systemd/system /etc/pam.d"

# Build watch list (only include paths that exist)
TARGETS=""
for p in \$WATCH_FILES \$WATCH_DIRS; do
    [[ -e "\$p" ]] && TARGETS="\$TARGETS \$p"
done

inotifywait -m -e modify,create,delete,move,attrib \$TARGETS 2>/dev/null | \\
while read dir event file; do
    MSG="[\${HOST}] \${event}: \${dir}\${file}"
    curl -sf \\
        -H "Title: File Change on \${HOST}" \\
        -H "Priority: high" \\
        -H "Tags: warning,file_folder" \\
        -d "\${MSG}" \\
        "\${NTFY_URL}" &>/dev/null &
done
WATCHEOF
chmod +x /usr/local/bin/hids-filewatcher.sh

# Create systemd service
cat > /etc/systemd/system/hids-filewatcher.service << 'SVCEOF'
[Unit]
Description=HIDS File Watcher (inotifywait + ntfy)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hids-filewatcher.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable --now hids-filewatcher.service > /dev/null 2>&1

echo "    -> File watcher active (instant alerts to ntfy)"

# ============================================================================
# PHASE 2: Falco Runtime Detection
# ============================================================================
echo "[2] Installing Falco"

# Add Falco repository
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc 2>/dev/null | \
    gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg 2>/dev/null

echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" \
    > /etc/apt/sources.list.d/falcosecurity.list

apt-get update -qq > /dev/null 2>&1
FALCO_FRONTEND=noninteractive apt-get install -y -qq falco > /dev/null 2>&1

echo "    -> Falco installed"

echo "[3] Configuring Falco outputs"

mkdir -p /var/log/falco

# Create ntfy forwarder script
cat > /usr/local/bin/falco-ntfy.sh << FALCOSCRIPT
#!/bin/bash
# Reads JSON alert lines from Falco on stdin, forwards to ntfy
NTFY_URL="${NTFY_URL}"
HOST="${HOST}"

while read -r line; do
    RULE=\$(echo "\$line" | jq -r '.rule // "Unknown Rule"' 2>/dev/null)
    OUTPUT=\$(echo "\$line" | jq -r '.output // "No details"' 2>/dev/null)
    PRIO=\$(echo "\$line" | jq -r '.priority // "Warning"' 2>/dev/null)

    # Map Falco priority → ntfy priority
    case "\$PRIO" in
        Critical)   NTFY_PRI="urgent" ;;
        Error)      NTFY_PRI="high" ;;
        Warning)    NTFY_PRI="default" ;;
        *)          NTFY_PRI="low" ;;
    esac

    curl -sf \\
        -H "Title: Falco [\${HOST}]: \${RULE}" \\
        -H "Priority: \${NTFY_PRI}" \\
        -H "Tags: rotating_light,shield" \\
        -d "\${OUTPUT}" \\
        "\${NTFY_URL}" &>/dev/null &
done
FALCOSCRIPT
chmod +x /usr/local/bin/falco-ntfy.sh

# Falco config overrides
mkdir -p /etc/falco/config.d

cat > /etc/falco/config.d/competition.yaml << 'FALCOCONF'
# Competition overrides
json_output: true
json_include_output_property: true
json_include_tags_property: true
buffered_outputs: false
time_format_iso_8601: true

# Log to file (for later analysis / Gravwell ingestion)
file_output:
  enabled: true
  keep_alive: true
  filename: /var/log/falco/events.log

# Pipe to ntfy forwarder script
program_output:
  enabled: true
  keep_alive: true
  program: /usr/local/bin/falco-ntfy.sh

# Syslog output (backup)
syslog_output:
  enabled: true

# Stdout for debugging
stdout_output:
  enabled: false

# Log level
log_level: warning
FALCOCONF

echo "    -> Falco configured for JSON output + ntfy"

echo "[4] Installing competition Falco rules"

cat > /etc/falco/rules.d/competition.yaml << 'COMPETITIONRULES'
# ============================================================================
# Competition-specific Falco rules
# ============================================================================

# ── Reverse shell detection ─────────────────────────────────────────────────
- rule: Reverse Shell Detected
  desc: Detects shell process with stdin/stdout connected to network socket
  condition: >
    spawned_process and
    proc.name in (bash, sh, dash, zsh, csh, ksh, fish) and
    (fd.type=ipv4 or fd.type=ipv6) and
    fd.direction=out
  output: >
    Reverse shell detected (user=%user.name command=%proc.cmdline
    connection=%fd.name container=%container.name pid=%proc.pid)
  priority: CRITICAL
  tags: [competition, network, reverse_shell]

# ── Common attacker tools ────────────────────────────────────────────────────
- rule: Attacker Recon Tool Executed
  desc: Detects execution of common attacker reconnaissance and exploitation tools
  condition: >
    spawned_process and
    proc.name in (nmap, masscan, nikto, gobuster, dirb, dirbuster, ffuf,
                  sqlmap, hydra, john, hashcat, msfconsole, msfvenom,
                  metasploit, mimikatz, linpeas, linenum, pspy)
  output: >
    Attacker tool executed (user=%user.name tool=%proc.name
    cmdline=%proc.cmdline pid=%proc.pid ppid=%proc.ppid pname=%proc.pname)
  priority: CRITICAL
  tags: [competition, recon, attacker_tool]

# ── Webshell indicators ─────────────────────────────────────────────────────
- rule: Shell Spawned from Web Server
  desc: Shell process spawned by web server — strong webshell indicator
  condition: >
    spawned_process and
    proc.name in (bash, sh, dash, zsh, csh) and
    proc.pname in (apache2, httpd, nginx, php-fpm, php-cgi, php,
                   node, python, python3, ruby, java, tomcat)
  output: >
    Web server spawned shell — possible webshell
    (user=%user.name shell=%proc.name parent=%proc.pname
    cmdline=%proc.cmdline pid=%proc.pid)
  priority: CRITICAL
  tags: [competition, webshell]

# ── Cron persistence ─────────────────────────────────────────────────────────
- rule: Crontab Modified
  desc: Detects writes to crontab files or cron directories
  condition: >
    (open_write) and
    (fd.name startswith /etc/cron or
     fd.name startswith /var/spool/cron or
     fd.name = /etc/crontab)
  output: >
    Crontab modification detected (user=%user.name file=%fd.name
    command=%proc.cmdline pid=%proc.pid)
  priority: ERROR
  tags: [competition, persistence, cron]

# ── SSH authorized_keys tampering ────────────────────────────────────────────
- rule: SSH Authorized Keys Modified
  desc: Detects writes to any authorized_keys file
  condition: >
    open_write and fd.name endswith authorized_keys
  output: >
    authorized_keys modified (user=%user.name file=%fd.name
    command=%proc.cmdline pid=%proc.pid)
  priority: CRITICAL
  tags: [competition, persistence, ssh]

# ── Systemd service persistence ──────────────────────────────────────────────
- rule: New Systemd Service Created
  desc: Detects creation of new systemd service files
  condition: >
    ((open_write) and
     (fd.name startswith /etc/systemd/system or
      fd.name startswith /usr/lib/systemd/system or
      fd.name startswith /lib/systemd/system) and
     fd.name endswith .service) and
    not proc.name in (systemctl, dpkg, apt, apt-get, yum, dnf, rpm)
  output: >
    New systemd service created (user=%user.name file=%fd.name
    command=%proc.cmdline pid=%proc.pid)
  priority: ERROR
  tags: [competition, persistence, systemd]

# ── User/group modifications ────────────────────────────────────────────────
- rule: User Account Created or Modified
  desc: Detects user creation or modification
  condition: >
    spawned_process and
    proc.name in (useradd, usermod, adduser, userdel, deluser,
                  groupadd, groupmod, gpasswd, chpasswd)
  output: >
    User/group modification (user=%user.name command=%proc.cmdline pid=%proc.pid)
  priority: ERROR
  tags: [competition, user_management]

# ── Suspicious file downloads ───────────────────────────────────────────────
- rule: Suspicious Download Tool Execution
  desc: wget/curl downloading to /tmp or other writable directories
  condition: >
    spawned_process and
    proc.name in (wget, curl) and
    (proc.cmdline contains /tmp or
     proc.cmdline contains /dev/shm or
     proc.cmdline contains /var/tmp)
  output: >
    Suspicious download to writable dir (user=%user.name
    cmdline=%proc.cmdline pid=%proc.pid)
  priority: WARNING
  tags: [competition, download]

# ── Kernel module loading ────────────────────────────────────────────────────
- rule: Kernel Module Loaded
  desc: Detects loading of kernel modules (rootkit indicator)
  condition: >
    spawned_process and
    proc.name in (insmod, modprobe) and
    not proc.pname in (systemd, systemd-modules, kmod)
  output: >
    Kernel module loaded (user=%user.name command=%proc.cmdline
    pid=%proc.pid parent=%proc.pname)
  priority: CRITICAL
  tags: [competition, rootkit, kernel]

# ── Netcat listener ─────────────────────────────────────────────────────────
- rule: Netcat Listener Started
  desc: nc/ncat started in listen mode (bind shell)
  condition: >
    spawned_process and
    proc.name in (nc, ncat, nmap, socat) and
    (proc.cmdline contains "-l" or proc.cmdline contains "LISTEN")
  output: >
    Netcat listener started — possible bind shell (user=%user.name
    cmdline=%proc.cmdline pid=%proc.pid)
  priority: CRITICAL
  tags: [competition, bind_shell]

# ── Sensitive file read ─────────────────────────────────────────────────────
- rule: Sensitive File Read by Non-Root
  desc: Non-root users reading shadow, gshadow, or SSL private keys
  condition: >
    open_read and
    (fd.name = /etc/shadow or
     fd.name = /etc/gshadow or
     fd.name startswith /etc/ssl/private) and
    user.name != root
  output: >
    Sensitive file read by non-root (user=%user.name file=%fd.name
    command=%proc.cmdline pid=%proc.pid)
  priority: ERROR
  tags: [competition, credential_access]

# ── Base64 encoding (possible obfuscation) ──────────────────────────────────
- rule: Base64 Encoding Detected
  desc: Detects base64 encoding commands (common in obfuscation)
  condition: >
    spawned_process and
    proc.name in (base64, base32, xxd, openssl) and
    (proc.cmdline contains "-e" or proc.cmdline contains "enc" or proc.cmdline contains "encode")
  output: >
    Base64 encoding detected (user=%user.name cmdline=%proc.cmdline pid=%proc.pid)
  priority: WARNING
  tags: [competition, obfuscation]
COMPETITIONRULES

echo "    -> Competition rules installed (12 custom rules)"

echo "[5] Starting Falco"

# Try modern eBPF driver first, fall back to kmod
if falco --modern-bpf --version > /dev/null 2>&1; then
    systemctl enable --now falco-modern-bpf > /dev/null 2>&1 && \
        echo "    -> Falco running (modern eBPF driver)" || {
        echo "    [!] modern-bpf failed, trying default..."
        systemctl enable --now falco > /dev/null 2>&1 && \
            echo "    -> Falco running (default driver)" || \
            echo "    [!] Falco failed to start — check: journalctl -u falco"
    }
else
    systemctl enable --now falco > /dev/null 2>&1 && \
        echo "    -> Falco running (kernel module driver)" || \
        echo "    [!] Falco failed to start — check: journalctl -u falco"
fi

# ============================================================================
# PHASE 3: AIDE File Integrity Monitoring
# ============================================================================
echo "[6] Installing AIDE"

apt-get install -y -qq aide > /dev/null 2>&1
echo "    -> AIDE installed"

echo "[7] Configuring AIDE"

cat > /etc/aide/aide.conf.d/90_competition << 'AIDECONF'
# Competition AIDE rules — focused on attack-relevant paths

# Define check groups
COMPETITION = p+i+n+u+g+s+md5+sha256

# Critical system files
/etc/passwd       COMPETITION
/etc/shadow       COMPETITION
/etc/group        COMPETITION
/etc/gshadow      COMPETITION
/etc/sudoers      COMPETITION
/etc/sudoers.d    COMPETITION
/etc/ssh          COMPETITION
/etc/pam.d        COMPETITION
/etc/crontab      COMPETITION
/etc/cron.d       COMPETITION
/etc/cron.daily   COMPETITION
/etc/cron.hourly  COMPETITION
/etc/systemd/system COMPETITION
/etc/ld.so.preload COMPETITION
/etc/ld.so.conf.d  COMPETITION

# System binaries
/usr/bin          COMPETITION
/usr/sbin         COMPETITION
/bin              COMPETITION
/sbin             COMPETITION
/usr/local/bin    COMPETITION
/usr/local/sbin   COMPETITION

# Web roots
/var/www          COMPETITION

# Root home
/root             COMPETITION

# Skip noisy directories
!/proc
!/sys
!/dev
!/run
!/tmp
!/var/log
!/var/cache
!/var/lib/apt
!/var/lib/dpkg
AIDECONF

echo "    -> AIDE configured"

echo "[8] Initializing AIDE baseline (background)"

# Run in background — takes 1-5 minutes
(
    aideinit > /dev/null 2>&1
    if [[ -f /var/lib/aide/aide.db.new ]]; then
        cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        echo "    -> AIDE baseline ready"
    fi
) &

AIDE_PID=$!
echo "    -> AIDE baseline building (PID ${AIDE_PID})"

# Create AIDE check script with ntfy integration
cat > /usr/local/bin/aide-check-ntfy.sh << AIDESCRIPT
#!/bin/bash
NTFY_URL="${NTFY_URL}"
HOST="${HOST}"
LOGFILE="/var/log/aide-check.log"

# Run the check
aide --check > "\${LOGFILE}" 2>&1
EXIT_CODE=\$?

if [[ \$EXIT_CODE -ne 0 ]]; then
    # AIDE found changes
    SUMMARY=\$(grep -E "^(Added|Removed|Changed):" "\${LOGFILE}" | head -10)
    CHANGED_FILES=\$(grep -E "^(f|d|l)" "\${LOGFILE}" | awk '{print \$2}' | head -20)

    MSG="AIDE detected filesystem changes on \${HOST}:\n\n\${SUMMARY}\n\nFiles:\n\${CHANGED_FILES}"

    curl -sf \\
        -H "Title: AIDE Alert [\${HOST}]" \\
        -H "Priority: high" \\
        -H "Tags: mag,warning" \\
        -d "\${MSG}" \\
        "\${NTFY_URL}" &>/dev/null
fi
AIDESCRIPT
chmod +x /usr/local/bin/aide-check-ntfy.sh

# Add cron job
cat > /etc/cron.d/aide-competition << 'CRONEOF'
# Run AIDE integrity check every 10 minutes during competition
*/10 * * * * root /usr/local/bin/aide-check-ntfy.sh
CRONEOF

echo "    -> AIDE cron job installed (checks every 10 minutes)"

# ============================================================================
# PHASE 4: Verification & Test Alert
# ============================================================================
echo ""
echo "========================================="
echo "  DEPLOYMENT SUMMARY"
echo "========================================="
echo ""

# Check services
if systemctl is-active --quiet hids-filewatcher 2>/dev/null; then
    echo "[+] File Watcher: RUNNING"
else
    echo "[-] File Watcher: NOT RUNNING"
fi

if systemctl is-active --quiet falco-modern-bpf 2>/dev/null; then
    echo "[+] Falco (eBPF): RUNNING"
elif systemctl is-active --quiet falco 2>/dev/null; then
    echo "[+] Falco: RUNNING"
else
    echo "[-] Falco: NOT RUNNING"
fi

if [[ -f /var/lib/aide/aide.db ]]; then
    echo "[+] AIDE baseline: READY"
elif kill -0 "$AIDE_PID" 2>/dev/null; then
    echo "[*] AIDE baseline: BUILDING (PID ${AIDE_PID})"
else
    echo "[!] AIDE baseline: CHECK MANUALLY"
fi

echo ""
echo "Sending test alert to ntfy..."
curl -sf \
    -H "Title: HIDS Deployed [${HOST}]" \
    -H "Priority: default" \
    -H "Tags: white_check_mark,shield" \
    -d "Log monitoring active on ${HOST}" \
    "${NTFY_URL}" > /dev/null 2>&1 && echo "[+] Test alert sent" || echo "[!] Test alert failed"

echo ""
echo "========================================="
echo "  LOG MONITORING ACTIVE"
echo "========================================="
echo ""
echo "ntfy topic: ${NTFY_URL}"
echo ""
echo "Useful commands:"
echo "  Falco events:  tail -f /var/log/falco/events.log"
echo "  Falco logs:    journalctl -u falco -f"
echo "  AIDE check:    /usr/local/bin/aide-check-ntfy.sh"
echo "  AIDE rebase:   aideinit && cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db"
echo "  File watcher:  journalctl -u hids-filewatcher -f"
echo ""
echo "Subscribe to alerts:"
echo "  Phone: Install ntfy app → subscribe to ${NTFY_TOPIC}"
echo "  Browser: https://ntfy.sh/${NTFY_TOPIC}"
echo "  Filter high-priority: ?priority=high,urgent"
echo ""
echo "To add centralized logging, run: @gravwell_setup.sh"
