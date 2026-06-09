#!/bin/bash
# ============================================================================
# Healthcheck — KOTЭ SYSTEM
# ============================================================================

echo "🔍 Checking services..."

# Backend
if curl -s http://localhost:8000/api/v1/health | grep -q '"status":"ok"'; then
  echo "✅ Backend: OK"
else
  echo "❌ Backend: DOWN"
fi

# n8n
if curl -s http://localhost:5678/healthz | grep -q 'ok'; then
  echo "✅ n8n: OK"
else
  echo "❌ n8n: DOWN"
fi

# Docker containers
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || echo "⚠️  Docker Compose not available"

echo ""
echo "📊 System resources:"
df -h / | tail -1 | awk '{print "💾 Disk: "$5" used"}'
free -h | grep Mem | awk '{print "🧠 RAM: "$3" / "$2}'