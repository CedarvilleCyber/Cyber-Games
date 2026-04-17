#!/bin/bash
#
# @fruit.sh - Service config audit
# Adapted from DSU-DefSec/cyber (https://github.com/DSU-DefSec/cyber)
# Checks for vulnerable misconfigurations in common service config files
# Usage: sudo ./fruit.sh [service ...]   (default: all)
#        e.g.: sudo ./fruit.sh openssh vsftpd
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

COUNT_CRIT=0
COUNT_HIGH=0
COUNT_MED=0

# ============================================================================
# CONFIG LOADING
# ============================================================================

BODY=""
_VAL=""

load_configs() {
    BODY=""
    local f pat found=1
    shopt -s nullglob
    for pat in "$@"; do
        for f in $pat; do
            [[ -f "$f" ]] || continue
            BODY+=$'\n'"$(cat "$f" 2>/dev/null)"
            found=0
        done
    done
    shopt -u nullglob
    return $found
}

get_dir() {
    _VAL=$(printf '%s\n' "$BODY" \
        | grep -iE "^[[:space:]]*$1[[:space:]]+" | grep -v '^[[:space:]]*#' | head -1 \
        | sed -E "s/^[[:space:]]*$1[[:space:]]+//i; s/[[:space:]]*#.*//; s/['\"]//g" \
        | xargs 2>/dev/null) || true
}

get_eq() {
    _VAL=$(printf '%s\n' "$BODY" \
        | grep -iE "^[[:space:]]*$1[[:space:]]*=" | grep -v '^[[:space:]]*#' | head -1 \
        | sed -E "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//i; s/[[:space:]]*#.*//; s/['\"]//g" \
        | xargs 2>/dev/null) || true
}

body_has() { printf '%s\n' "$BODY" | grep -qiE "$1"; }

hit() {
    local sev="$1" msg="$2" fix="$3"
    case "$sev" in
        CRITICAL) echo -e "  ${RED}${BOLD}[CRITICAL]${RST} $msg" ;;
        HIGH)     echo -e "  ${RED}[HIGH]${RST}     $msg" ;;
        MEDIUM)   echo -e "  ${YEL}[MEDIUM]${RST}   $msg" ;;
    esac
    echo -e "             ${GRAY}fix: $fix${RST}"
    case "$sev" in
        CRITICAL) COUNT_CRIT=$((COUNT_CRIT+1)) ;;
        HIGH)     COUNT_HIGH=$((COUNT_HIGH+1)) ;;
        MEDIUM)   COUNT_MED=$((COUNT_MED+1)) ;;
    esac
}

# ============================================================================
# SERVICE CHECKS
# ============================================================================

check_apache2() {
    load_configs \
        '/etc/apache2/apache2.conf' '/etc/apache2/conf-enabled/*.conf' \
        '/etc/apache2/sites-enabled/*.conf' '/etc/httpd/conf/httpd.conf' \
        '/etc/httpd/conf.d/*.conf' || { echo -e "${GRAY}  (not installed)${RST}"; return; }
    local proto clean

    body_has 'Options[[:space:]][^#]*\bIndexes\b' && \
        hit HIGH 'Directory listing enabled (Options Indexes)' \
            'remove "Indexes" from all Options directives'

    if body_has 'Options[[:space:]][^#]*\bFollowSymLinks\b' && \
       ! body_has 'Options[[:space:]][^#]*\bSymLinksIfOwnerMatch\b'; then
        hit MEDIUM 'FollowSymLinks without SymLinksIfOwnerMatch (docroot escape risk)' \
            'replace FollowSymLinks with SymLinksIfOwnerMatch'
    fi

    body_has '^[[:space:]]*AllowOverride[[:space:]]+All\b' && \
        hit MEDIUM 'AllowOverride All - .htaccess can override security rules' \
            'AllowOverride None  (or only the directives you need)'

    get_dir TraceEnable
    [[ -z "$_VAL" || "${_VAL,,}" != off ]] && \
        hit MEDIUM 'HTTP TRACE enabled (XST cookie theft)' \
            'TraceEnable Off'

    for proto in SSLv2 SSLv3 'TLSv1 ' 'TLSv1\.1'; do
        body_has "SSLProtocol[[:space:]][^#]*${proto}" || continue
        clean="${proto// /}"
        hit HIGH "Weak TLS protocol permitted: $clean" \
            'SSLProtocol TLSv1.2 TLSv1.3'
    done

    if body_has '<Location[[:space:]][^>]*/server-status' && \
       ! body_has 'Require[[:space:]]+(ip|local|host)'; then
        hit HIGH '/server-status exposed without IP restriction' \
            'add "Require ip 127.0.0.1" inside the <Location /server-status>'
    fi

    body_has 'Options[[:space:]][^#]*\bExecCGI\b' && \
        hit HIGH 'Options ExecCGI enabled - CGI execution allowed (RCE if writable)' \
            'Remove ExecCGI from Options; use ScriptAlias only for trusted CGI dirs'

    body_has 'Options[[:space:]][^#]*\bIncludes\b' && \
        hit HIGH 'Options Includes enabled - SSI exec directives allowed (RCE vector)' \
            'Remove Includes from Options; use IncludesNOEXEC if SSI output is needed'
}

