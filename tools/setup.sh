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
    trap 'rm -rf "$TMPDIR"' EXIT
    curl -sfL "https://github.com/CISOfy/lynis/archive/refs/heads/master.tar.gz" | \
        tar -xz -C "$TMPDIR"
    mv "$TMPDIR/lynis-master" "$TOOLS_DIR/lynis"
    chmod +x "$TOOLS_DIR/lynis/lynis"
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

download "restic" \
    "https://github.com/restic/restic/releases/download/v0.17.3/restic_0.17.3_linux_${RESTIC_ARCH}.bz2" \
    "$TOOLS_DIR/restic.bz2"

if [[ -f "$TOOLS_DIR/restic.bz2" && ! -f "$TOOLS_DIR/restic" ]]; then
    bunzip2 -k "$TOOLS_DIR/restic.bz2"
    chmod +x "$TOOLS_DIR/restic"
fi

echo ""
echo -e "${GRN}[+] Done. Tools ready in $TOOLS_DIR/${RST}"
