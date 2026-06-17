# Print-worker

Mini servicio Node.js que corre en la mini-PC de cocina (Windows). Escucha la tabla `orders` de Supabase y manda cada orden nueva a la impresora térmica Star TSP143 conectada por USB.

```
┌────────────┐   realtime   ┌──────────────┐    ESC-POS    ┌──────────┐
│  Supabase  │ ───────────► │ print-worker │ ────────────► │ TSP143   │
│  (orders)  │              │  (Node.js)   │   via Windows │ (USB)    │
└────────────┘              └──────────────┘    spooler    └──────────┘
```

Marca cada orden como `printed_at = NOW()` después de imprimir, así no se duplican tickets ni cuando se reinicia el worker.

## Pre-requisitos en la mini-PC

1. **Windows 10 / 11** (probado en estos).
2. **Driver de la impresora** — Star *futurePRNT* o Star *LineMode*. Descárgalo de https://starmicronics.com/support/products/tsp100futureprnt/ y, durante la instalación, elige el modelo TSP143 USB. Al final debe aparecer la impresora en *Devices and Printers* con un nombre como `Star TSP143 (TSP100)`.
3. **Node.js LTS (18+)** — https://nodejs.org/ → descarga el `Windows Installer (.msi)` de la versión LTS y siguiente-siguiente-finalizar.

## Instalación del worker

1. **Clona o copia este folder** en la mini-PC, p. ej. `C:\restaurant\print-worker\`.

2. Abre **PowerShell** en esa carpeta y corre:
   ```powershell
   npm install
   ```
   Tarda 1-2 minutos. Crea `node_modules/`.

3. **Configura el `.env`** — copia la plantilla y llena los valores:
   ```powershell
   copy .env.example .env
   notepad .env
   ```
   Llena:
   - `SUPABASE_URL` — del dashboard de Supabase (Project Settings → API).
   - `SUPABASE_SERVICE_KEY` — la **service_role** key (no la anon). Te da acceso full a la BD; no la pegues en chats ni la subas a git.
   - `PRINTER_NAME` — el nombre EXACTO de la impresora en Windows. Para verlo: Panel de control → *Devices and Printers* → click derecho en la Star → *Printer properties* → pestaña *General* → campo *Name*.
   - `BRANCH_NAME` — el nombre de tu sucursal (debe coincidir con `orders.branch_name` en la BD; p. ej. `Maravillas`, `Pocitos`).

4. **Aplica la migración** en Supabase (solo una vez, en el dashboard SQL Editor):
   ```sql
   -- supabase/migrations/20260616050000_add_printed_at_to_orders.sql
   ALTER TABLE orders ADD COLUMN IF NOT EXISTS printed_at TIMESTAMPTZ NULL;
   ```
   *(Esta migración ya viene en el repo del PWA — si usas `supabase db push` se aplica sola.)*

5. **Prueba la impresora** — debe sacar un ticket de prueba:
   ```powershell
   npm run test-print
   ```
   Si dice `✘ Impresora no conectada`, revisa el cable USB y que el nombre en `.env` coincida exactamente con el de Windows.

6. **Arranca el worker**:
   ```powershell
   npm start
   ```
   Si todo está bien, verás:
   ```
   Print-worker iniciado | Sucursal: Maravillas | Impresora: Star TSP143 (TSP100)
   Realtime: SUBSCRIBED
   ```
   Manda una orden de prueba desde la PWA — el ticket debe salir en segundos.

## Que arranque solo al prender la mini-PC

Para que no tengas que abrir PowerShell cada vez, instálalo como **servicio de Windows** con [NSSM](https://nssm.cc/download):

1. Descarga NSSM, descomprime, y desde PowerShell **como administrador**:
   ```powershell
   nssm install RestauPrintWorker
   ```
2. En la ventana que abre:
   - *Path*: `C:\Program Files\nodejs\node.exe`
   - *Startup directory*: `C:\restaurant\print-worker\`
   - *Arguments*: `index.js`
3. Pestaña *I/O* → redirige *stdout* y *stderr* a un archivo, p. ej. `C:\restaurant\print-worker\worker.log` (para troubleshoot).
4. *Install service* → ya arranca solo al booteo.

Para verificarlo: reinicia la mini-PC, manda una orden desde otro dispositivo, debe imprimirse. Si no, abre `worker.log` y mándame el error.

## Troubleshooting

| Síntoma | Causa probable | Fix |
|---|---|---|
| `Falta variable de entorno` | `.env` mal llenado | Verifica que las 4 vars estén y sin comillas. |
| `Impresora no conectada` | nombre no coincide o USB desconectado | Verifica el nombre en *Devices and Printers* y prueba imprimir test de Windows. |
| Ticket sale en blanco | driver mal | Reinstala el driver de Star usando *futurePRNT* y reinicia. |
| Tickets duplicados | dos workers corriendo | Solo debe correr 1. Verifica `Get-Process node` en PowerShell. |
| No imprime órdenes nuevas | Realtime caído | El catch-up cada 60 s las recoge igual. Si tampoco, mira `worker.log`. |
| `Catch-up falló: ... permission denied` | usaste anon key en vez de service_role | Cambia `SUPABASE_SERVICE_KEY` por la correcta. |

## Formato del ticket

Cada orden saca **dos tickets** (cocina + bar) que cortan entre sí. El
de COCINA sale primero. Solo se imprime el ticket de un área si esa
área tiene ítems — una orden sin bebidas no saca ticket de bar.

```
============================================
                COCINA
          Sucursal Maravillas
============================================
Tipo: DELIVERY
Fecha: 16/06/2026 19:42
Cliente: Mariano
Tel: 4491234567
Direccion:
  Calle X 123, Col. Centro
--------------------------------------------
2 x Gordita de Asada
   Bistec, Chicharrón
1 x Envío FLASH
--------------------------------------------
                ID: 8f3a1b2c
[CORTE]

============================================
                  BAR
          Sucursal Maravillas
============================================
Tipo: DELIVERY
Fecha: 16/06/2026 19:42
Cliente: Mariano
--------------------------------------------
1 x Refresco 600ml
   Coca-Cola
--------------------------------------------
                ID: 8f3a1b2c
[CORTE]
```

Estos son tickets de **producción** (para cocina/bar) — no llevan
precio ni total. Si quieres agregar precios, edita `appendTicket()`
en `index.js`.

Las categorías que cuentan como bebida son: `drink`, `alcohol`,
`bebidas`, `drinks` (mismas que usa `kitchen_view.dart`). Cualquier
otra categoría va a cocina, incluyendo el Envío FLASH (para que el
cocinero sepa que es delivery).
