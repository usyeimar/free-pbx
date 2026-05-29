#!/usr/bin/env bash
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' B='\033[1;34m'
W='\033[1;37m' N='\033[0m' DIM='\033[2m'

banner() {
echo ""
echo -e "  ${B}███████╗██████╗ ███████╗███████╗██████╗ ██████╗ ██╗  ██╗${N}"
echo -e "  ${B}██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗╚██╗██╔╝${N}"
echo -e "  ${B}█████╗  ██████╔╝█████╗  █████╗  ██████╔╝██████╔╝ ╚███╔╝ ${N}"
echo -e "  ${B}██╔══╝  ██╔══██╗██╔══╝  ██╔══╝  ██╔═══╝ ██╔══██╗ ██╔██╗ ${N}"
echo -e "  ${B}██║     ██║  ██║███████╗███████╗██║     ██████╔╝██╔╝ ██╗${N}"
echo -e "  ${B}╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═════╝ ╚═╝  ╚═╝${N}"
echo -e "                         ${W}PBX 17${N}"
echo ""
}

log()  { echo -e "  ${C}[$(date +%H:%M:%S)]${N} $1"; }
ok()   { echo -e "  ${G}[$(date +%H:%M:%S)] ✔${N} $1"; }
warn() { echo -e "  ${Y}[$(date +%H:%M:%S)] ⚠${N} $1"; }
info() { echo -e "  ${DIM}  ├─${N} $1"; }
last() { echo -e "  ${DIM}  └─${N} $1"; }
sep()  { echo -e "  ${DIM}─────────────────────────────────────────────────────────${N}"; }

# Asegurar links de CLI
for cli in fwconsole amportal; do
  target="/var/lib/asterisk/bin/${cli}"
  [[ -e "$target" ]] && ln -sfn "$target" "/usr/sbin/${cli}"
done

banner
sep
echo -e "  ${W}SISTEMA${N}"
info "OS:          $(cat /etc/os-release 2>/dev/null | grep PRETTY | cut -d= -f2 | tr -d '\"')"
info "Kernel:      $(uname -r)"
info "Hostname:    $(hostname)"
info "IP:          $(hostname -I 2>/dev/null | awk '{print $1}')"
info "CPU:         $(nproc) cores"
info "RAM:         $(free -h 2>/dev/null | awk '/Mem:/{print $2}') total"
last "Timezone:    ${TZ:-UTC}"
echo ""

sep
echo -e "  ${W}COMPONENTES${N}"
info "Asterisk:    $(asterisk -V 2>/dev/null || echo 'no disponible')"
info "PHP:         $(php -v 2>/dev/null | head -1 | awk '{print $2}')"
info "Apache:      $(apache2ctl -v 2>/dev/null | head -1 | awk -F/ '{print $2}' | awk '{print $1}')"
info "Node.js:     $(node -v 2>/dev/null || echo 'no disponible')"
last "FreePBX:     $(test -f /etc/freepbx.conf && echo '17 (instalado)' || echo 'pendiente de instalar')"
echo ""

# Iniciar servicios
sep
echo -e "  ${W}SERVICIOS${N}"

log "Iniciando cron..."
/usr/sbin/cron &
ok "Cron activo"

log "Iniciando Postfix..."
service postfix start 2>/dev/null && ok "Postfix activo" || warn "Postfix no disponible"

log "Iniciando Asterisk..."
/usr/local/src/freepbx/start_asterisk start 2>/dev/null &
sleep 3
if asterisk -rx "core show version" &>/dev/null; then
  ok "Asterisk activo (PID: $(pidof asterisk 2>/dev/null | awk '{print $1}'))"
  AST_CHANNELS=$(asterisk -rx "core show channels count" 2>/dev/null | grep "active channel" | awk '{print $1}' || echo "0")
  AST_MODULES=$(asterisk -rx "module show" 2>/dev/null | tail -1 | awk '{print $1}' || echo "N/A")
  AST_RTP_START=$(grep -i "rtpstart" /etc/asterisk/rtp.conf 2>/dev/null | awk -F= '{print $2}' || echo "16384")
  AST_RTP_END=$(grep -i "rtpend" /etc/asterisk/rtp.conf 2>/dev/null | awk -F= '{print $2}' || echo "32767")
  info "Canales:     $AST_CHANNELS activos"
  info "Módulos:     $AST_MODULES cargados"
  last "RTP:         $AST_RTP_START - $AST_RTP_END"
else
  warn "Asterisk no respondió"
fi
echo ""

# Apache (foreground al final)
sep
echo -e "  ${W}APACHE${N}"
log "Iniciando Apache..."

# Resumen final
IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
echo ""
sep
echo ""
echo -e "  ${G}┌─────────────────────────────────────────────────────────┐${N}"
echo -e "  ${G}│  ${W}✔ FreePBX 17 — Listo${G}                                   │${N}"
echo -e "  ${G}│                                                         │${N}"
echo -e "  ${G}│  ${N}Web Panel    ${C}http://${IP_ADDR}${N}"
echo -e "  ${G}│  ${N}HTTPS        ${C}https://${IP_ADDR}${N}"
echo -e "  ${G}│  ${N}PJSIP        ${C}${IP_ADDR}:5060 (UDP)${N}"
echo -e "  ${G}│  ${N}RTP          ${C}${AST_RTP_START:-16384}-${AST_RTP_END:-32767} (UDP)${N}"
echo -e "  ${G}│  ${N}MariaDB      ${C}db:3306 (contenedor separado)${N}"
echo -e "  ${G}│                                                         │${N}"
echo -e "  ${G}└─────────────────────────────────────────────────────────┘${N}"
echo ""
echo -e "  ${DIM}Comandos útiles:${N}"
echo -e "  ${DIM}  asterisk -rvvv              CLI de Asterisk${N}"
echo -e "  ${DIM}  fwconsole reload            Recargar FreePBX${N}"
echo -e "  ${DIM}  fwconsole ma list           Módulos instalados${N}"
echo ""

exec apache2ctl -D FOREGROUND
