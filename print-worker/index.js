// Print-worker: escucha la tabla `orders` de Supabase y manda cada
// orden nueva a la impresora térmica Star TSP143 (USB en Windows).
//
// Flujo:
//   1. Al arrancar, procesa todas las órdenes sin imprimir (catch-up).
//   2. Se subscribe vía Realtime a INSERT en `orders` para esta sucursal.
//   3. Por cada orden: fetch items+dishes → formato ESC-POS → imprime
//      → UPDATE orders SET printed_at = NOW().
//
// Idempotencia: el guard `printed_at IS NULL` evita duplicados aunque
// el evento se vuelva a entregar tras un reconnect de Realtime.

'use strict';

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const {
  printer: ThermalPrinter,
  types: PrinterTypes,
} = require('node-thermal-printer');

// Node <22 no tiene WebSocket nativo y @supabase/realtime-js lo exige
// (incluso si solo hacemos polling). Cargamos `ws` como polyfill.
let wsTransport;
try {
  wsTransport = require('ws');
} catch {
  // Node 22+ trae WebSocket nativo, no se necesita.
}

// ── Config ──────────────────────────────────────────────────────────
const {
  SUPABASE_URL,
  SUPABASE_SERVICE_KEY,
  PRINTER_NAME,    // Windows: nombre en el spooler ("Star TSP143")
  PRINTER_DEVICE,  // Linux/Raspberry: device file ("/dev/usb/lp0")
  PRINTER_TYPE,    // 'epson' (default) o 'star' — comando set de la impresora
  PAPER_WIDTH_CHARS, // 48 (80mm, default) o 32 (58mm)
  BRANCH_NAME,
  DRY_RUN,
} = process.env;

// DRY_RUN=true → no manda nada a la impresora; imprime el ticket
// formateado en la terminal. Útil para probar localmente (p.ej. en
// Mac sin impresora térmica) que la suscripción a Supabase, el
// formato y la división en COCINA/BAR funcionan end-to-end.
const isDryRun = String(DRY_RUN || '').toLowerCase() === 'true';

const paperWidth = Math.max(20, parseInt(PAPER_WIDTH_CHARS || '48', 10));

const requiredVars = { SUPABASE_URL, SUPABASE_SERVICE_KEY, BRANCH_NAME };
for (const [k, v] of Object.entries(requiredVars)) {
  if (!v) {
    console.error(`✘ Falta variable de entorno: ${k}. Revisa el archivo .env`);
    process.exit(1);
  }
}
if (!isDryRun && !PRINTER_NAME && !PRINTER_DEVICE) {
  console.error(
    '✘ Falta PRINTER_NAME (Windows) o PRINTER_DEVICE (Linux, p.ej. /dev/usb/lp0). Define uno en .env',
  );
  process.exit(1);
}

const printerTarget = PRINTER_DEVICE || PRINTER_NAME || '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false },
  realtime: wsTransport ? { transport: wsTransport } : undefined,
});

// Fake printer para DRY_RUN: misma API que ThermalPrinter pero acumula
// líneas en memoria y al execute() las vuelca a la terminal con cierto
// formato (mayúsculas para bold, ====== para drawLine, ✂️ para cut).
function buildDryRunPrinter() {
  const lines = [];
  let bold = false;
  let align = 'left';
  let scale = 'normal';
  const pad = (s) => {
    s = String(s);
    if (align === 'center') {
      const w = paperWidth;
      const trimmed = s.length > w ? s.slice(0, w) : s;
      const space = Math.max(0, Math.floor((w - trimmed.length) / 2));
      return ' '.repeat(space) + trimmed;
    }
    return s;
  };
  const fmt = (s) => {
    let out = pad(s);
    if (bold) out = out.toUpperCase();
    if (scale === 'double') out = `★ ${out} ★`;
    return out;
  };
  return {
    isPrinterConnected: async () => true,
    alignCenter: () => { align = 'center'; },
    alignLeft: () => { align = 'left'; },
    alignRight: () => { align = 'right'; },
    bold: (v) => { bold = !!v; },
    setTextDoubleHeight: () => { scale = 'double'; },
    setTextNormal: () => { scale = 'normal'; },
    println: (s) => lines.push(fmt(s)),
    newLine: () => lines.push(''),
    drawLine: () => lines.push('-'.repeat(paperWidth)),
    cut: () => lines.push('\n────────── ✂️  CORTE ──────────\n'),
    execute: async () => {
      console.log(
        '\n┌─── [DRY_RUN] Ticket(s) que se imprimirían ───┐',
      );
      for (const l of lines) console.log(l);
      console.log('└──────────────────────────────────────────────┘\n');
      lines.length = 0;
    },
  };
}

