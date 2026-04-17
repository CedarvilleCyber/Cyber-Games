#!/bin/bash
#
# @dn_install.sh - defined.net dnclient one-step install & enroll
# Downloads, installs, starts, and enrolls the dnclient server binary
# Usage: sudo ./dn_install.sh <ENROLL_CODE>
#        e.g.: sudo ./dn_install.sh ABCD-1234-EFGH-5678
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
# CONFIGURATION
# ============================================================================

DN_INSTALL_DIR="${DN_INSTALL_DIR:-/usr/local/bin}"
API="https://api.defined.net/v1/downloads"

# ============================================================================
# PRE-FLIGHT
# ============================================================================

echo -e "${BOLD}=========================================${RST}"
echo -e "${BOLD}  DEFINED.NET DNCLIENT INSTALL${RST}"
echo -e "${BOLD}=========================================${RST}"
echo ""

if [[ $(id -u) -ne 0 ]]; then
    echo -e "${RED}[!] Run this script as root.${RST}"
    exit 1
fi

if [[ $# -eq 0 || -z "${1:-}" ]]; then
    echo -e "${RED}[!] Usage: $0 <ENROLL_CODE>${RST}"
    exit 1
fi

ENROLL_CODE="$1"

for cmd in curl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}[!] '$cmd' is required but not installed${RST}"
        exit 1
    fi
done

# ============================================================================
# DETECT PLATFORM
# ============================================================================

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
    linux)  PLATFORM="linux" ;;
    freebsd) PLATFORM="freebsd" ;;
    darwin) PLATFORM="macos" ;;
    *) echo -e "${RED}[!] Unsupported OS: $OS${RST}"; exit 1 ;;
esac

case "$ARCH" in
    x86_64|amd64)   ARCH_KEY="amd64" ;;
    i386|i686)      ARCH_KEY="386" ;;
    aarch64|arm64)  ARCH_KEY="arm64" ;;
    armv5l)         ARCH_KEY="armv5" ;;
    armv6l)         ARCH_KEY="armv6" ;;
    armv7l)         ARCH_KEY="armv7" ;;
    mips)           ARCH_KEY="mips" ;;
    mips64)         ARCH_KEY="mips64" ;;
    mips64le)       ARCH_KEY="mips64le" ;;
    mipsle)         ARCH_KEY="mipsle" ;;
    ppc64le)        ARCH_KEY="ppc64le" ;;
    riscv64)        ARCH_KEY="riscv64" ;;
    *) echo -e "${RED}[!] Unsupported architecture: $ARCH${RST}"; exit 1 ;;
esac

if [[ "$PLATFORM" == "macos" ]]; then
    DL_KEY="macos-universal-server"
else
    DL_KEY="${PLATFORM}-${ARCH_KEY}"
fi

echo -e "${GRN}[+] Platform: $DL_KEY${RST}"

# ============================================================================
# FETCH DOWNLOAD URL
# ============================================================================

echo -e "${GRN}[+] Fetching latest dnclient URL${RST}"
response=$(curl -sf "$API")

if command -v python3 &>/dev/null; then
    DL_URL=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['dnclient']['latest']['$DL_KEY'])")
    VERSION=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['versionInfo']['latest']['dnclient'])")
else
    DL_URL=$(echo "$response" | grep -o "\"${DL_KEY}\":\"[^\"]*\"" | tail -1 | sed "s/\"${DL_KEY}\":\"//;s/\"//")
    VERSION=$(echo "$response" | grep -o '"dnclient":"[0-9][^"]*"' | tail -1 | sed 's/"dnclient":"//;s/"//')
fi

if [[ -z "$DL_URL" || "$DL_URL" == "None" ]]; then
    echo -e "${RED}[!] No download available for $DL_KEY${RST}"
    exit 1
fi

echo -e "${GRAY}    Version: ${VERSION:-unknown}${RST}"
echo -e "${GRAY}    URL: $DL_URL${RST}"

# ============================================================================
# DOWNLOAD
# ============================================================================

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo -e "${GRN}[+] Downloading dnclient${RST}"
curl -sfL -o "$TMPDIR/dnclient" "$DL_URL"
chmod +x "$TMPDIR/dnclient"
echo -e "${GRAY}    done${RST}"

# ============================================================================
# INSTALL & START
# ============================================================================

echo -e "${GRN}[+] Installing dnclient to $DN_INSTALL_DIR${RST}"
cp "$TMPDIR/dnclient" "$DN_INSTALL_DIR/dnclient"
echo -e "${GRAY}    done${RST}"

echo -e "${GRN}[+] Installing dnclient service${RST}"
"$DN_INSTALL_DIR/dnclient" install
echo -e "${GRAY}    done${RST}"

echo -e "${GRN}[+] Starting dnclient service${RST}"
"$DN_INSTALL_DIR/dnclient" start
echo -e "${GRAY}    done${RST}"

# ============================================================================
# ENROLL
# ============================================================================

echo -e "${GRN}[+] Enrolling with code: ${ENROLL_CODE:0:4}****${RST}"
if [[ -f /etc/dnclient/config.yaml ]] || [[ -f /usr/local/etc/dnclient/config.yaml ]]; then
    echo -e "${YEL}[!] Already enrolled — re-enrolling will overwrite existing config${RST}"
    read -rp "    Continue? [y/N] " confirm < /dev/tty
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "${GRAY}    skipped${RST}"; ENROLL_SKIP=1; }
fi
if [[ -z "${ENROLL_SKIP:-}" ]]; then
    "$DN_INSTALL_DIR/dnclient" enroll -code "$ENROLL_CODE"
    echo -e "${GRAY}    done${RST}"
fi

# ============================================================================
# DONE
# ============================================================================

echo ""
echo -e "${BOLD}=========================================${RST}"
echo -e "${GRN}${BOLD}  DNCLIENT INSTALLED & ENROLLED${RST}"
echo -e "${BOLD}=========================================${RST}"
echo ""
echo -e "${GRN}[+] Binary: $DN_INSTALL_DIR/dnclient${RST}"
echo -e "${GRN}[+] Service: dnclient (auto-starts on boot)${RST}"