check_nginx() {
    load_configs \
        '/etc/nginx/nginx.conf' '/etc/nginx/conf.d/*.conf' \
        '/etc/nginx/sites-enabled/*.conf' || { echo -e "${GRAY}  (not installed)${RST}"; return; }

    body_has '^[[:space:]]*autoindex[[:space:]]+on[[:space:]]*;' && \
        hit HIGH 'Directory listing enabled (autoindex on)' \
            'autoindex off;'

    local proto_line proto clean
    proto_line=$(printf '%s\n' "$BODY" | grep -iE 'ssl_protocols[[:space:]]+' | head -1)
    if [[ -n "$proto_line" ]]; then
        for proto in SSLv2 SSLv3 'TLSv1 ' 'TLSv1\.1'; do
            printf '%s\n' "$proto_line" | grep -qiE "$proto" || continue
            clean="${proto// /}"
            hit HIGH "Weak TLS protocol in ssl_protocols: $clean" \
                'ssl_protocols TLSv1.2 TLSv1.3;'
        done
    fi

    local cipher
    for cipher in RC4 '3DES' 'NULL' EXPORT aNULL ADH; do
        body_has "ssl_ciphers[^;]*${cipher}" || continue
        hit HIGH "Weak cipher group in ssl_ciphers: $cipher" \
            'ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:!RC4:!3DES:!aNULL;'
        break
    done
}

