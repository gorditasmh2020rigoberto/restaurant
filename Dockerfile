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

# Build arg para la API key de Google Maps. Se pasa al build de Flutter
# con --dart-define para que quede embebida en el bundle JS. Si EasyPanel
# no la define, queda vacía y la app cae al geocoder OSM (gratis) como
# fallback.
ARG GOOGLE_MAPS_API_KEY=""

# Obtener dependencias y compilar para web
RUN flutter pub get
RUN flutter build web --release --no-tree-shake-icons --pwa-strategy=none \
    --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}"

# ETAPA 2: Servir con Nginx (Servidor Web)
FROM nginx:alpine

# Copiar el resultado de la etapa anterior al directorio de Nginx
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponer el puerto 80 (el puerto web estándar)
EXPOSE 80

# Comando de arranque del servidor Nginx 
CMD ["nginx", "-g", "daemon off;"]
