#!/bin/bash
set -e

# Extract team number from IP (assuming 192.168.T.x)
TEAM_NUM=$(echo $TEAM_IP | cut -d'.' -f3)

if [ -z "$TEAM_NUM" ]; then
    echo "ERROR: TEAM_IP environment variable not set (e.g. 192.168.3.12)"
    exit 1
fi

echo "Configuring DNS for Team $TEAM_NUM..."

# SSH port forwarding is now handled by docker-compose
# Proceed with DNS setup

# 1. Generate the static internal zone file
cat <<EOF > /etc/bind/db.team${TEAM_NUM}.net
\$TTL 604800
@   IN  SOA ns1.team${TEAM_NUM}.net. admin.team${TEAM_NUM}.net. (
            2024010101 ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
@   IN  NS  ns1.team${TEAM_NUM}.net.
ns1 IN  A   192.168.${TEAM_NUM}.12
www IN  A   192.168.${TEAM_NUM}.5
db  IN  A   192.168.${TEAM_NUM}.7
EOF

# 2. Generate the static reverse zone file
cat <<EOF > /etc/bind/db.192.168.${TEAM_NUM}
\$TTL 604800
@   IN  SOA ns1.team${TEAM_NUM}.net. admin.team${TEAM_NUM}.net. (
            2024010101 ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
@   IN  NS  ns1.team${TEAM_NUM}.net.
12  IN  PTR ns1.team${TEAM_NUM}.net.
5   IN  PTR www.team${TEAM_NUM}.net.
7   IN  PTR db.team${TEAM_NUM}.net.
EOF

# 3. Generate the Dynamic DNS zone file (must be in a writable directory)
cat <<EOF > /var/bind/dyn/db.team${TEAM_NUM}.ncaecybergames.org
\$TTL 604800
@   IN  SOA ns1.team${TEAM_NUM}.net. admin.team${TEAM_NUM}.net. (
            2024010101 ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
@   IN  NS  ns1.team${TEAM_NUM}.net.
EOF

# Fix permissions for the dynamic zone so Bind9 can write the journal file
chown named:named /var/bind/dyn/db.team${TEAM_NUM}.ncaecybergames.org
chmod 664 /var/bind/dyn/db.team${TEAM_NUM}.ncaecybergames.org

# 4. Generate the named.conf dynamically
cat <<EOF > /etc/bind/named.conf
options {
    directory "/var/bind";
    
    // Listen on all interfaces
    listen-on { any; };
    listen-on-v6 { none; };

    // Allow queries from anywhere (or restrict to internal/external subnets)
    allow-query { any; };

    // Disable recursion to prevent DNS amplification attacks
    recursion no;
    
    // Hide BIND version for security
    version "Not Disclosed";
};

// Define the TSIG key required for Dynamic DNS updates
key "tsig-key-ddns" {
    algorithm hmac-sha256;
    secret "2gpGiYfklQY0o1WJM0WrgRJL1QU+fWGQS0Ab0gRdkJg=";
};

// 1. Internal Forward Zone
zone "team${TEAM_NUM}.net" {
    type master;
    file "/etc/bind/db.team${TEAM_NUM}.net";
};

// 2. Internal Reverse Zone
zone "${TEAM_NUM}.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.${TEAM_NUM}";
};

// 3. Dynamic DNS Zone (Secured with TSIG)
zone "team${TEAM_NUM}.ncaecybergames.org" {
    type master;
    file "/var/bind/dyn/db.team${TEAM_NUM}.ncaecybergames.org";
    
    // SECURE DDNS: Only allow updates authenticated with the specific key
    allow-update { key "tsig-key-ddns"; };
};
EOF

# Start Bind9 in the foreground
echo "Starting Bind9..."
exec named -g -u named
