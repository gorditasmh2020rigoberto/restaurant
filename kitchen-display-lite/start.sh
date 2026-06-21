#!/usr/bin/env bash
# Wrapper que lanza kitchen_display.py en loop (relanza si crashea).
# Lo invoca el .desktop autostart — no lo corras manualmente excepto para debug.

set -u

# Anti-screensaver/blanking en runtime
xset s noblank >/dev/null 2>&1 || true
xset s off     >/dev/null 2>&1 || true
xset -dpms     >/dev/null 2>&1 || true

# Esconder cursor del mouse tras inactividad
pkill -x unclutter >/dev/null 2>&1 || true
unclutter -idle 0.5 -root >/dev/null 2>&1 &

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$SCRIPT_DIR/kitchen_display.py"

[[ -f "$APP" ]] || { echo "✘ No encuentro $APP"; exit 1; }

# Loop: si Python crashea, espera 3 s y relanza.
while true; do
  python3 "$APP" 2>&1 | tee -a "$HOME/.kitchen-display-lite.log"
  sleep 3
done
