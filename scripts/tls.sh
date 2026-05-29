#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

[[ -z "$1" || -z "$2" ]] && { echo "Uso: ./scripts/tls.sh dominio.com tu@email.com"; exit 1; }

docker compose exec freepbx certbot --apache \
  -d "$1" --email "$2" --agree-tos --redirect -n

echo "✅ TLS configurado para $1"
