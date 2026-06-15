#!/bin/sh
# Genera env-config.js en /usr/share/nginx/html ANTES de iniciar nginx,
# inyectando las variables de entorno del container como propiedades
# de window.* para que Flutter las pueda leer al cargar.
set -e

cat > /usr/share/nginx/html/env-config.js <<EOF
// Auto-generado por docker-entrypoint.sh en cada arranque del container.
window.GOOGLE_MAPS_API_KEY = "${GOOGLE_MAPS_API_KEY:-}";
EOF

echo "env-config.js generado:"
cat /usr/share/nginx/html/env-config.js

exec "$@"
