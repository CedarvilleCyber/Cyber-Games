#!/bin/bash
#
# 03 - Kernel Hardening
# Apply security-focused sysctl settings
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/03_kernel_hardening.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  KERNEL HARDENING"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

echo "[1] Backing up current sysctl settings"
cp /etc/sysctl.conf "/etc/sysctl.conf.backup.$(date +%s)" 2>/dev/null || true

echo "[2] Applying security sysctl settings"

cat > /etc/sysctl.d/99-security.conf << 'SYSCTL_EOF'
# NCAE Competition Security Settings

# === Network Security ===
# Disable IP forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Disable redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Enable reverse path filtering (anti-spoofing)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# ICMP protection
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.icmp_echo_ignore_all = 0

# Log martian packets (packets with impossible addresses)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# === TCP/SYN Flood Protection ===
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# === Kernel Security ===
# Restrict dmesg access
kernel.dmesg_restrict = 1

# Hide kernel pointers
kernel.kptr_restrict = 2

# Restrict ptrace (prevent process debugging)
kernel.yama.ptrace_scope = 1

# Disable kexec (prevents kernel replacement)
kernel.kexec_load_disabled = 1

# === Memory Protection ===
# Increase ASLR entropy
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16

# Disable core dumps for SUID programs
fs.suid_dumpable = 0

# === File System Protection ===
# Protect hard/soft links
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

# Restrict access to /proc
kernel.kptr_restrict = 2
SYSCTL_EOF

echo "[3] Applying settings"
sysctl -p /etc/sysctl.d/99-security.conf

echo "[4] Verifying key settings"
echo "    IP forwarding: $(sysctl -n net.ipv4.ip_forward)"
echo "    SYN cookies: $(sysctl -n net.ipv4.tcp_syncookies)"
echo "    PTRACE scope: $(sysctl -n kernel.yama.ptrace_scope)"
echo "    ASLR bits: $(sysctl -n vm.mmap_rnd_bits)"

echo "[5] Disabling uncommon network protocols"
cat > /etc/modprobe.d/blacklist-rare-network.conf << 'MODPROBE_EOF'
# Disable uncommon protocols that could be attack vectors
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
MODPROBE_EOF

echo ""
echo "========================================="
echo "  KERNEL HARDENING COMPLETE"
echo "========================================="
echo ""
echo "Reboot recommended to fully apply all settings."
echo "Settings will persist across reboots."