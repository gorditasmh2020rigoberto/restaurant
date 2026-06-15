# ETAPA 1: Compilación de la aplicación
FROM debian:stable-slim AS build-env

# Instalar dependencias esenciales
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    ca-certificates \
    && apt-get clean

# Descargar Flutter SDK
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Configurar Flutter
RUN flutter channel stable
RUN flutter upgrade

# Configurar el directorio de trabajo
WORKDIR /app

# Copiar archivos del proyecto
COPY . .

# Obtener dependencias y compilar para web. La GOOGLE_MAPS_API_KEY se
# inyecta en runtime vía env-config.js (ver docker-entrypoint.sh), no
# en build time, porque EasyPanel solo pasa env vars al container al
# arrancar (no al docker build).
RUN flutter pub get
RUN flutter build web --release --no-tree-shake-icons --pwa-strategy=none

# ETAPA 2: Servir con Nginx (Servidor Web)
FROM nginx:alpine

# Copiar el resultado de la etapa anterior al directorio de Nginx
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Script que genera /usr/share/nginx/html/env-config.js a partir de las
# variables de entorno del container ANTES de iniciar nginx. Permite que
# EasyPanel inyecte GOOGLE_MAPS_API_KEY en runtime sin re-buildear.
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
