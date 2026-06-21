# Kitchen Display

Convierte una Raspberry Pi con Raspberry Pi OS Desktop en una pantalla
de cocina (kiosko): arranca sola al boot y abre Chromium fullscreen
apuntando al `kitchen_view` de la PWA.

```
┌──────────────────────────────┐
│  GORDITAS MIS HERMANAS       │
│  Sucursal Maravillas         │
│  ──────────────────────────  │
│   ◯  Mesa 5  · Mario         │
│      2 x Gordita de asada    │
│      1 x Refresco Coca       │
│                              │
│   ◯  Mesa 2  · Lupita        │
│      1 x Quesadilla maíz     │
└──────────────────────────────┘
```

## Pre-requisitos

- **Raspberry Pi OS Desktop** (Bookworm, 32-bit o 64-bit). El **Lite** NO sirve — necesita entorno gráfico.
- Conexión a internet.
- Acceso SSH o teclado + monitor para correr el instalador.
- La PWA ya deployada en alguna URL accesible (típicamente HTTPS).

## Instalación

Desde la Pi (SSH o terminal local):

```bash
# 1. Clona el repo o copia solo este folder.
cd ~
git clone https://github.com/mleyva2003/restaurant_pwa.git
cd restaurant_pwa/kitchen-display

# 2. Corre el instalador (NO como root — usa sudo internamente).
chmod +x install.sh
./install.sh
```

Te va a preguntar:
1. **URL base de la PWA** — p.ej. `https://restaurant-pwa.tu-dominio.com`.
2. **Vista** — `cocina` (todo) / `cocina-llevar` / `barra`.

Después:

```bash
sudo reboot
```

Al volver, Chromium debe abrir solo en fullscreen mostrando la kitchen view.

## Qué hace el instalador

1. Instala `chromium-browser`, `unclutter` (oculta cursor), `xdotool`, `xscreensaver`.
2. Guarda la config en `~/.kitchen-display.conf`.
3. Copia `start-display.sh` a `~/.kitchen-display/`.
4. Crea un autostart entry en `~/.config/autostart/kitchen-display.desktop`.
5. Deshabilita el screensaver y el blanking de pantalla (`xset` en `~/.config/lxsession/LXDE-pi/autostart`).

## Cómo funciona en runtime

El autostart corre `start-display.sh`, que:
1. Lee `~/.kitchen-display.conf`.
2. Aplica `xset` para que no se apague la pantalla.
3. Lanza `unclutter` (cursor invisible tras 0.5 s).
4. Limpia el flag de "Chromium crasheó" para que no salga el banner amarillo de restaurar pestañas.
5. Lanza Chromium en kiosk mode (`--kiosk --noerrdialogs --disable-session-crashed-bubble ...`).
6. Si Chromium muere (crash, Alt+F4), espera 3 s y lo relanza en loop infinito.

## Cambiar URL o vista después

Edita `~/.kitchen-display.conf`:

```bash
nano ~/.kitchen-display.conf
```

Cambia `KITCHEN_URL` o `KITCHEN_VIEW`, después:

```bash
# Mata Chromium — el loop lo relanza con la nueva config en 3 s
pkill -x chromium-browser
# O reinicia la Pi
sudo reboot
```

## Salir temporalmente del kiosko

- `Alt+F4` → cierra Chromium. El loop lo relanza en 3 s. Si necesitas más tiempo (p.ej. para actualizar el sistema):
  ```bash
  pkill -f start-display.sh   # mata el loop
  pkill -x chromium-browser   # mata Chromium
  ```
- Para volver: corre `~/.kitchen-display/start-display.sh &` o `sudo reboot`.

## Desinstalar

```bash
rm -rf ~/.kitchen-display ~/.kitchen-display.conf ~/.config/autostart/kitchen-display.desktop
# (Opcional) quita las líneas de xset del LX autostart
sed -i '/^@xset/d' ~/.config/lxsession/LXDE-pi/autostart
```

## Convivencia con el print-worker

Si en esta misma Pi corres también el `print-worker`:

- **Solo pantalla** — pon `DISPLAY_MODE=screen` en `~/print-worker/.env` y `sudo systemctl restart print-worker`. El worker sigue corriendo (para Realtime, logs, etc.) pero no manda nada a la impresora.
- **Solo impresora** — quita `DISPLAY_MODE` (o ponla en `printer`) y desinstala el kitchen-display (no usas la pantalla).
- **Ambos** — actualmente no implementado en backend; el worker es binario printer/screen. Si lo necesitas, lo añadimos.

## Troubleshooting

| Síntoma | Causa probable | Fix |
|---|---|---|
| Chromium abre pero pide login Wi-Fi | Pi no tiene internet | Configura Wi-Fi en `raspi-config` o conecta Ethernet. |
| Pantalla se apaga después de 10 min | El `xset` no se aplicó | Verifica `~/.config/lxsession/LXDE-pi/autostart`; debe tener `@xset s off`, `@xset -dpms`. |
| Sale el banner "¿Restaurar pestañas?" | Chromium crasheó la sesión previa | El script limpia esto, pero si insiste: borra `~/.config/chromium/Default/Preferences`. |
| Carga la URL pero pide login de mesero | La PWA requiere login para la kitchen view | Login una vez con el user de cocina y deja que se persista en el local storage de Chromium. |
| Texto demasiado chico/grande | Resolución del monitor | Ajusta zoom default de Chromium o resolución de la Pi en `raspi-config`. |
| No hay sonido de notificación | Browser bloquea autoplay de audio | Click una vez en la página (o usa una URL con interacción previa). |

## Pruebas

Manualmente, sin reboot:

```bash
~/.kitchen-display/start-display.sh
```

Chromium debe abrir fullscreen. Ctrl+C en la terminal mata el loop.
