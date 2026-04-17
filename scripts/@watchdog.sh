#!/bin/bash
#
# @watchdog.sh - tmux monitoring dashboard for competition
# Opens a multi-pane session with live monitoring tools
# Usage: sudo ./watchdog.sh
#

set -euo pipefail

SESSION="watchdog"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"

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
    echo "[+] watchdog session already exists — attaching"
    exec tmux attach -t "$SESSION"
fi

tmux new-session -d -s "$SESSION" -n "monitor"

# ============================================================================
# Layout: 4 panes
#
#   ┌──────────────────┬──────────────────┐
#   │  process watch   │  network watch   │
#   │  (pspy/find)     │  (ss filtered)   │
#   ├──────────────────┼──────────────────┤
#   │  auth log        │  users & ports   │
#   │  (tail -f)       │  (w + listening) │
#   └──────────────────┴──────────────────┘
# ============================================================================

tmux split-window -v -t "$SESSION:0"
tmux split-window -h -t "$SESSION:0.0"
tmux split-window -h -t "$SESSION:0.2"

# Pane 0 (top-left): Process monitor — pspy64 if available, else find-based
PANE0="$SESSION:0.0"
if [[ -x "$TOOLS_DIR/pspy64" ]]; then
    tmux send-keys -t "$PANE0" "$TOOLS_DIR/pspy64 -pf -i 1000" C-m
elif command -v pspy64 &>/dev/null; then
    tmux send-keys -t "$PANE0" 'pspy64 -pf -i 1000' C-m
else
    tmux send-keys -t "$PANE0" 'echo "[+] pspy64 not found — using find-based watcher"; echo "[+] Run: bash tools/setup.sh"; while true; do clear; echo "=== Modified files (last 5 min) ==="; find /etc /home /root /var/spool -mmin -5 2>/dev/null; sleep 30; done' C-m
fi

# Pane 1 (top-right): Network — filtered to non-loopback only
PANE1="$SESSION:0.1"
tmux send-keys -t "$PANE1" 'watch -n 2 "echo === LISTENING (non-loopback) ===; ss -tulpn | grep -v 127.0.0.1 | grep -v ::1; echo; echo === ESTABLISHED (non-loopback) ===; ss -tupn state established | grep -v 127.0.0.1 | grep -v ::1"' C-m

# Pane 2 (bottom-left): Auth log — filtered to interesting events only
PANE2="$SESSION:0.2"
AUTH_LOG="/var/log/auth.log"
[[ ! -f "$AUTH_LOG" ]] && AUTH_LOG="/var/log/secure"
tmux send-keys -t "$PANE2" "tail -f $AUTH_LOG | grep --line-buffered -E 'Failed|Accepted|session opened|session closed|sudo|useradd|userdel|passwd|su:'" C-m

# Pane 3 (bottom-right): Users & listening ports — compact
PANE3="$SESSION:0.3"
tmux send-keys -t "$PANE3" 'watch -n 5 "echo === LOGGED IN ===; who; echo; echo === LISTENING (non-loopback) ===; ss -tulpn | grep -v 127.0.0.1 | grep -v ::1 | grep LISTEN"' C-m

# ============================================================================
# Second window: re-run audit every 15 min
# ============================================================================

tmux new-window -t "$SESSION" -n "audit"
PANE_AUDIT="$SESSION:1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux send-keys -t "$PANE_AUDIT" "echo '[+] Running audit every 15 min — Ctrl+C to stop'; while true; do clear; bash $SCRIPT_DIR/03_audit.sh 2>&1 | grep -vE '^$'; echo; echo '=== Next run in 15 min ==='; sleep 900; done" C-m

# ============================================================================
# Third window: interactive shell
# ============================================================================

tmux new-window -t "$SESSION" -n "shell"

# ============================================================================
# Attach
# ============================================================================

tmux select-window -t "$SESSION:0"
tmux attach -t "$SESSION"
