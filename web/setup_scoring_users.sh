#!/bin/bash

USERS=("gloucester" "scituate" "leicester" "leominster" "tewksbury")
PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcM4aDj8Y4COv+f8bd2WsrIynlbRGgDj2+q9aBeW1Umj5euxnO1vWsjfkpKnyE/ORsI6gkkME9ojAzNAPquWMh2YG+n11FB1iZl2S6yuZB7dkVQZSKpVYwRvZv2RnYDQdcVnX9oWMiGrBWEAi4jxcYykz8nunaO2SxjEwzuKdW8lnnh2BvOO9RkzmSXIIdPYgSf8bFFC7XFMfRrlMXlsxbG3u/NaFjirfvcXKexz06L6qYUzob8IBPsKGaRjO+vEdg6B4lH1lMk1JQ4GtGOJH6zePfB6Gf7rp31261VRfkpbpaDAznTzh7bgpq78E7SenatNbezLDaGq3Zra3j53u7XaSVipkW0S3YcXczhte2J9kvo6u6s094vrcQfB9YigH4KhXpCErFk08NkYAEJDdqFqXIjvzsro+2/EW1KKB9aNPSSM9EZzhYc+cBAl4+ohmEPej1m15vcpw3k+kpo1NC2rwEXIFxmvTme1A2oIZZBpgzUqfmvSPwLXF0EyfN9Lk= SCORING KEY DO NOT REMOVE"

echo "Starting scoring user setup..."

for user in "${USERS[@]}"; do
    if ! id "$user" &>/dev/null; then
        useradd -m -s /bin/bash "$user"
    fi

    HOME_DIR="/home/$user"
    SSH_DIR="$HOME_DIR/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"

    if ! grep -q "SCORING KEY DO NOT REMOVE" "$AUTH_KEYS" 2>/dev/null; then
        echo "$PUB_KEY" >> "$AUTH_KEYS"
    fi

    chmod 700 "$SSH_DIR"
    chmod 600 "$AUTH_KEYS"
    chown -R "$user:$user" "$SSH_DIR"
done

# Configure sshd
mkdir -p /run/sshd
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config || true
sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config || true
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
