#!/usr/bin/env bash
# Lanza Chromium en kiosk mode apuntando a la kitchen_view de la PWA.
# Lo invoca el autostart entry creado por install.sh — no lo corras
# manualmente a menos que estés debuggeando.
#
# Loop: si Chromium muere (crash, Alt+F4), espera 3 s y lo relanza.

set -u

CONFIG_FILE="$HOME/.kitchen-display.conf"
[[ -f "$CONFIG_FILE" ]] || { echo "✘ No encuentro $CONFIG_FILE. Corre install.sh primero."; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${KITCHEN_URL:?KITCHEN_URL no definido en $CONFIG_FILE}"
: "${KITCHEN_VIEW:?KITCHEN_VIEW no definido en $CONFIG_FILE}"

FULL_URL="${KITCHEN_URL%/}/#/${KITCHEN_VIEW}"

# Anti-screensaver/blanking en runtime (por si el LX autostart no aplicó).
xset s noblank >/dev/null 2>&1 || true
xset s off     >/dev/null 2>&1 || true
xset -dpms     >/dev/null 2>&1 || true

# Oculta el cursor del mouse tras 0.5 s de inactividad.
pkill -x unclutter >/dev/null 2>&1 || true
unclutter -idle 0.5 -root >/dev/null 2>&1 &

# Limpia estado anterior de Chromium que podría hacer que pregunte
# "¿Restaurar pestañas?" o "Chromium no se cerró correctamente".
PROFILE_DIR="$HOME/.config/chromium/Default"
[[ -f "$PROFILE_DIR/Preferences" ]] && \
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"Crashed"/"exit_type":"Normal"/' \
    "$PROFILE_DIR/Preferences" 2>/dev/null || true

# Detecta el binario de Chromium (varía según versión de Raspberry Pi OS).
CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium || true)"
[[ -n "$CHROMIUM_BIN" ]] || { echo "✘ No encuentro chromium-browser ni chromium en PATH."; exit 1; }

# Loop infinito: si Chromium muere, espera 3 s y lo relanza.
while true; do
  "$CHROMIUM_BIN" \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --no-first-run \
    --start-fullscreen \
    --check-for-update-interval=31536000 \
    --overscroll-history-navigation=0 \
    --disable-pinch \
    "$FULL_URL" \
    >/dev/null 2>&1
  sleep 3
done
