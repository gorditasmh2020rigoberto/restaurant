# Kitchen Display Lite (Python)

Versión **ligera** del kitchen display, en Python + Tkinter. Pensada para Raspberry Pi Zero 2W o cualquier Pi con menos de 1 GB de RAM donde Chromium no es viable.

## Comparación con `kitchen-display/` (Chromium)

| | `kitchen-display/` | `kitchen-display-lite/` (este) |
|---|---|---|
| Tech | Chromium + PWA Flutter | Python + Tkinter |
| RAM en runtime | ~400-600 MB | ~30-50 MB |
| Pi mínima | Pi 3B+ (1 GB) | Pi Zero 2W (512 MB) ✅ |
| Mismo render que la PWA | Sí (es la PWA) | No — UI separada, solo visualiza |
| Marcar órdenes desde la pantalla | Sí | No, usa el móvil del mesero |
| Necesita la PWA deployada | Sí | No — habla directo a Supabase |

## Pre-requisitos

- Raspberry Pi OS Desktop (no Lite — necesita X server para Tkinter).
- Python 3 (viene preinstalado en Raspberry Pi OS).
- `python3-tk` (lo instala el script).
- WiFi/Ethernet.
- Tu `SUPABASE_SERVICE_KEY` a la mano (Dashboard Supabase → Settings → API Keys → Secret key).

## Instalación

```bash
# En la Pi (SSH o terminal local)
cd ~
git clone https://github.com/mleyva2003/restaurant_pwa.git
cd restaurant_pwa/kitchen-display-lite
chmod +x install.sh
./install.sh
```

Te va a preguntar:
- `SUPABASE_URL` (p.ej. `https://jcaqolmacqhhgtjdgvaz.supabase.co`)
- `SUPABASE_SERVICE_KEY` (la pegas, se guarda con permisos 600)
- `BRANCH_NAME` (exacto como está en `orders.branch_name`, p.ej. `Sucursal Maravillas`)
- `RESTAURANT_NAME` (para el header)
- `KITCHEN_VIEW`: 1=cocina (comida), 2=cocina-llevar, 3=barra (bebidas)

Después:

```bash
~/.kitchen-display-lite/start.sh   # prueba manual (Escape para salir)
sudo reboot                         # arranque automático en cada boot
```

## Cómo funciona

- **Poll**: cada 3 s hace GET al REST de Supabase pidiendo órdenes con `sent_to_kitchen_at IS NOT NULL` de tu sucursal, con JOIN a `restaurant_tables`, `waiters`, `order_items.dishes`.
- **Render**: cada orden es una "card" con mesa/mesero/hora arriba, items debajo (qty × nombre + guisados).
- **Filtro por vista**:
  - `cocina`: items que NO son bebidas.
  - `cocina-llevar`: items de comida cuyo `order_type` es to_go/delivery.
  - `barra`: solo items con categoría drink/alcohol/bebidas.
- **Marcado**: si un `order_item` ya tiene `printed_at`, no se muestra (asumiendo que el print-worker o la PWA lo marcó como listo/impreso).

## Convivencia con la impresora (`print-worker`)

Esta pantalla y la impresora pueden coexistir. Casos:

- **Solo pantalla en esta Pi** — no instales `print-worker`, listo.
- **Pantalla en esta Pi, impresora en otra Pi de la misma sucursal** — perfectamente válido. La pantalla muestra todo y los meseros van por el ticket físico.
- **Pantalla + impresora en la MISMA Pi** — funciona, pero el `print-worker` debe estar con `DISPLAY_MODE=printer` (o sin la var). Si pones `DISPLAY_MODE=screen` el worker no imprime y solo tienes pantalla.

## Editar config después

```bash
nano ~/.kitchen-display.conf
pkill -f kitchen_display.py   # el wrapper start.sh la relanza con la nueva config
```

## Logs

Stdout/stderr del Python se guardan en `~/.kitchen-display-lite.log`. Para verlo en vivo:

```bash
tail -f ~/.kitchen-display-lite.log
```

## Desinstalar

```bash
rm -rf ~/.kitchen-display-lite ~/.config/autostart/kitchen-display-lite.desktop
rm ~/.kitchen-display.conf
```

## Troubleshooting

| Síntoma | Causa | Fix |
|---|---|---|
| "Faltan vars en ~/.kitchen-display.conf" | El archivo no existe o le faltan keys | Re-corre `install.sh`. |
| "✘ Sin conexión" en el status bar | Sin internet o URL mal | Verifica WiFi (`ping 8.8.8.8`) y `SUPABASE_URL`. |
| "401 Unauthorized" o "JWT expired" | Service key mal | Rota la key en el dashboard, edita `~/.kitchen-display.conf`. |
| Pantalla vacía con "Sin órdenes pendientes" | Filtro de view o sucursal | Verifica `BRANCH_NAME` exacto y que sí haya órdenes con `sent_to_kitchen_at NOT NULL` en la BD. |
| App crashea / no abre | Tkinter mal | `sudo apt install python3-tk` manualmente; corre `python3 ~/.kitchen-display-lite/kitchen_display.py` para ver el error. |
| Texto muy chico | Resolución del monitor | Edita `kitchen_display.py`, busca `size=` en los `tkfont.Font(...)` y subes los números. |

## Limitaciones (vs versión Chromium)

- Solo VISUALIZA, no permite marcar "listo" desde la pantalla (todavía).
- No tiene sonido de notificación (se puede agregar fácilmente con `aplay` en `render_card` cuando `is_new=True`).
- El estilo es básico (oscuro, monospace) — se puede pulir editando colores en `kitchen_display.py`.
- No usa Realtime websocket, sino polling cada 3 s — latencia max 3 s desde que el mesero envía a cocina hasta que aparece.
