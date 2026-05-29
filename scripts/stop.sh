#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

echo "⏹️  Deteniendo FreePBX..."
docker compose down
echo "✅ Detenido"
