#!/usr/bin/env bash
# Instalador del print-worker para Raspberry Pi (Raspberry Pi OS / Debian).
#
# Pensado para desplegar VARIAS Pis en la misma sucursal, cada una con
# un rol distinto (bebidas, cocina, para llevar, cuenta/caja) vía la
# variable PRINT_AREA — ver print-worker/README.md, sección "Varias
# Pis en la misma sucursal".
#
# Uso: copia/clona la carpeta print-worker/ completa en la Pi, entra a
# ella y corre:
#   ./install.sh

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
say()  { echo -e "${GREEN}▶${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
die()  { echo -e "${RED}✘${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "No corras como root."
command -v apt-get >/dev/null || die "Este instalador es para Debian/Raspberry Pi OS."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ -f index.js ]] || die "No encuentro index.js en $SCRIPT_DIR — corre este script desde dentro de print-worker/."

ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  say "Ya existe un .env en $SCRIPT_DIR — vuelvo a preguntar (Enter para mantener el valor actual)."
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

# ── Node.js (Raspberry Pi OS suele traer una versión vieja) ──────────
NODE_OK=false
if command -v node >/dev/null; then
  NODE_MAJOR="$(node -v | sed 's/^v//' | cut -d. -f1)"
  [[ "$NODE_MAJOR" -ge 18 ]] && NODE_OK=true
fi
if [[ "$NODE_OK" != true ]]; then
  say "Instalando Node.js LTS (20.x)…"
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y -qq nodejs
else
  say "Node.js $(node -v) ya está listo."
fi

# ── Preguntas ─────────────────────────────────────────────────────────
DEFAULT_URL="${SUPABASE_URL:-https://YOUR-PROJECT.supabase.co}"
echo
read -r -p "SUPABASE_URL [$DEFAULT_URL]: " IN
SUPABASE_URL="${IN:-$DEFAULT_URL}"
SUPABASE_URL="${SUPABASE_URL%/}"

echo
echo "SUPABASE_SERVICE_KEY (Dashboard → Project Settings → API → service_role)."
echo "NO es la anon key. No la compartas fuera de este .env."
read -r -p "SUPABASE_SERVICE_KEY${SUPABASE_SERVICE_KEY:+ [Enter = mantener la actual]}: " IN
SUPABASE_SERVICE_KEY="${IN:-${SUPABASE_SERVICE_KEY:-}}"
[[ -n "$SUPABASE_SERVICE_KEY" ]] || die "Sin SUPABASE_SERVICE_KEY no podemos seguir."

DEFAULT_BRANCH="${BRANCH_NAME:-Sucursal Maravillas}"
echo
echo "BRANCH_NAME debe coincidir EXACTO con orders.branch_name (incluye el"
echo "prefijo \"Sucursal \")."
read -r -p "BRANCH_NAME [$DEFAULT_BRANCH]: " IN
BRANCH_NAME="${IN:-$DEFAULT_BRANCH}"

echo
echo "¿Qué imprime esta Pi?"
echo "  1) Bebidas / bar        → PRINT_AREA=drinks"
echo "  2) Cocina (comer aquí)  → PRINT_AREA=kitchen, PRINT_ORDER_TYPES=dine_in"
echo "  3) Para llevar          → PRINT_AREA=takeout"
echo "  4) Cuenta / caja        → PRINT_AREA=receipt"
echo "  5) Todo en uno (cocina+bar en la misma Pi, sin dividir)"
DEFAULT_AREA_CHOICE="1"
case "${PRINT_AREA:-}" in
  drinks) DEFAULT_AREA_CHOICE=1 ;;
  kitchen) DEFAULT_AREA_CHOICE=2 ;;
  takeout) DEFAULT_AREA_CHOICE=3 ;;
  receipt) DEFAULT_AREA_CHOICE=4 ;;
  '') [[ -n "${BRANCH_NAME:-}" && -f "$ENV_FILE" ]] && DEFAULT_AREA_CHOICE=5 ;;
esac
read -r -p "Elige (1-5) [$DEFAULT_AREA_CHOICE]: " AREA_CHOICE
AREA_CHOICE="${AREA_CHOICE:-$DEFAULT_AREA_CHOICE}"
PRINT_ORDER_TYPES=""
case "$AREA_CHOICE" in
  1) PRINT_AREA="drinks" ;;
  2) PRINT_AREA="kitchen"; PRINT_ORDER_TYPES="dine_in" ;;
  3) PRINT_AREA="takeout" ;;
  4) PRINT_AREA="receipt" ;;
  5) PRINT_AREA="" ;;
  *) die "Opción inválida." ;;
esac

DEFAULT_DEVICE="${PRINTER_DEVICE:-/dev/usb/lp0}"
echo
read -r -p "PRINTER_DEVICE (Linux/USB) [$DEFAULT_DEVICE]: " IN
PRINTER_DEVICE="${IN:-$DEFAULT_DEVICE}"

DEFAULT_RESTAURANT="${RESTAURANT_NAME:-GORDITAS MIS HERMANAS}"
echo
read -r -p "RESTAURANT_NAME (encabezado del ticket) [$DEFAULT_RESTAURANT]: " IN
RESTAURANT_NAME="${IN:-$DEFAULT_RESTAURANT}"

# ── Grupo lp (acceso al device USB de la impresora) ──────────────────
if ! id -nG "$USER" | grep -qw lp; then
  say "Agregando $USER al grupo 'lp' (acceso a $PRINTER_DEVICE)…"
  sudo usermod -aG lp "$USER"
  warn "Necesitas cerrar sesión y volver a entrar (o reiniciar) para que aplique."
fi

# ── Escribir .env ─────────────────────────────────────────────────────
say "Guardando configuración en $ENV_FILE"
cat > "$ENV_FILE" <<EOF
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_KEY=$SUPABASE_SERVICE_KEY
PRINTER_DEVICE=$PRINTER_DEVICE
BRANCH_NAME=$BRANCH_NAME
RESTAURANT_NAME=$RESTAURANT_NAME
PRINT_AREA=$PRINT_AREA
PRINT_ORDER_TYPES=$PRINT_ORDER_TYPES
DRY_RUN=false
EOF
chmod 600 "$ENV_FILE"

# ── Dependencias ──────────────────────────────────────────────────────
say "Instalando dependencias (npm install)…"
npm install --silent

# ── Servicio systemd (arranca solo, se reinicia si crashea) ──────────
SERVICE_FILE="/etc/systemd/system/print-worker.service"
say "Configurando servicio systemd en $SERVICE_FILE"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Restaurant print-worker (${PRINT_AREA:-todo-en-uno})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$(command -v node) $SCRIPT_DIR/index.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable print-worker
sudo systemctl restart print-worker

echo
say "${GREEN}✓ Instalación completa.${NC}  Rol: ${PRINT_AREA:-todo-en-uno} — Sucursal: $BRANCH_NAME"
echo
echo "Ver logs en vivo:      sudo journalctl -u print-worker -f"
echo "Reiniciar el worker:   sudo systemctl restart print-worker"
echo "Editar config después: nano $ENV_FILE   (y systemctl restart print-worker)"
