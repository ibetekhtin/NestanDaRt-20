#!/bin/bash
# ============================================================================
# VPS Setup — Nestandart (Hetzner CPX21)
# ============================================================================
# Run as root on fresh Ubuntu 24.04
# Usage: sudo bash deploy/setup-vps.sh
# ============================================================================

set -e

echo "🚀 Setting up Nestandart VPS..."

# System update
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create project directory
mkdir -p /opt/nestandart
mkdir -p /opt/nestandart/logs

# Firewall (UFW) — только публичные порты; n8n и backend только через nginx
apt-get install -y ufw
ufw allow 22      # SSH
ufw allow 80      # HTTP
ufw allow 443     # HTTPS
# НЕ открывать 5678 (n8n) и 8000 (backend) — доступны только через nginx reverse proxy
ufw --force enable

# Swap file (if not present)
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo ""
echo "✅ VPS setup complete!"
echo ""
echo "Next steps:"
echo "  1. Clone repo: cd /opt/nestandart && git clone <repo> ."
echo "  2. Configure: cp .env.example .env && nano .env"
echo "  3. Deploy: docker compose up -d"
echo ""