check_openssh() {
    load_configs '/etc/ssh/sshd_config' '/etc/ssh/sshd_config.d/*.conf' \
        || { echo -e "${GRAY}  (not installed)${RST}"; return; }
    local v c

    get_dir PermitRootLogin; v="${_VAL,,}"
    [[ -z "$v" || ( "$v" != no && "$v" != prohibit-password && "$v" != forced-commands-only ) ]] && \
        hit CRITICAL "Root SSH login permitted (PermitRootLogin=${_VAL:-yes})" \
            'PermitRootLogin no'

    get_dir PermitEmptyPasswords
    [[ "${_VAL,,}" == yes ]] && \
        hit CRITICAL 'Empty passwords permitted over SSH' \
            'PermitEmptyPasswords no'

    get_dir Protocol
    [[ -n "$_VAL" && "$_VAL" == *1* ]] && \
        hit CRITICAL "SSHv1 enabled (Protocol=$_VAL)" \
            'Protocol 2'

    get_dir PasswordAuthentication; v="${_VAL,,}"
    [[ -z "$v" || "$v" == yes ]] && \
        hit HIGH 'Password authentication enabled (brute-force exposure)' \
            'PasswordAuthentication no  (deploy SSH keys)'

    get_dir MaxAuthTries; v="${_VAL:-6}"
    if ! [[ "$v" =~ ^[0-9]+$ ]] || (( v > 4 )); then
        hit MEDIUM "MaxAuthTries=${_VAL:-6} - too many attempts per connection" \
            'MaxAuthTries 3'
    fi

    get_dir Ciphers; v="${_VAL,,}"
    if [[ -n "$v" ]]; then
        for c in arcfour 3des-cbc blowfish-cbc cast128-cbc aes128-cbc aes192-cbc aes256-cbc; do
            [[ "$v" == *"$c"* ]] || continue
            hit HIGH "Weak cipher in SSH Ciphers list: $c" \
                'Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com'
            break
        done
    fi

    body_has '^[[:space:]]*(AllowUsers|AllowGroups)[[:space:]]+' || \
        hit MEDIUM 'No AllowUsers/AllowGroups - every system account can authenticate' \
            'AllowUsers <user1> <user2>'

    get_dir AuthorizedKeysFile
    if [[ -n "$_VAL" && "$_VAL" != ".ssh/authorized_keys" && "$_VAL" != ".ssh/authorized_keys .ssh/authorized_keys2" ]]; then
        hit CRITICAL "Non-standard AuthorizedKeysFile defined: $_VAL" \
            'Remove AuthorizedKeysFile directive to restore default behavior'
    fi

    get_dir AuthorizedKeysCommand
    [[ -n "$_VAL" && "${_VAL,,}" != none ]] && \
        hit CRITICAL "AuthorizedKeysCommand=$_VAL - external program provides authorized keys" \
            'Remove AuthorizedKeysCommand unless intentional; verify the binary is trusted'

    get_dir StrictModes; v="${_VAL,,}"
    [[ "$v" == no ]] && \
        hit CRITICAL 'StrictModes no - SSH accepts world-writable authorized_keys (trivial key injection)' \
            'StrictModes yes'

    get_dir AllowTcpForwarding; v="${_VAL,,}"
    [[ -z "$v" || "$v" == yes ]] && \
        hit HIGH 'AllowTcpForwarding enabled - SSH can be used as TCP tunnel or pivot' \
            'AllowTcpForwarding no'

    get_dir GatewayPorts; v="${_VAL,,}"
    [[ "$v" == yes || "$v" == clientspecified ]] && \
        hit HIGH "GatewayPorts=$_VAL - remote port-forwards accessible on all interfaces" \
            'GatewayPorts no'

    get_dir PermitTunnel; v="${_VAL,,}"
    [[ -n "$v" && "$v" != no ]] && \
        hit HIGH "PermitTunnel=$_VAL - VPN-style tun/tap tunneling allowed over SSH" \
            'PermitTunnel no'

    get_dir HostbasedAuthentication; v="${_VAL,,}"
    [[ "$v" == yes ]] && \
        hit HIGH 'HostbasedAuthentication yes - host-based auth enabled (hostname is spoofable)' \
            'HostbasedAuthentication no'

    get_dir X11Forwarding; v="${_VAL,,}"
    [[ -z "$v" || "$v" == yes ]] && \
        hit MEDIUM 'X11Forwarding enabled - X11 connections can be tunneled over SSH' \
            'X11Forwarding no'

    get_dir UsePAM; v="${_VAL,,}"
    [[ "$v" == no ]] && \
        hit MEDIUM 'UsePAM no - PAM modules bypassed (account lockout and MFA checks skipped)' \
            'UsePAM yes'
}

check_vsftpd() {
    load_configs '/etc/vsftpd.conf' '/etc/vsftpd/vsftpd.conf' \
        || { echo -e "${GRAY}  (not installed)${RST}"; return; }
    local v d

    get_eq anonymous_enable; v="${_VAL^^}"
    [[ -z "$v" || "$v" == YES ]] && \
        hit CRITICAL "Anonymous FTP enabled (anonymous_enable=${_VAL:-YES})" \
            'anonymous_enable=NO'

    get_eq anon_upload_enable
    [[ "${_VAL^^}" == YES ]] && \
        hit CRITICAL 'Anonymous uploads enabled (webshell drop vector)' \
            'anon_upload_enable=NO'

    get_eq anon_mkdir_write_enable
    [[ "${_VAL^^}" == YES ]] && \
        hit HIGH 'Anonymous directory creation enabled' \
            'anon_mkdir_write_enable=NO'

    get_eq chroot_local_user; v="${_VAL^^}"
    [[ -z "$v" || "$v" != YES ]] && \
        hit HIGH 'Local users not chrooted - full FS traversal via FTP' \
            'chroot_local_user=YES'

    get_eq ssl_enable; v="${_VAL^^}"
    if [[ -z "$v" || "$v" != YES ]]; then
        hit HIGH 'SSL/TLS disabled - FTP creds+data in cleartext' \
            'ssl_enable=YES + rsa_cert_file/rsa_private_key_file'
    else
        get_eq allow_anon_ssl
        [[ "${_VAL^^}" == YES ]] && \
            hit MEDIUM 'allow_anon_ssl=YES - SSL for anonymous sessions' \
                'allow_anon_ssl=NO'
        for d in force_local_data_ssl force_local_logins_ssl; do
            get_eq "$d"; v="${_VAL^^}"
            [[ -z "$v" || "$v" != YES ]] && \
                hit MEDIUM "$d not enforced - plaintext fallback" "$d=YES"
        done
    fi
}

