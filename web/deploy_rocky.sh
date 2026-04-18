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

# 5. Make sure the docker-compose has the correct interface
# (This is already hardcoded to ens18 in docker-compose.yml)
echo "Using macvlan parent interface ens18"

# 6. Tear down old containers first (if any exist)
echo "Tearing down old deployments..."
sudo docker compose down -v || true

# 7. Start the containers
echo "Building and starting containers..."
sudo docker compose up -d --build

echo "Deployment complete! Checking status:"
sudo docker compose ps
