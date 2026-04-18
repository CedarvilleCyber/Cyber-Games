#!/bin/bash
#
# @watchdog.sh - tmux monitoring dashboard for competition
# Opens a multi-pane session with live monitoring tools
# Usage: sudo ./watchdog.sh
#
# Keybinds (all prefix-less, no Ctrl+b needed):
#   Alt+Arrow / Alt+hjkl  — switch panes
#   Alt+1/2/3            — switch windows (0-indexed)
#   Shift+Left/Right      — prev/next window
#   Alt+z                 — zoom/unzoom pane (fullscreen toggle)
#   Ctrl+Alt+Arrow        — resize panes
#   Alt+q                 — kill session and exit
#   Alt+d                 — detach session
#   Mouse enabled         — click, scroll, drag borders
#

set -euo pipefail

SESSION="watchdog"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

if ! command -v tmux &>/dev/null; then
    echo "[!] tmux is required but not installed"
    echo "    Install: apt install tmux  OR  dnf install tmux"
    exit 1
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[+] Killing existing watchdog session"
    tmux kill-session -t "$SESSION"
fi

# ============================================================================
# Create helper scripts in /var/lib/watchdog
# ============================================================================

WD_DIR="/var/lib/watchdog"
mkdir -p "$WD_DIR"

cat > "$WD_DIR/_watchdog_net.sh" << 'NET_EOF'
#!/bin/bash
# Colored network display — port + binary, concise
RED='\033[1;31m'; GRN='\033[1;32m'; GRAY='\033[2m'; RST='\033[0m'
KNOWN_PORTS="22 53 80 443 3306 5432 25 110 143 993 995 21"

