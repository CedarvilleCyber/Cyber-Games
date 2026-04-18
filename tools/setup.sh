#!/bin/bash
#
# tools/setup.sh - Download open-source tools into the repo
# Run once after cloning: bash tools/setup.sh
#

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[1;31m'
GRN='\033[1;32m'
GRAY='\033[2m'
RST='\033[0m'

# ============================================================================
# Install system dependencies
# ============================================================================

echo -e "${GRN}[+] Installing system dependencies${RST}"

if command -v apt &>/dev/null; then
    apt install -y tmux bzip2 curl 2>/dev/null || true
elif command -v dnf &>/dev/null; then
    dnf install -y tmux bzip2 curl 2>/dev/null || true
elif command -v yum &>/dev/null; then
    yum install -y tmux bzip2 curl 2>/dev/null || true
fi

download() {
    local name="$1" url="$2" dest="$3"
    if [[ -f "$dest" ]]; then
        echo -e "${GRAY}  $name (already exists)${RST}"
        return
    fi
    echo -e "${GRN}[+] Downloading $name${RST}"
    mkdir -p "$(dirname "$dest")"
    curl -sfL -o "$dest" "$url"
    chmod +x "$dest"
}

decompress_bz2() {
    local src="$1" dest="$2"
    if command -v bzip2 &>/dev/null; then
        bzip2 -dk "$src"
    elif command -v python3 &>/dev/null; then
        python3 -c "
import bz2, sys
with open(sys.argv[1], 'rb') as f:
    data = bz2.decompress(f.read())
with open(sys.argv[2], 'wb') as f:
    f.write(data)
" "$src" "$dest"
    else
        echo -e "${RED}[!] Need bzip2 or python3 to decompress $src${RST}"
        echo -e "${GRAY}    Install: apt install bzip2  OR  dnf install bzip2${RST}"
        return 1
    fi
    chmod +x "$dest"
}

# ============================================================================
# GPLv2 tools
# ============================================================================

echo -e "${GRN}[+] Downloading GPLv2 tools${RST}"

download "pspy64 (v1.2.1)" \
    "https://github.com/DominicBreuker/pspy/releases/download/v1.2.1/pspy64" \
    "$TOOLS_DIR/pspy64"

download "linpeas.sh" \
    "https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh" \
    "$TOOLS_DIR/linpeas.sh"

# ============================================================================
# GPLv3 tools — lynis
# ============================================================================

echo -e "${GRN}[+] Downloading GPLv3 tools${RST}"

if [[ -d "$TOOLS_DIR/lynis" ]]; then
    echo -e "${GRAY}  lynis (already exists)${RST}"
else
    echo -e "${GRN}[+] Downloading lynis${RST}"
    TMPDIR=$(mktemp -d)
    curl -sfL "https://github.com/CISOfy/lynis/archive/refs/heads/master.tar.gz" | \
        tar -xz -C "$TMPDIR"
    mv "$TMPDIR/lynis-master" "$TOOLS_DIR/lynis"
    chmod +x "$TOOLS_DIR/lynis/lynis"
    rm -rf "$TMPDIR"
fi

# ============================================================================
# BSD-2-Clause tools — restic
# ============================================================================

echo -e "${GRN}[+] Downloading BSD-2-Clause tools${RST}"

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64) RESTIC_ARCH="amd64" ;;
    aarch64|arm64) RESTIC_ARCH="arm64" ;;
    *) RESTIC_ARCH="amd64" ;;
esac

if [[ -f "$TOOLS_DIR/restic" ]]; then
    echo -e "${GRAY}  restic (already exists)${RST}"
else
    download "restic" \
        "https://github.com/restic/restic/releases/download/v0.17.3/restic_0.17.3_linux_${RESTIC_ARCH}.bz2" \
        "$TOOLS_DIR/restic.bz2"
    decompress_bz2 "$TOOLS_DIR/restic.bz2" "$TOOLS_DIR/restic"
    rm -f "$TOOLS_DIR/restic.bz2"
fi

echo ""
echo -e "${GRN}[+] Done. Tools ready in $TOOLS_DIR/${RST}"
