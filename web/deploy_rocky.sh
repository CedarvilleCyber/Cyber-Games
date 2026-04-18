#!/bin/bash
set -e

echo "Starting deployment on Rocky 9..."

# 1. Update and install required packages
sudo dnf update -y
sudo dnf install -y yum-utils git curl wget

# 2. Add Docker repository and install Docker CE
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 3. Enable and start Docker service
sudo systemctl enable --now docker

# 4. Open firewall ports (HTTP, HTTPS, SSH, Postgres)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --permanent --add-port=53/udp
sudo firewall-cmd --permanent --add-port=53/tcp
sudo firewall-cmd --reload

# 5. Bind physical IPs to host interface (ens18) for Docker Bridge
echo "Binding scoring IPs to ens18..."
sudo ip addr add 192.168.3.5/24 dev ens18 || true
sudo ip addr add 192.168.3.7/24 dev ens18 || true
sudo ip addr add 192.168.3.12/24 dev ens18 || true

# 6. Clean up old macvlan network and containers
echo "Tearing down old deployments and clearing macvlan networks..."
sudo docker compose down -v || true
sudo docker network rm web_snb_net || true

# 7. Start the containers
echo "Building and starting containers..."
sudo docker compose up -d --build

echo "Deployment complete! Checking status:"
sudo docker compose ps
