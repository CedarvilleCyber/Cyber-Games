#!/bin/bash
#
# @dn_enroll.sh - defined.net CTF mass enrollment
# Creates hosts on a defined.net network and generates enrollment commands
# Usage: ./dn_enroll.sh <host-name> [host-name ...]
#        e.g.: ./dn_enroll.sh kali-1 kali-2 ubuntu-target db-server
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
# CONFIGURATION — edit these for your competition
# ============================================================================

DN_API_KEY="${DN_API_KEY:?Set DN_API_KEY env var}"
DN_NETWORK_ID="${DN_NETWORK_ID:-network-JC2XSVID2IICN3ZZXYZ3JOW65E}"
DN_ROLE_ID="${DN_ROLE_ID:-role-5JSB3SLU2BJIOGYP3KP6APTJQM}"
API="https://api.defined.net/v1"

# ============================================================================
# PRE-FLIGHT
# ============================================================================

echo -e "${BOLD}=========================================${RST}"
echo -e "${BOLD}  DEFINED.NET MASS ENROLLMENT${RST}"
echo -e "${BOLD}=========================================${RST}"
echo ""

for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}[!] '$cmd' is required but not installed${RST}"
        exit 1
    fi
done

if [[ $# -eq 0 ]]; then
    echo -e "${RED}[!] Usage: $0 <host-name> [host-name ...]${RST}"
    exit 1
fi

# ============================================================================
# ENROLLMENT
# ============================================================================

for name in "$@"; do
    echo -e "${GRN}[+] Creating host: $name${RST}"

    payload=$(jq -n \
        --arg name "$name" \
        --arg net "$DN_NETWORK_ID" \
        --arg role "$DN_ROLE_ID" \
        '{
            name: $name,
            networkID: $net,
            roleID: (if $role != "" then $role else null end),
            isLighthouse: false,
            isRelay: false
        }')

    response=$(curl -sf -X POST "$API/host-and-enrollment-code" \
        -H "Authorization: Bearer $DN_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")

    code=$(echo "$response" | jq -r '.data.enrollmentCode.code')
    ip=$(echo "$response" | jq -r '.data.host.ipAddress')

    echo -e "${GRAY}    Host: $name ($ip)${RST}"
    echo -e "${GRAY}    Enroll: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/@dn_install.sh | sudo bash -s $code${RST}"
    echo ""
done

echo -e "${BOLD}=========================================${RST}"
echo -e "${GRN}${BOLD}  ENROLLMENT COMPLETE${RST}"
echo -e "${BOLD}=========================================${RST}"
echo ""
echo -e "${YEL}[!] Run the enroll commands on each target host${RST}"