function buildPrinter() {
  if (isDryRun) return buildDryRunPrinter();
  // - Windows: PRINTER_NAME="Star TSP143" → 'printer:Star TSP143' (spooler)
  // - Linux/Raspberry: PRINTER_DEVICE="/dev/usb/lp0" → escribe al device USB
  //   directamente (no requiere CUPS).
  const iface = PRINTER_DEVICE ? PRINTER_DEVICE : `printer:${PRINTER_NAME}`;
  const type = String(PRINTER_TYPE || 'epson').toLowerCase() === 'star'
    ? PrinterTypes.STAR
    : PrinterTypes.EPSON;
  return new ThermalPrinter({
    type,
    interface: iface,
    width: paperWidth,
    characterSet: 'PC858_EURO',
    removeSpecialCharacters: false,
    lineCharacter: '-',
    options: { timeout: 5000 },
  });
}

// ── Utils ───────────────────────────────────────────────────────────
function fmtDateTime(ts) {
  const d = ts ? new Date(ts) : new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

// `customer_name` viene smushed: "Mariano (Pago: efectivo) - DIR: ... - TEL: ..."
// Lo partimos para imprimirlo en líneas separadas.
function parseCustomerName(raw) {
  if (!raw) return { name: '', pago: '', dir: '', tel: '' };
  const out = { name: '', pago: '', dir: '', tel: '' };
  // name = todo antes del primer paréntesis o guion
  const m = raw.match(/^([^()\-]+)/);
  out.name = (m ? m[1] : raw).trim();
  const pago = raw.match(/\(Pago:\s*([^)]+)\)/i);
  if (pago) out.pago = pago[1].trim();
  const dir = raw.match(/-\s*DIR:\s*([^-]+?)(?:\s*-\s*TEL:|$)/i);
  if (dir) out.dir = dir[1].trim();
  const tel = raw.match(/-\s*TEL:\s*([^-]+)$/i);
  if (tel) out.tel = tel[1].trim();
  return out;
}

function parseGuisados(raw) {
  if (!raw) return [];
  try {
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr.filter(Boolean) : [];
  } catch {
    return [];
  }
}

