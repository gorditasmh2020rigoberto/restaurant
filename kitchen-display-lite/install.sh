#!/usr/bin/env bash
# Instalador del kitchen-display-lite (versión Python) para Raspberry Pi
# Zero 2W o cualquier Pi con poca RAM (<1 GB).
#
# Diferencias con kitchen-display/ (versión Chromium):
# - Usa Tkinter (built-in) y polling REST a Supabase. No browser.
# - ~30-50 MB RAM en runtime (vs 400+ MB de Chromium).
# - No requiere que la PWA esté deployada en una URL pública — habla
#   directo a Supabase.
# - Limitación: solo VISUALIZA. Para marcar órdenes como listas, usa
#   la PWA en otro dispositivo (móvil del mesero).

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
say()  { echo -e "${GREEN}▶${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
die()  { echo -e "${RED}✘${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "No corras como root."
command -v apt-get >/dev/null || die "Este instalador es para Debian/Raspberry Pi OS."

CONFIG_FILE="$HOME/.kitchen-display.conf"

if [[ -f "$CONFIG_FILE" ]]; then
  say "Config existente en $CONFIG_FILE — vuelvo a preguntar (Enter para mantener)."
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

DEFAULT_URL="${SUPABASE_URL:-https://YOUR-PROJECT.supabase.co}"
DEFAULT_BRANCH="${BRANCH_NAME:-Sucursal Maravillas}"
DEFAULT_VIEW="${KITCHEN_VIEW:-cocina}"
DEFAULT_RESTAURANT="${RESTAURANT_NAME:-GORDITAS MIS HERMANAS}"

echo
read -r -p "SUPABASE_URL [$DEFAULT_URL]: " IN
SUPABASE_URL="${IN:-$DEFAULT_URL}"
SUPABASE_URL="${SUPABASE_URL%/}"

echo
echo "SUPABASE_SERVICE_KEY — la pegas aquí y se guarda en $CONFIG_FILE"
echo "(empieza con 'sb_secret_' o 'eyJ...'). Dashboard Supabase → Settings → API Keys."
read -r -p "SUPABASE_SERVICE_KEY: " SUPABASE_SERVICE_KEY
[[ -n "$SUPABASE_SERVICE_KEY" ]] || die "Sin SUPABASE_SERVICE_KEY no podemos seguir."

echo
read -r -p "BRANCH_NAME exacto como está en la BD [$DEFAULT_BRANCH]: " IN
BRANCH_NAME="${IN:-$DEFAULT_BRANCH}"

echo
read -r -p "Nombre del restaurante para el header [$DEFAULT_RESTAURANT]: " IN
RESTAURANT_NAME="${IN:-$DEFAULT_RESTAURANT}"

echo
echo "Vista a mostrar:"
echo "  1) cocina         — comida (sin bebidas)"
echo "  2) cocina-llevar  — solo to_go / delivery"
echo "  3) barra          — solo bebidas"
read -r -p "Elige (1/2/3) [default '$DEFAULT_VIEW']: " VIEW_CHOICE
case "${VIEW_CHOICE:-}" in
  1) KITCHEN_VIEW="cocina" ;;
  2) KITCHEN_VIEW="cocina-llevar" ;;
  3) KITCHEN_VIEW="barra" ;;
  "") KITCHEN_VIEW="$DEFAULT_VIEW" ;;
  *) die "Opción inválida." ;;
esac

# ── Instalar python3-tk (Tkinter). El resto (urllib, json, etc.) viene built-in.
say "Instalando python3-tk…"
sudo apt-get update -qq
sudo apt-get install -y -qq python3 python3-tk unclutter

# ── Guardar config (con permisos restrictivos porque tiene service key)
say "Guardando configuración en $CONFIG_FILE"
cat > "$CONFIG_FILE" <<EOF
# kitchen-display-lite config — generado por install.sh
# CONTIENE LA SUPABASE_SERVICE_KEY — no compartas este archivo.
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_KEY=$SUPABASE_SERVICE_KEY
BRANCH_NAME=$BRANCH_NAME
RESTAURANT_NAME=$RESTAURANT_NAME
KITCHEN_VIEW=$KITCHEN_VIEW
POLL_INTERVAL_MS=3000
EOF
chmod 600 "$CONFIG_FILE"

# ── Copiar la app al $HOME y darle permisos
INSTALL_DIR="$HOME/.kitchen-display-lite"
mkdir -p "$INSTALL_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/kitchen_display.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/start.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/start.sh"
say "Instalado: $INSTALL_DIR/"

# ── Autostart entry
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
DESKTOP_FILE="$AUTOSTART_DIR/kitchen-display-lite.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Kitchen Display Lite
Comment=Pantalla de cocina (Python, low-RAM)
Exec=$INSTALL_DIR/start.sh
X-GNOME-Autostart-enabled=true
NoDisplay=false
Hidden=false
EOF
say "Autostart: $DESKTOP_FILE"

# ── Disable screen blanking
LX_AUTOSTART="$HOME/.config/lxsession/LXDE-pi/autostart"
if [[ ! -f "$LX_AUTOSTART" ]]; then
  mkdir -p "$(dirname "$LX_AUTOSTART")"
  [[ -f /etc/xdg/lxsession/LXDE-pi/autostart ]] && cp /etc/xdg/lxsession/LXDE-pi/autostart "$LX_AUTOSTART"
fi
touch "$LX_AUTOSTART"
grep -q '^@xset s noblank' "$LX_AUTOSTART" || echo '@xset s noblank' >> "$LX_AUTOSTART"
grep -q '^@xset s off'     "$LX_AUTOSTART" || echo '@xset s off'     >> "$LX_AUTOSTART"
grep -q '^@xset -dpms'     "$LX_AUTOSTART" || echo '@xset -dpms'     >> "$LX_AUTOSTART"
say "Screensaver/blanking deshabilitado."

# ── Si existe el autostart del Chromium version, ofrecer desactivarlo
CHROMIUM_AUTOSTART="$HOME/.config/autostart/kitchen-display.desktop"
if [[ -f "$CHROMIUM_AUTOSTART" ]]; then
  warn "Detecté el autostart del Chromium version en:"
  warn "  $CHROMIUM_AUTOSTART"
  read -r -p "¿Lo desactivo? (s/N): " ANS
  if [[ "${ANS,,}" == "s" || "${ANS,,}" == "y" ]]; then
    rm -f "$CHROMIUM_AUTOSTART"
    say "Eliminado."
  fi
fi

echo
say "${GREEN}✓ Instalación completa.${NC}"
echo
echo "Próximos pasos:"
echo "  1. Probar manualmente:  $INSTALL_DIR/start.sh"
echo "     (cierra con Escape; si la pantalla queda en negro reboot y debe abrir solo)"
echo "  2. Reiniciar para que arranque automático: sudo reboot"
echo
echo "Editar config después:"
echo "  nano $CONFIG_FILE"
echo "  pkill -f kitchen_display.py   # el autostart la relanza"
