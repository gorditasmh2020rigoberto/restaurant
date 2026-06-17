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

// ── Config ──────────────────────────────────────────────────────────
const {
  SUPABASE_URL,
  SUPABASE_SERVICE_KEY,
  PRINTER_NAME,
  BRANCH_NAME,
} = process.env;

for (const [k, v] of Object.entries({
  SUPABASE_URL,
  SUPABASE_SERVICE_KEY,
  PRINTER_NAME,
  BRANCH_NAME,
})) {
  if (!v) {
    console.error(`✘ Falta variable de entorno: ${k}. Revisa el archivo .env`);
    process.exit(1);
  }
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false },
});

function buildPrinter() {
  // En Windows, `interface: 'printer:NOMBRE'` manda los bytes al spooler
  // del sistema operativo, que a su vez los pasa a la impresora USB.
  return new ThermalPrinter({
    type: PrinterTypes.STAR,
    interface: `printer:${PRINTER_NAME}`,
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
async function fetchOrder(orderId) {
  const { data, error } = await supabase
    .from('orders')
    .select(`
      id, branch_name, order_type, customer_name, total_amount,
      table_id, created_at, payment_method,
      order_items (
        quantity, price_at_time, guisados_selected, client_label,
        dishes ( name, category )
      )
    `)
    .eq('id', orderId)
    .maybeSingle();
  if (error) throw error;
  return data;
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

async function printOrder(order) {
  const printer = buildPrinter();
  // Sanity check: solo si la impresora está conectada lanzamos.
  const connected = await printer.isPrinterConnected();
  if (!connected) {
    throw new Error(`Impresora "${PRINTER_NAME}" no responde. Verifica USB/driver.`);
  }

  const items = order.order_items || [];
  const drinks = items.filter(isDrink);
  const kitchen = items.filter((it) => !isDrink(it));

  if (!drinks.length && !kitchen.length) {
    console.warn(`⚠ Orden ${order.id} sin ítems — nada que imprimir`);
    return;
  }

  // Orden de impresión: COCINA primero (la comida tarda más), BAR
  // después. Salen como dos tickets independientes con su propio cut.
  if (kitchen.length) appendTicket(printer, 'COCINA', order, kitchen);
  if (drinks.length) appendTicket(printer, 'BAR', order, drinks);

  await printer.execute();
}

async function markPrinted(orderId) {
  const { error } = await supabase
    .from('orders')
    .update({ printed_at: new Date().toISOString() })
    .eq('id', orderId)
    .is('printed_at', null);
  if (error) throw error;
}

async function processOrder(orderId, source = 'unknown') {
  try {
    const order = await fetchOrder(orderId);
    if (!order) {
      console.warn(`⚠ Orden ${orderId} no encontrada (${source})`);
      return;
    }
    if (order.branch_name !== BRANCH_NAME) {
      // No es de esta sucursal — ignorar (el filtro en realtime debería
      // evitar esto, pero defendemos por si acaso).
      return;
    }
    console.log(`→ Imprimiendo ${orderId} (${source})...`);
    await printOrder(order);
    await markPrinted(orderId);
    console.log(`✓ ${orderId} impresa y marcada`);
  } catch (e) {
    console.error(`✘ Falló orden ${orderId}: ${e.message}`);
    // No marcamos printed_at → la orden vuelve a entrar al siguiente
    // catch-up (cada 60s) o cuando llegue otro INSERT que dispare poll.
  }
}

// ── Catch-up al arrancar y cada 60s (red de seguridad por si Realtime
//    se cae y no nos enteramos) ──────────────────────────────────────
async function catchUp() {
  const { data, error } = await supabase
    .from('orders')
    .select('id')
    .eq('branch_name', BRANCH_NAME)
    .is('printed_at', null)
    .order('created_at', { ascending: true })
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

// ── Realtime subscription ───────────────────────────────────────────
function subscribeRealtime() {
  const channel = supabase
    .channel('orders-print-worker')
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'orders',
        filter: `branch_name=eq.${BRANCH_NAME}`,
      },
      (payload) => {
        const orderId = payload?.new?.id;
        if (orderId) processOrder(orderId, 'realtime');
      },
    )
    .subscribe((status) => {
      console.log(`Realtime: ${status}`);
    });
  return channel;
}

// ── Test print ──────────────────────────────────────────────────────
async function testPrint() {
  console.log(`Imprimiendo ticket de prueba en "${PRINTER_NAME}"...`);
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
  printer.println(`Impresora: ${PRINTER_NAME}`);
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
  console.log(`Print-worker iniciado | Sucursal: ${BRANCH_NAME} | Impresora: ${PRINTER_NAME}`);
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
