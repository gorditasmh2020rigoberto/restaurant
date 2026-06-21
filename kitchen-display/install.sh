#!/usr/bin/env bash
# Instalador del kitchen-display para Raspberry Pi OS Desktop (32-bit).
#
# Convierte una Raspberry Pi con desktop en una pantalla de cocina:
# arranca sola al boot, abre Chromium en kiosk mode a la URL de
# kitchen_view de la PWA, sin cursor, sin screensaver, sin paneles.
#
# Uso:
#   chmod +x install.sh
#   ./install.sh
#
# Probado en: Raspberry Pi OS Bookworm Desktop (32-bit, 64-bit).
# Requiere conexión a internet y user con sudo (típicamente `pi` o el
# user creado al instalar Raspberry Pi OS).

set -euo pipefail

# ── Helpers ─────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
say()  { echo -e "${GREEN}▶${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
die()  { echo -e "${RED}✘${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "No corras este script como root. Corre como tu user normal; usa sudo internamente."
command -v apt-get >/dev/null || die "Este instalador es para Raspberry Pi OS (Debian). No detecto apt-get."

# ── 1) URL y modo ───────────────────────────────────────────────────
CONFIG_FILE="$HOME/.kitchen-display.conf"

if [[ -f "$CONFIG_FILE" ]]; then
  say "Config existente encontrada en $CONFIG_FILE. Vuelvo a preguntar valores (Enter para mantener)."
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

DEFAULT_URL="${KITCHEN_URL:-https://restaurant-pwa.your-domain.com}"
DEFAULT_VIEW="${KITCHEN_VIEW:-cocina}"

echo
read -r -p "URL base de la PWA (sin slash final) [$DEFAULT_URL]: " KITCHEN_URL_INPUT
KITCHEN_URL="${KITCHEN_URL_INPUT:-$DEFAULT_URL}"
KITCHEN_URL="${KITCHEN_URL%/}"  # strip trailing slash

echo
echo "Vista a mostrar:"
echo "  1) cocina         — comida + bebidas (vista completa)"
echo "  2) cocina-llevar  — solo pedidos para llevar"
echo "  3) barra          — solo bebidas (BAR)"
read -r -p "Elige (1/2/3) [default '$DEFAULT_VIEW']: " VIEW_CHOICE
case "${VIEW_CHOICE:-}" in
  1) KITCHEN_VIEW="cocina" ;;
  2) KITCHEN_VIEW="cocina-llevar" ;;
  3) KITCHEN_VIEW="barra" ;;
  "") KITCHEN_VIEW="$DEFAULT_VIEW" ;;
  *) die "Opción inválida: $VIEW_CHOICE" ;;
esac

# Flutter web sirve con hash routing por default ("/#/cocina").
FULL_URL="${KITCHEN_URL}/#/${KITCHEN_VIEW}"
say "URL final: $FULL_URL"

# ── 2) Instalar paquetes ────────────────────────────────────────────
say "Instalando paquetes (chromium, unclutter, xdotool)…"
sudo apt-get update -qq
sudo apt-get install -y -qq chromium-browser unclutter xdotool xscreensaver

# ── 3) Guardar config ──────────────────────────────────────────────
say "Guardando configuración en $CONFIG_FILE"
cat > "$CONFIG_FILE" <<EOF
# kitchen-display config — generado por install.sh
# Editar manualmente y reiniciar la Pi para aplicar.
KITCHEN_URL="$KITCHEN_URL"
KITCHEN_VIEW="$KITCHEN_VIEW"
EOF

# ── 4) Copiar start script ─────────────────────────────────────────
INSTALL_DIR="$HOME/.kitchen-display"
mkdir -p "$INSTALL_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/start-display.sh" "$INSTALL_DIR/start-display.sh"
chmod +x "$INSTALL_DIR/start-display.sh"
say "Instalado: $INSTALL_DIR/start-display.sh"

# ── 5) Autostart desktop entry ─────────────────────────────────────
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
DESKTOP_FILE="$AUTOSTART_DIR/kitchen-display.desktop"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Kitchen Display
Comment=Pantalla de cocina (kiosk Chromium)
Exec=$INSTALL_DIR/start-display.sh
X-GNOME-Autostart-enabled=true
NoDisplay=false
Hidden=false
EOF
say "Autostart configurado: $DESKTOP_FILE"

# ── 6) Disable screen blanking globalmente ─────────────────────────
say "Deshabilitando screensaver y screen blanking."
# Crea ~/.config/lxsession/LXDE-pi/autostart si no existe y agrega xset cmds
LX_AUTOSTART="$HOME/.config/lxsession/LXDE-pi/autostart"
if [[ ! -f "$LX_AUTOSTART" ]]; then
  mkdir -p "$(dirname "$LX_AUTOSTART")"
  # Copia el global como punto de partida si existe
  [[ -f /etc/xdg/lxsession/LXDE-pi/autostart ]] && cp /etc/xdg/lxsession/LXDE-pi/autostart "$LX_AUTOSTART"
fi
touch "$LX_AUTOSTART"
# Agrega las líneas si no están
grep -q '^@xset s noblank' "$LX_AUTOSTART" || echo '@xset s noblank' >> "$LX_AUTOSTART"
grep -q '^@xset s off'     "$LX_AUTOSTART" || echo '@xset s off'     >> "$LX_AUTOSTART"
grep -q '^@xset -dpms'     "$LX_AUTOSTART" || echo '@xset -dpms'     >> "$LX_AUTOSTART"

# ── 7) Listo ────────────────────────────────────────────────────────
echo
say "${GREEN}✓ Instalación completa.${NC}"
echo
echo "Próximos pasos:"
echo "  1. Reinicia la Pi:  sudo reboot"
echo "  2. Al volver: Chromium debe abrir solo en fullscreen mostrando"
echo "                $FULL_URL"
echo
echo "Para cambiar URL/vista después:"
echo "  - Edita ~/.kitchen-display.conf"
echo "  - sudo reboot (o mata Chromium y se relanza)"
echo
echo "Para SALIR del modo kiosko temporalmente:"
echo "  - Alt+F4 (cierra Chromium); el script tiene un loop que lo relanza"
echo "  - Para deshabilitar el autostart: rm $DESKTOP_FILE"
echo
warn "Si vas a usar esta Pi también con impresora, recuerda que el"
warn "print-worker (DISPLAY_MODE=screen) debe estar configurado para"
warn "que NO imprima desde esta sucursal."
