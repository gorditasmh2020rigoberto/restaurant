# syntax=docker/dockerfile:1.7

# ─── ETAPA 1: Compilación de la app Flutter Web ────────────────────────
#
# Imagen prebuilt de Flutter (cirruslabs es el estándar de facto en CI).
# Ahorra ~2-3 min por deploy vs el flujo anterior que (1) hacía
# `apt-get install` de curl/git/wget/unzip, (2) `git clone` del repo de
# flutter (~100 MB), y (3) `flutter channel stable && flutter upgrade`.
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

# La imagen cirruslabs usa el user `cirrus` por defecto; forzamos root
# para evitar issues de permisos al COPY/build.
USER root

WORKDIR /app

# 1) Copiar SOLO los manifests primero. El layer de `pub get` se cachea
#    así entre builds y solo se re-corre si cambian las dependencias,
#    no en cada commit. Sin esto, cualquier cambio en `lib/` invalida
#    el caché y se re-descargan ~150 MB de paquetes cada deploy.
COPY pubspec.yaml pubspec.lock ./

# 2) `pub get` con cache mount persistente (BuildKit). Los paquetes
#    descargados sobreviven a invalidaciones del layer.
RUN --mount=type=cache,target=/root/.pub-cache \
    flutter pub get

# 3) Ahora sí copiamos el resto del código fuente.
COPY . .

# 4) Build web. La GOOGLE_MAPS_API_KEY se inyecta en runtime vía
#    env-config.js (ver docker-entrypoint.sh), no en build time, porque
#    EasyPanel solo pasa env vars al container al arrancar (no al
#    `docker build`).
RUN --mount=type=cache,target=/root/.pub-cache \
    flutter build web --release --no-tree-shake-icons --pwa-strategy=none

# ─── ETAPA 2: Servir con Nginx ─────────────────────────────────────────
FROM nginx:alpine

# Copia el resultado del build al directorio de Nginx
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Entrypoint genera /usr/share/nginx/html/env-config.js a partir de las
# env vars del container ANTES de iniciar nginx. Permite que EasyPanel
# inyecte GOOGLE_MAPS_API_KEY en runtime sin re-buildear.
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