while true; do
    output=""
    output+="${GRN}=== LISTENING ===${RST}\n"
    listen_lines=$(ss -tlnp 2>/dev/null | tail -n +2 | grep -vE '127\.0\.0\.1|::1')
    if [[ -n "$listen_lines" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            port=$(echo "$line" | grep -oE ':[0-9]+' | head -1 | sed 's/://')
            [[ -z "$port" ]] && continue
            bin=$(echo "$line" | awk -F'"' '{print $2}')
            [[ -z "$bin" ]] && bin="?"
            known=0
            for p in $KNOWN_PORTS; do [[ "$port" == "$p" ]] && known=1 && break; done
            if [[ "$known" -eq 1 ]]; then
                output+="  ${GRAY}:${port} ${bin}${RST}\n"
            else
                output+="  ${RED}:${port} ${bin}${RST}\n"
            fi
        done <<< "$listen_lines"
    else
        output+="  ${GRAY}(none)${RST}\n"
    fi

    output+="\n${GRN}=== ESTABLISHED (non-loopback) ===${RST}\n"
    est_lines=$(ss -tupn state established 2>/dev/null | grep -vE '127\.0\.0\.1|::1')
    if [[ -n "$est_lines" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            lport=$(echo "$line" | awk '{print $4}' | grep -oE '[0-9]+$')
            raddr=$(echo "$line" | awk '{print $5}')
            bin=$(echo "$line" | awk -F'"' '{print $2}')
            [[ -z "$bin" ]] && bin="?"
            known=0
            for p in $KNOWN_PORTS; do [[ "$lport" == "$p" ]] && known=1 && break; done
            if [[ "$known" -eq 1 ]]; then
                output+="  ${GRAY}${lport} → ${raddr} ${bin}${RST}\n"
            else
                output+="  ${RED}${lport} → ${raddr} ${bin}${RST}\n"
            fi
        done <<< "$est_lines"
    else
        output+="  ${GRAY}(none)${RST}\n"
    fi

    clear
    echo -e "$output"
    sleep 3
done
NET_EOF
chmod +x "$WD_DIR/_watchdog_net.sh"

cat > "$WD_DIR/_watchdog_users.sh" << 'USERS_EOF'
#!/bin/bash
# Fast logged-in users + listening ports
GRN='\033[1;32m'; GRAY='\033[2m'; RED='\033[1;31m'; RST='\033[0m'
KNOWN_PORTS="22 53 80 443 3306 5432 25 110 143 993 995 21"

while true; do
    output=""
    output+="${GRN}=== LOGGED IN ===${RST}\n"
    logged=$(w -h 2>/dev/null | awk '{printf "%s %s ", $1, $3; for(i=8;i<=NF;i++) printf "%s ", $i; print ""}' | sort -u)
    if [[ -n "$logged" ]]; then
        while IFS= read -r line; do
            output+="  ${GRAY}${line}${RST}\n"
        done <<< "$logged"
    else
        output+="  ${GRAY}(none)${RST}\n"
    fi

    output+="\n${GRN}=== LISTENING (non-loopback) ===${RST}\n"
    listen_lines=$(ss -tlnp 2>/dev/null | tail -n +2 | grep -vE '127\.0\.0\.1|::1')
    if [[ -n "$listen_lines" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            port=$(echo "$line" | grep -oE ':[0-9]+' | head -1 | sed 's/://')
            [[ -z "$port" ]] && continue
            bin=$(echo "$line" | awk -F'"' '{print $2}')
            [[ -z "$bin" ]] && bin="?"
            known=0
            for p in $KNOWN_PORTS; do [[ "$port" == "$p" ]] && known=1 && break; done
            if [[ "$known" -eq 1 ]]; then
                output+="  ${GRAY}:${port} ${bin}${RST}\n"
            else
                output+="  ${RED}:${port} ${bin}${RST}\n"
            fi
        done <<< "$listen_lines"
    else
        output+="  ${GRAY}(none)${RST}\n"
    fi

    clear
    echo -e "$output"
    sleep 2
done
USERS_EOF
chmod +x "$WD_DIR/_watchdog_users.sh"

cat > "$WD_DIR/_watchdog_files.sh" << 'FILES_EOF'
#!/bin/bash
# Suspicious activity watcher — runs critical checks every 10s
RED='\033[1;31m'; YEL='\033[1;33m'; GRN='\033[1;32m'; GRAY='\033[2m'; RST='\033[0m'

while true; do
    clear
    echo -e "${GRN}=== Suspicious processes ===${RST}"
    found=0
    ps aux | grep -E 'nc[[:space:]].*-[ec]|ncat[[:space:]]|bash.*\/dev\/tcp|sh.*\/dev\/tcp|python.*socket|perl.*socket|ruby.*socket|socat' | grep -v grep | while IFS= read -r line; do
        echo -e "  ${RED}${line}${RST}"
        found=1
    done
    [[ "$found" -eq 0 ]] && echo -e "  ${GRAY}(clean)${RST}"

    echo ""
    echo -e "${GRN}=== Deleted executables ===${RST}"
    found=0
    for pid in /proc/[0-9]*/exe; do
        readlink "$pid" 2>/dev/null | grep -q '(deleted)' || continue
        n=${pid#/proc/}; n=${n%/exe}
        cmd=$(ps -p "$n" -o cmd= 2>/dev/null || echo "?")
        echo -e "  ${RED}PID ${n}: ${cmd}${RST}"
        found=1
    done
    [[ "$found" -eq 0 ]] && echo -e "  ${GRAY}(clean)${RST}"

    echo ""
    echo -e "${GRN}=== New connections (non-loopback) ===${RST}"
    conn_count=$(ss -tupn state established 2>/dev/null | grep -cvE '127\.0\.0\.1|::1' || echo 0)
    echo -e "  ${GRAY}${conn_count} established (non-loopback)${RST}"

    echo ""
    echo -e "${GRN}=== Modified files (5 min) ===${RST}"
    EXCLUDE="(watchdog|_watchdog|\.bak\.|\.git/|\.bash_history|/var/log/|/var/cache/|/var/lib/|__pycache__|/root/\.cache/)"
    count=$(find /etc /home /root /var/spool -mmin -5 -type f 2>/dev/null | grep -vE "$EXCLUDE" | wc -l)
    if [[ "$count" -gt 0 ]]; then
        find /etc /home /root /var/spool -mmin -5 -type f 2>/dev/null | grep -vE "$EXCLUDE" | head -10 | while IFS= read -r f; do
            echo -e "  ${GRAY}${f}${RST}"
        done
        [[ "$count" -gt 10 ]] && echo -e "  ${GRAY}... and $((count-10)) more${RST}"
    else
        echo -e "  ${GRAY}(none)${RST}"
    fi

    sleep 10
done
FILES_EOF
chmod +x "$WD_DIR/_watchdog_files.sh"

# ============================================================================
# tmux config — mouse + easy keybinds
# ============================================================================

tmux new-session -d -s "$SESSION" -n "monitor"

tmux set-option -g mouse on
tmux set-option -g escape-time 0
tmux set-option -g history-limit 10000

# Alt+arrow to switch panes
tmux bind -n M-Left select-pane -L
tmux bind -n M-Right select-pane -R
tmux bind -n M-Up select-pane -U
tmux bind -n M-Down select-pane -D

# Alt+number to switch windows
tmux bind -n M-1 select-window -t 0
tmux bind -n M-2 select-window -t 1
tmux bind -n M-3 select-window -t 2

# Alt+hjkl to switch panes (vim-style)
tmux bind -n M-h select-pane -L
tmux bind -n M-l select-pane -R
tmux bind -n M-k select-pane -U
tmux bind -n M-j select-pane -D

# Alt+z to zoom/unzoom current pane
tmux bind -n M-z resize-pane -Z

# Alt+q to kill session and exit
tmux bind -n M-q kill-session

# Alt+d to detach
tmux bind -n M-d detach

# Shift+arrow to switch windows
tmux bind -n S-Left previous-window
tmux bind -n S-Right next-window

# Prefix-less pane resize with Ctrl+Alt+arrow
tmux bind -n C-M-Left resize-pane -L 5
tmux bind -n C-M-Right resize-pane -R 5
tmux bind -n C-M-Up resize-pane -U 5
tmux bind -n C-M-Down resize-pane -D 5

# ============================================================================
# Layout: 4 panes
#
#   ┌──────────────────┬──────────────────┐
#   │  process watch   │  network watch   │
#   ├──────────────────┼──────────────────┤
#   │  auth log        │  users & ports   │
#   └──────────────────┴──────────────────┘
# ============================================================================

tmux split-window -v -t "$SESSION:0"
tmux split-window -h -t "$SESSION:0.0"
tmux split-window -h -t "$SESSION:0.2"

# Pane 0 (top-left): Suspicious activity watcher
PANE0="$SESSION:0.0"
tmux send-keys -t "$PANE0" "bash $WD_DIR/_watchdog_files.sh" C-m

# Pane 1 (top-right): Colored network display
PANE1="$SESSION:0.1"
tmux send-keys -t "$PANE1" "bash $WD_DIR/_watchdog_net.sh" C-m

# Pane 2 (bottom-left): Auth log — interesting events only
PANE2="$SESSION:0.2"
AUTH_LOG="/var/log/auth.log"
[[ ! -f "$AUTH_LOG" ]] && AUTH_LOG="/var/log/secure"
tmux send-keys -t "$PANE2" "tail -f $AUTH_LOG | grep --line-buffered -E 'Failed|Accepted|sudo|useradd|userdel|passwd|su:'" C-m

# Pane 3 (bottom-right): Users & listening ports
PANE3="$SESSION:0.3"
tmux send-keys -t "$PANE3" "bash $WD_DIR/_watchdog_users.sh" C-m

# ============================================================================
# Second window: re-run audit every 15 min
# ============================================================================

tmux new-window -t "$SESSION" -n "audit"
PANE_AUDIT="$SESSION:1"
tmux send-keys -t "$PANE_AUDIT" "while true; do clear; bash $SCRIPT_DIR/03_audit.sh; echo; echo '=== Next audit in 15 min ==='; sleep 900; done" C-m

# ============================================================================
# Third window: interactive shell
# ============================================================================

tmux new-window -t "$SESSION" -n "shell"

# ============================================================================
# Attach
# ============================================================================

tmux select-window -t "$SESSION:0"
tmux attach -t "$SESSION"