// ── Fetch + Format + Print ──────────────────────────────────────────
// Fetch SOLO los datos de la orden (no items). Items se traen aparte
// filtrados por printed_at IS NULL.
async function fetchOrder(orderId) {
  const { data, error } = await supabase
    .from('orders')
    .select(`
      id, branch_name, order_type, customer_name, total_amount,
      table_id, created_at, payment_method,
      sent_to_kitchen_at, printed_at
    `)
    .eq('id', orderId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

// Trae solo los order_items que aún no se han impreso. Esto es lo que
// permite imprimir las adiciones de una orden ya enviada sin reimprimir
// los items que ya fueron a cocina.
async function fetchUnprintedItems(orderId) {
  const { data, error } = await supabase
    .from('order_items')
    .select(`
      id, quantity, price_at_time, guisados_selected, client_label,
      dishes ( name, category )
    `)
    .eq('order_id', orderId)
    .is('printed_at', null)
    .order('id', { ascending: true });
  if (error) throw error;
  return data || [];
}

// Marca los items que acabamos de imprimir. Si después de eso ya no
// quedan items sin imprimir, marca la orden como printed_at = NOW()
// también, para que la query del catch-up (printed_at IS NULL) la
// excluya y sea barata.
async function markItemsPrinted(orderId, itemIds) {
  if (itemIds.length === 0) return;
  const nowIso = new Date().toISOString();
  const { error: e1 } = await supabase
    .from('order_items')
    .update({ printed_at: nowIso })
    .in('id', itemIds);
  if (e1) throw e1;
  // ¿Quedan items sin imprimir? Si no, marca también orders.printed_at
  // para que el catch-up (filtrado por printed_at IS NULL) sea barato.
  const { count, error: e2 } = await supabase
    .from('order_items')
    .select('id', { count: 'exact', head: true })
    .eq('order_id', orderId)
    .is('printed_at', null);
  if (e2) throw e2;
  if ((count ?? 0) === 0) {
    await supabase
      .from('orders')
      .update({ printed_at: nowIso })
      .eq('id', orderId);
  }
}

// Clasifica un order_item como bebida (BAR) o comida (COCINA) usando
// la misma regla de category que `kitchen_view.dart`. El Envío FLASH
// (categoría 'Envío') se considera comida para que el cocinero vea
// que es delivery.
const DRINK_CATEGORIES = ['drink', 'alcohol', 'bebidas', 'drinks'];
function isDrink(item) {
  const cat = (item.dishes?.category || '').toString().toLowerCase().trim();
  return DRINK_CATEGORIES.includes(cat);
}

// Añade un ticket completo (header → ítems → cut) al buffer del printer.
// `kind` es 'COCINA' o 'BAR'. No llama execute() — lo hace el caller.
function appendTicket(printer, kind, order, items) {
  const cust = parseCustomerName(order.customer_name);
  const tipo = (order.order_type || 'pedido').toUpperCase();

  // ── Encabezado
  printer.alignCenter();
  printer.setTextDoubleHeight();
  printer.bold(true);
  printer.println(kind);
  printer.bold(false);
  printer.setTextNormal();
  printer.println(`Sucursal ${order.branch_name || ''}`);
  printer.drawLine();

  // ── Tipo + fecha + cliente
  printer.alignLeft();
  printer.setTextNormal();
  printer.println(`Tipo: ${tipo}`);
  if (order.table_id) printer.println(`Mesa: ${order.table_id}`);
  printer.println(`Fecha: ${fmtDateTime(order.created_at)}`);
  if (cust.name) printer.println(`Cliente: ${cust.name}`);
  if (cust.tel) printer.println(`Tel: ${cust.tel}`);
  if (cust.dir) {
    printer.println('Direccion:');
    printer.println(`  ${cust.dir}`);
  }
  if (cust.pago) printer.println(`Pago: ${cust.pago}`);
  printer.drawLine();

  // ── Ítems (sin precios — esto es ticket de producción, no recibo)
  for (const it of items) {
    const name = it.dishes?.name || '(sin nombre)';
    const qty = it.quantity || 1;
    printer.bold(true);
    printer.println(`${qty} x ${name}`);
    printer.bold(false);
    const guisados = parseGuisados(it.guisados_selected);
    if (guisados.length) {
      printer.println(`   ${guisados.join(', ')}`);
    }
    if (it.client_label && it.client_label !== 'Cliente 1') {
      printer.println(`   (${it.client_label})`);
    }
  }
  printer.drawLine();

  // ── Pie
  printer.alignCenter();
  printer.println(`ID: ${String(order.id).slice(0, 8)}`);
  printer.newLine();
  printer.cut();
}

// Imprime los items dados (ya filtrados por unprinted). Devuelve true
// si efectivamente mandó algo, false si no había nada que imprimir.
async function printItems(order, items) {
  const printer = buildPrinter();
  const connected = await printer.isPrinterConnected();
  if (!connected) {
    throw new Error(`Impresora "${printerTarget}" no responde. Verifica USB/driver.`);
  }

  const drinks = items.filter(isDrink);
  const kitchen = items.filter((it) => !isDrink(it));

  if (!drinks.length && !kitchen.length) return false;

  // Si esta NO es la primera impresión (la orden ya tenía printed_at),
  // los tickets traen un banner "ADICIÓN" para que cocina sepa que son
  // items nuevos sobre una orden ya entregada.
  const isAddition = !!order.printed_at;

  if (kitchen.length) {
    appendTicket(printer, isAddition ? 'COCINA — ADICIÓN' : 'COCINA', order, kitchen);
  }
  if (drinks.length) {
    appendTicket(printer, isAddition ? 'BAR — ADICIÓN' : 'BAR', order, drinks);
  }

  await printer.execute();
  return true;
}

// Lock en memoria para no procesar la misma orden en paralelo (puede
// pasar si realtime entrega un evento mientras el catch-up trabaja).
const _inFlight = new Set();

async function processOrder(orderId, source = 'unknown') {
  if (_inFlight.has(orderId)) {
    return; // ya hay otro procesando esta orden
  }
  _inFlight.add(orderId);
  try {
    const order = await fetchOrder(orderId);
    if (!order) {
      console.warn(`⚠ Orden ${orderId} no encontrada (${source})`);
      return;
    }
    if (order.branch_name !== BRANCH_NAME) return; // otra sucursal
    if (!order.sent_to_kitchen_at) return;         // aún no mandada a cocina

    const items = await fetchUnprintedItems(orderId);
    if (items.length === 0) return; // todo ya impreso, nada que hacer

    const tag = order.printed_at ? 'adición' : 'primera';
    console.log(
      `→ Imprimiendo ${items.length} item(s) de ${orderId} (${source}, ${tag})...`,
    );
    const printed = await printItems(order, items);
    if (!printed) return; // por si acaso
    await markItemsPrinted(
      orderId,
      items.map((it) => it.id),
    );
    console.log(`✓ ${orderId} — ${items.length} item(s) impresos y marcados`);
  } catch (e) {
    console.error(`✘ Falló orden ${orderId}: ${e.message}`);
    // No marcamos printed_at en items → vuelven a entrar al siguiente
    // catch-up (cada 60s) o al próximo evento de realtime.
  } finally {
    _inFlight.delete(orderId);
  }
}

// ── Catch-up al arrancar y cada 60s (red de seguridad por si Realtime
//    se cae y no nos enteramos) ──────────────────────────────────────
//
// Solo imprime órdenes que ya fueron "mandadas a cocina" por el mesero
// (sent_to_kitchen_at IS NOT NULL). Las órdenes del cliente que aún
// no aprueba el mesero quedan en cola sin tocar.
async function catchUp() {
  const { data, error } = await supabase
    .from('orders')
    .select('id')
    .eq('branch_name', BRANCH_NAME)
    .not('sent_to_kitchen_at', 'is', null)
    .is('printed_at', null)
    .order('sent_to_kitchen_at', { ascending: true })
    .limit(50);
  if (error) {
    console.error('Catch-up falló:', error.message);
    return;
  }
  if (!data?.length) return;
  console.log(`Catch-up: ${data.length} orden(es) pendiente(s)`);
  for (const o of data) {
    await processOrder(o.id, 'catch-up');
  }
}

// Defensive: el realtime UPDATE dispara para CUALQUIER cambio en la
// fila (p.ej. el mesero edita total). Antes de imprimir, re-checamos
// el gate contra la BD para no imprimir si ya está impresa o si el
// sent_to_kitchen_at sigue null.
function isReadyToPrint(row) {
  return !!row?.sent_to_kitchen_at && !row?.printed_at;
}

// ── Realtime subscription ───────────────────────────────────────────
function subscribeRealtime() {
  const channel = supabase
    .channel('orders-print-worker')
    // INSERT — cuando el mesero crea orden ya con sent_to_kitchen_at
    // seteado (su "guardar" es el "mandar a cocina" de una vez).
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'orders',
        filter: `branch_name=eq.${BRANCH_NAME}`,
      },
      (payload) => {
        if (isReadyToPrint(payload?.new)) {
          processOrder(payload.new.id, 'realtime-insert');
        }
      },
    )
    // UPDATE — cuando el mesero toca "Mandar a cocina" en una orden
    // del cliente que estaba esperando aprobación.
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'orders',
        filter: `branch_name=eq.${BRANCH_NAME}`,
      },
      (payload) => {
        if (isReadyToPrint(payload?.new)) {
          processOrder(payload.new.id, 'realtime-update');
        }
      },
    )
    .subscribe((status) => {
      console.log(`Realtime: ${status}`);
    });
  return channel;
}

