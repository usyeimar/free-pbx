#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

source .env 2>/dev/null || { echo "❌ Copia .env.example a .env y configúralo"; exit 1; }

SILENT=false
RTP_RANGE="16384-32767"

for arg in "$@"; do
  case "$arg" in
    -s|--silent) SILENT=true ;;
    *) RTP_RANGE="$arg" ;;
  esac
done

FREEPBX_IP="172.18.0.20"
IFACE=$(ip -o -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')

echo "🚀 Construyendo y levantando FreePBX..."
docker compose up -d --build

# Configurar iptables para RTP (solo Linux)
if [[ "$OSTYPE" == "linux-gnu"* && -n "$IFACE" ]]; then
  echo "🔧 Configurando iptables RTP ($RTP_RANGE)..."

  # Esperar a que Docker cree la cadena DOCKER-USER
  DOCKER_USER_READY=false
  for i in $(seq 1 15); do
    if iptables -L DOCKER-USER -n &>/dev/null; then
      DOCKER_USER_READY=true
      break
    fi
    echo "  ⏳ Esperando cadena DOCKER-USER... ($i/15)"
    sleep 2
  done

  if [ "$DOCKER_USER_READY" = false ]; then
    echo "  ⚠️  Cadena DOCKER-USER no existe, creándola manualmente..."
    iptables -N DOCKER-USER 2>/dev/null || true
    iptables -I FORWARD -j DOCKER-USER 2>/dev/null || true
  fi

  iptables -C DOCKER-USER -p udp -d "$FREEPBX_IP" --dport "${RTP_RANGE/-/:}" -j ACCEPT 2>/dev/null \
    || iptables -I DOCKER-USER -p udp -d "$FREEPBX_IP" --dport "${RTP_RANGE/-/:}" -j ACCEPT

  iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport "${RTP_RANGE/-/:}" -j DNAT --to-destination "$FREEPBX_IP" 2>/dev/null \
    || iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport "${RTP_RANGE/-/:}" -j DNAT --to-destination "$FREEPBX_IP"
fi

echo "⏳ Esperando que la DB esté lista..."
sleep 15

# Instalar FreePBX si no está instalado
if ! docker compose exec freepbx test -f /etc/freepbx.conf 2>/dev/null; then
  echo "📦 Primera ejecución: instalando FreePBX..."
  docker compose exec -w /usr/local/src/freepbx freepbx \
    php install -n \
    --dbuser="${MYSQL_USER}" \
    --dbpass="${MYSQL_PASSWORD}" \
    --dbhost=db
fi

echo "✅ FreePBX listo en http://$(hostname -I | awk '{print $1}')"

if [ "$SILENT" = false ]; then
  echo "📋 Mostrando logs (Ctrl+C para salir)..."
  docker compose logs -f
fi