get_global_smb() {
    _VAL=$(printf '%s\n' "$BODY" | awk -v key="${1,,}" '
        /^\[global\]/                   { in_g=1; next }
        /^\[[^]]+\]/ && !/^\[global\]/  { in_g=0 }
        in_g {
            line = tolower($0); gsub(/^[[:space:]]+/, "", line)
            if (line ~ ("^" key "[[:space:]]*=")) {
                sub(/^[^=]+=[[:space:]]*/, "", line); sub(/[[:space:]]*#.*$/, "", line)
                print line; exit
            }
        }') || true
}

check_samba() {
    load_configs '/etc/samba/smb.conf' '/etc/smb.conf' \
        || { echo -e "${GRAY}  (not installed)${RST}"; return; }
    local v key

    get_global_smb 'null passwords'; v="${_VAL,,}"
    [[ "$v" == yes || "$v" == true || "$v" == 1 ]] && \
        hit CRITICAL 'null passwords = yes - empty-password accounts accepted' \
            'null passwords = no'

    body_has '^[[:space:]]*guest ok[[:space:]]*=[[:space:]]*yes' && \
        hit HIGH 'guest ok = yes on one or more shares - unauthenticated share access' \
            'guest ok = no  (on every share)'

    get_global_smb 'map to guest'; v="${_VAL,,}"
    [[ "$v" == 'bad user' || "$v" == 'bad password' ]] && \
        hit HIGH "map to guest = $_VAL - failed logins fall back to guest" \
            'map to guest = never'

    get_global_smb 'server signing'; v="${_VAL,,}"
    [[ -z "$v" || "$v" == auto || "$v" == disabled || "$v" == no ]] && \
        hit HIGH "server signing=${_VAL:-auto} - SMB packets MITM-tamperable" \
            'server signing = mandatory'

    for key in 'client min protocol' 'server min protocol'; do
        get_global_smb "$key"; v="${_VAL^^}"
        [[ -z "$v" || "$v" == NT1 || "$v" == LANMAN1 || "$v" == LANMAN2 || "$v" == CORE || "$v" == COREPLUS ]] && \
            hit HIGH "$key=${_VAL:-unset} - SMBv1 (EternalBlue/MS17-010)" \
                "$key = SMB2"
    done

    get_global_smb 'smb encrypt'; v="${_VAL,,}"
    [[ -z "$v" || "$v" == auto || "$v" == disabled || "$v" == no ]] && \
        hit MEDIUM "smb encrypt=${_VAL:-auto} - SMB traffic not end-to-end encrypted" \
            'smb encrypt = required'

    get_global_smb 'restrict anonymous'; v="${_VAL:-0}"
    [[ -z "${_VAL:-}" || "$v" == 0 ]] && \
        hit MEDIUM 'Anonymous share/user enumeration allowed' \
            'restrict anonymous = 2'
}

check_bind() {
    load_configs \
        '/etc/bind/named.conf' '/etc/bind/named.conf.options' \
        '/etc/named.conf' '/etc/named/named.conf' '/etc/named/named.conf.options' \
        || { echo -e "${GRAY}  (not installed)${RST}"; return; }

    if body_has 'recursion[[:space:]]+yes[[:space:]]*;' && \
       ! body_has 'allow-recursion[[:space:]]*\{'; then
        hit CRITICAL 'Open recursive resolver (recursion yes; no allow-recursion)' \
            'allow-recursion { 127.0.0.1; <internal>; };'
    fi

    if body_has 'allow-transfer[[:space:]]*\{[^}]*\bany\b[^}]*\}'; then
        hit CRITICAL 'Zone transfers open to any host (allow-transfer { any; })' \
            'allow-transfer { <secondary_ns_ip>; };'
    elif ! body_has 'allow-transfer[[:space:]]*\{'; then
        hit HIGH 'allow-transfer not configured - may default to open' \
            'allow-transfer { none; };  globally'
    fi

    body_has 'allow-query[[:space:]]*\{' || \
        hit MEDIUM 'allow-query not configured - answers any source' \
            'allow-query { your_network; };'

    body_has 'allow-update[[:space:]]*\{[^}]*\bany\b[^}]*\}' && \
        hit CRITICAL 'Dynamic DNS updates open to any host (allow-update { any; })' \
            'allow-update { none; };  (or restrict to specific DDNS IPs)'

    body_has 'version[[:space:]]*"' || \
        hit MEDIUM 'BIND version string not hidden - reveals exact version via DNS CHAOS query' \
            'Add: version "not disclosed";  inside options { } block'
}

check_postgres() {
    local pg_body="" pg_path="" hba_body="" hba_path="" f pat
    shopt -s nullglob
    for pat in '/etc/postgresql/*/main/postgresql.conf' \
               '/var/lib/pgsql/data/postgresql.conf' \
               '/var/lib/postgresql/*/data/postgresql.conf'; do
        for f in $pat; do [[ -f "$f" ]] && pg_body=$(cat "$f") && pg_path=$f && break 2; done
    done
    for pat in '/etc/postgresql/*/main/pg_hba.conf' \
               '/var/lib/pgsql/data/pg_hba.conf' \
               '/var/lib/postgresql/*/data/pg_hba.conf'; do
        for f in $pat; do [[ -f "$f" ]] && hba_body=$(cat "$f") && hba_path=$f && break 2; done
    done
    shopt -u nullglob

    [[ -z "$pg_body" && -z "$hba_body" ]] && { echo -e "${GRAY}  (not installed)${RST}"; return; }

    local v line parts method trust_lines=() md5_lines=() conn_type db user

    if [[ -n "$pg_body" ]]; then
        BODY="$pg_body"

        get_eq listen_addresses
        [[ "$_VAL" == '*' ]] && \
            hit HIGH "listen_addresses='*' - DB port exposed on every interface" \
                "listen_addresses = 'localhost'"

        get_eq ssl; v="${_VAL,,}"
        [[ -z "$v" || "$v" =~ ^(off|false|0|no)$ ]] && \
            hit HIGH "ssl=${_VAL:-off} - cleartext credentials+data" \
                'ssl = on + ssl_cert_file/ssl_key_file'

        get_eq password_encryption; v="${_VAL,,}"
        [[ "$v" == md5 ]] && \
            hit MEDIUM 'password_encryption = md5 (offline-crackable)' \
                "password_encryption = 'scram-sha-256'"
    fi

    if [[ -n "$hba_body" ]]; then
        BODY="$hba_body"

        while IFS= read -r line; do
            line="${line%%#*}"
            [[ -z ${line//[[:space:]]/} ]] && continue
            read -ra parts <<< "$line"
            (( ${#parts[@]} < 4 )) && continue
            method="${parts[-1],,}"
            [[ "$method" == trust ]] && trust_lines+=("$line")
            [[ "$method" == md5 ]]   && md5_lines+=("$line")
        done < <(printf '%s\n' "$hba_body")

        if (( ${#trust_lines[@]} )); then
            local trust_all=0 tl
            for tl in "${trust_lines[@]}"; do [[ "$tl" == *all* ]] && trust_all=1 && break; done
            local tsev=HIGH; (( trust_all )) && tsev=CRITICAL
            hit "$tsev" "pg_hba.conf: ${#trust_lines[@]} trust entry/entries (no password required)" \
                'replace "trust" with "scram-sha-256"'
        fi

        (( ${#md5_lines[@]} )) && \
            hit MEDIUM "pg_hba.conf: ${#md5_lines[@]} md5 entry/entries (deprecated)" \
                'use scram-sha-256 + password_encryption=scram-sha-256'

        while IFS= read -r line; do
            line="${line%%#*}"
            [[ -z ${line//[[:space:]]/} ]] && continue
            read -ra parts <<< "$line"
            (( ${#parts[@]} < 4 )) && continue
            conn_type="${parts[0],,}"; db="${parts[1],,}"; user="${parts[2],,}"
            if [[ "$conn_type" == host && "$db" == all && \
                  ( "$user" == all || "$user" == postgres ) ]]; then
                hit HIGH "Broad remote rule in pg_hba.conf: ${parts[2]} to all DBs" \
                    'restrict to specific users/DBs/CIDRs; postgres superuser local-only'
                break
            fi
        done < <(printf '%s\n' "$hba_body")
    fi
}

check_mysql() {
    load_configs \
        '/etc/mysql/my.cnf' '/etc/mysql/mysql.conf.d/mysqld.cnf' \
        '/etc/mysql/conf.d/mysqld.cnf' \
        '/etc/mysql/mariadb.conf.d/50-server.cnf' \
        '/etc/my.cnf' '/etc/my.cnf.d/*.cnf' \
        || { echo -e "${GRAY}  (not installed)${RST}"; return; }
    local v

    body_has '^[[:space:]]*skip[-_]grant[-_]tables' && \
        hit CRITICAL 'skip-grant-tables is set - ALL MySQL/MariaDB authentication bypassed' \
            'Remove skip-grant-tables from [mysqld] and restart the service'

    get_eq local-infile; v="${_VAL,,}"
    [[ -z "$v" ]] && { get_eq local_infile; v="${_VAL,,}"; }
    [[ "$v" == 1 || "$v" == on || "$v" == true ]] && \
        hit HIGH 'local-infile=1 - arbitrary server file read via LOAD DATA LOCAL INFILE' \
            'local-infile=0  in [mysqld] section'

    get_eq bind-address; v="$_VAL"
    [[ -z "$v" ]] && { get_eq bind_address; v="$_VAL"; }
    if [[ "$v" == '0.0.0.0' || "$v" == '::' || "$v" == '*' ]]; then
        hit HIGH "bind-address=$v - MySQL/MariaDB port exposed on all network interfaces" \
            'bind-address=127.0.0.1'
    elif [[ -z "$v" ]]; then
        hit MEDIUM 'bind-address not set - MySQL/MariaDB may be listening on all interfaces' \
            'bind-address=127.0.0.1  in [mysqld] section'
    fi

    get_eq secure-file-priv; v="$_VAL"
    [[ -z "$v" ]] && { get_eq secure_file_priv; v="$_VAL"; }
    [[ -z "$v" || "$v" == '""' || "$v" == "''" ]] && \
        hit HIGH 'secure-file-priv not set - INTO OUTFILE / LOAD DATA can access any filesystem path' \
            'secure-file-priv=/var/lib/mysql-files  in [mysqld] section'
}

check_php() {
    load_configs \
        '/etc/php/*/apache2/php.ini' '/etc/php/*/cli/php.ini' \
        '/etc/php/*/fpm/php.ini' '/etc/php.ini' '/usr/local/lib/php.ini' \
        || { echo -e "${GRAY}  (not installed)${RST}"; return; }
    local v

    get_eq allow_url_include; v="${_VAL,,}"
    [[ "$v" == on || "$v" == 1 || "$v" == true ]] && \
        hit CRITICAL 'allow_url_include=On - Remote File Inclusion (RFI) via require/include' \
            'allow_url_include=Off'

    get_eq allow_url_fopen; v="${_VAL,,}"
    [[ -z "$v" || "$v" == on || "$v" == 1 ]] && \
        hit HIGH 'allow_url_fopen=On - PHP can open remote URLs (SSRF / remote payload fetch)' \
            'allow_url_fopen=Off'

    get_eq disable_functions; v="$_VAL"
    [[ -z "$v" ]] && \
        hit HIGH 'disable_functions is empty - exec,system,shell_exec,passthru etc. all callable' \
            'disable_functions=exec,passthru,shell_exec,system,proc_open,popen,show_source'
}

check_cron() {
    load_configs '/etc/crontab' '/etc/cron.d/*' '/var/spool/cron/crontabs/*' \
        || { echo -e "${GRAY}  (no cron files found)${RST}"; return; }
    local f fperms

    shopt -s nullglob
    for f in /etc/crontab /etc/cron.d/*; do
        [[ -f "$f" ]] || continue
        fperms=$(stat -c '%a' "$f" 2>/dev/null) || continue
        (( 8#$fperms & 022 )) && \
            hit CRITICAL "Cron file is group/world-writable: $f (mode $fperms)" \
                "chmod 644 \"$f\"; chown root:root \"$f\""
    done
    shopt -u nullglob

    body_has '\bnc\b.+-[el][[:space:]]|\bncat\b|\bnetcat\b.+-[el][[:space:]]' && \
        hit CRITICAL 'Possible netcat reverse shell in a cron job' \
            'Audit /etc/crontab and /etc/cron.d/*; remove suspicious entries'

    body_has '[[:space:]]/tmp/' && \
        hit CRITICAL 'Cron job executes a file from /tmp (common backdoor staging path)' \
            'Remove cron entries that reference /tmp'

    body_has 'base64.*(--decode|-d[[:space:]])' && \
        hit HIGH 'Cron job base64-decodes a payload - likely obfuscated command execution' \
            'Audit cron files for base64-encoded commands'

    body_has '(wget|curl)[[:space:]].*[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && \
        hit HIGH 'Cron job fetches content from a raw IP address (possible C2 callback)' \
            'Remove cron entries downloading from IP addresses'

    body_has '(python[23]?|perl|ruby|php)[[:space:]].*-[ce][[:space:]]' && \
        hit HIGH 'Cron job runs interpreter one-liner - possible scripted reverse shell' \
            'Audit cron entries for python/perl/ruby -e/-c one-liners'
}

check_sudoers() {
    load_configs '/etc/sudoers' '/etc/sudoers.d/*' \
        || { echo -e "${GRAY}  (not accessible)${RST}"; return; }
    local f fperms

    body_has 'NOPASSWD' && \
        hit HIGH 'NOPASSWD found in sudoers - privilege escalation without a password' \
            'Remove NOPASSWD or restrict to specific safe, non-shell commands'

    body_has 'NOPASSWD[[:space:]]*:[[:space:]]*ALL[[:space:]]*$' && \
        hit CRITICAL 'sudoers: unrestricted NOPASSWD: ALL - trivial full root access' \
            'Remove the rule or restrict to a specific whitelisted command'

    body_has '!authenticate' && \
        hit HIGH 'sudoers: !authenticate tag found - password check bypassed for affected rule' \
            'Remove !authenticate from sudoers'

    shopt -s nullglob
    for f in /etc/sudoers.d/*; do
        [[ -f "$f" ]] || continue
        fperms=$(stat -c '%a' "$f" 2>/dev/null) || continue
        (( 8#$fperms & 022 )) && \
            hit CRITICAL "sudoers.d file is group/world-writable: $f (mode $fperms)" \
                "chmod 440 \"$f\"; chown root:root \"$f\""
    done
    shopt -u nullglob
}

# ============================================================================
# MAIN
# ============================================================================

ALL=(apache2 nginx openssh vsftpd samba bind postgres mysql php cron sudoers)

SERVICES=()
if [[ $# -eq 0 ]]; then
    SERVICES=("${ALL[@]}")
else
    for a in "$@"; do
        if [[ "${a,,}" == all ]]; then SERVICES=("${ALL[@]}"); break; fi
        SERVICES+=("${a,,}")
    done
fi

echo -e "${BOLD}=========================================${RST}"
echo -e "${BOLD}  SERVICE CONFIG AUDIT${RST}"
echo -e "${BOLD}=========================================${RST}"
echo ""

for svc in "${SERVICES[@]}"; do
    fn="check_$svc"
    echo -e "${GRN}[+] ${svc}${RST}"
    if declare -f "$fn" >/dev/null; then
        "$fn"
    else
        echo -e "${GRAY}  unknown service (try: ${ALL[*]})${RST}"
    fi
    echo ""
done

echo -e "${BOLD}=========================================${RST}"
echo -e "${BOLD}  SUMMARY${RST}"
echo -e "${BOLD}=========================================${RST}"
echo ""
echo -e "  ${RED}${BOLD}${COUNT_CRIT} critical${RST} / ${RED}${COUNT_HIGH} high${RST} / ${YEL}${COUNT_MED} medium${RST}"
