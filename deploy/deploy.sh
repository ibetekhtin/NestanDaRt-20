#!/bin/bash
# ============================================================================
# Deploy Script — KOTЭ SYSTEM
# ============================================================================
# Usage: bash deploy/deploy.sh
# ============================================================================

set -e

echo "🚀 Deploying KOTЭ..."

cd /opt/kote

# Pull latest changes
echo "📥 Pulling latest code..."
git pull origin main

# Stop services
echo "⏹️  Stopping services..."
docker compose down

# Rebuild
echo "🔨 Building images..."
docker compose build --no-cache

# Start services
echo "▶️  Starting services..."
docker compose up -d

# Clean old images
echo "🧹 Cleaning up..."
docker image prune -f

# Show status
docker compose ps

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Services:"
echo "  🤖 Bot:     docker compose logs kote-bot"
echo "  🔌 Backend: http://localhost:8000/docs"
echo "  ⚙️  n8n:     http://localhost:5678"
echo ""