// ── Test print ──────────────────────────────────────────────────────
async function testPrint() {
  const target = isDryRun ? 'DRY_RUN (terminal)' : `"${printerTarget}"`;
  console.log(`Imprimiendo ticket de prueba en ${target}...`);
  const printer = buildPrinter();
  const ok = await printer.isPrinterConnected();
  if (!ok) {
    console.error('✘ Impresora no conectada. Revisa el cable USB y el nombre.');
    process.exit(2);
  }
  printer.alignCenter();
  printer.setTextDoubleHeight();
  printer.bold(true);
  printer.println('TEST');
  printer.setTextNormal();
  printer.bold(false);
  printer.println('Print-worker activo');
  printer.println(fmtDateTime());
  printer.drawLine();
  printer.println(`Sucursal: ${BRANCH_NAME}`);
  printer.println(`Modo: ${isDryRun ? 'DRY_RUN' : `Impresora ${printerTarget}`}`);
  printer.println(`Ancho: ${paperWidth} cols`);
  printer.newLine();
  printer.cut();
  await printer.execute();
  console.log('✓ Test impreso.');
  process.exit(0);
}

// ── Main ────────────────────────────────────────────────────────────
async function main() {
  if (process.argv.includes('--test')) {
    await testPrint();
    return;
  }
  console.log(
    `Print-worker iniciado | Sucursal: ${BRANCH_NAME} | ` +
      (isDryRun ? '🧪 DRY_RUN (terminal)' : `Impresora: ${printerTarget} (${paperWidth} cols)`),
  );
  await catchUp();
  subscribeRealtime();
  // Red de seguridad: re-corre catch-up cada 60 s.
  setInterval(catchUp, 60_000);
}

main().catch((e) => {
  console.error('Error fatal:', e);
  process.exit(1);
});

process.on('SIGINT', () => {
  console.log('\nDeteniendo print-worker...');
  process.exit(0);
});
