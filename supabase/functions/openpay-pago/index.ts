// Supabase Edge Function: openpay-pago
// Procesa pagos con tarjeta vía OpenPay (Sandbox/Producción) y actualiza
// el estado de la orden en Supabase.
//
// Endpoint: POST {SUPABASE_URL}/functions/v1/openpay-pago
//
// Lee la configuración de la tabla `app_config`:
//   key                     value
//   ---------------------   ---------------------------------------------
//   openpay_merchant_id     mj0jf0tulhemboyhoabj
//   openpay_private_key     sk_...        (¡ROTAR si se filtró!)
//   openpay_api_base        https://sandbox-api.openpay.mx/v1/
//                            (o https://api.openpay.mx/v1/ en producción)
//
// Acciones (campo "action" del body):
//   - "charge" → cobra un token de tarjeta y marca la orden como pagada.
//   - "check"  → consulta status de un charge por su id.
//
// Body para "charge":
//   {
//     action: "charge",
//     order_ids: string[],           // uno o varios ids de `orders`
//     amount: number,                // total a cobrar (MXN)
//     source_id: string,             // token de OpenPay JS SDK (frontend)
//     device_session_id: string,     // anti-fraude, generado por JS SDK
//     description?: string,
//     customer?: { name?, email?, phone_number? }
//   }

// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: CORS_HEADERS });
}

// Cache de config por ejecución para evitar N queries a app_config.
let _configCache: Record<string, string> | null = null;
async function loadConfig(): Promise<Record<string, string>> {
  if (_configCache) return _configCache;
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const { data, error } = await supabase.from('app_config').select('key, value');
  if (error) throw new Error(`No se pudo leer app_config: ${error.message}`);
  const cfg: Record<string, string> = {};
  for (const row of (data ?? []) as Array<{ key: string; value: string }>) {
    cfg[row.key] = row.value;
  }
  _configCache = cfg;
  return cfg;
}

function openpayAuthHeader(privateKey: string): string {
  // OpenPay usa Basic base64(privateKey:) — nota los dos puntos al final,
  // el username es la private key y el password está vacío.
  return `Basic ${btoa(`${privateKey}:`)}`;
}

async function procesarCargo(body: any) {
  const cfg = await loadConfig();
  const merchantId = cfg.openpay_merchant_id ?? '';
  const privateKey = cfg.openpay_private_key ?? '';
  const apiBase = (cfg.openpay_api_base ||
    'https://sandbox-api.openpay.mx/v1/').replace(/\/$/, '') + '/';
  if (!merchantId || !privateKey) {
    return json(
      { ok: false, message: 'Credenciales de OpenPay no configuradas en app_config' },
      500,
    );
  }

  const orderIds: string[] = Array.isArray(body.order_ids)
    ? body.order_ids.filter((x: unknown) => typeof x === 'string' && x)
    : (typeof body.order_id === 'string' ? [body.order_id] : []);
  const amount = Number(body.amount ?? 0);
  const sourceId = String(body.source_id ?? '').trim();
  const deviceSessionId = String(body.device_session_id ?? '').trim();
  const description = String(body.description ?? 'Pedido').slice(0, 250);
  const customer = body.customer && typeof body.customer === 'object'
    ? body.customer
    : undefined;

  if (orderIds.length === 0) {
    return json({ ok: false, message: 'Falta order_ids' }, 400);
  }
  if (!amount || amount <= 0) {
    return json({ ok: false, message: 'Monto inválido' }, 400);
  }
  if (!sourceId) {
    return json({ ok: false, message: 'Falta source_id (token OpenPay)' }, 400);
  }

  // POST /v1/{merchantId}/charges — carga directa con token de tarjeta.
  const url = `${apiBase}${merchantId}/charges`;
  let resp: Response;
  try {
    resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': openpayAuthHeader(privateKey),
      },
      body: JSON.stringify({
        source_id: sourceId,
        method: 'card',
        amount,
        currency: 'MXN',
        description,
        order_id: orderIds[0].slice(0, 100),
        device_session_id: deviceSessionId || undefined,
        customer,
      }),
    });
  } catch (e: any) {
    return json({ ok: false, step: 'fetch_openpay', detail: String(e?.message ?? e) }, 500);
  }

  const text = await resp.text();
  let data: any = {};
  try { data = JSON.parse(text); } catch (_) { data = { raw: text }; }

  if (!resp.ok) {
    return json({
      ok: false,
      status: 'rejected',
      http_status: resp.status,
      message: data.description ?? data.error_message ?? `HTTP ${resp.status}`,
      detail: data,
    }, resp.status);
  }

  const status = String(data.status ?? '').toLowerCase();
  const approved = status === 'completed' || status === 'in_progress';

  // Si OpenPay aprobó, marca las órdenes como pagadas.
  if (approved) {
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
      const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
      const supabase = createClient(supabaseUrl, serviceRoleKey, {
        auth: { persistSession: false },
      });
      await supabase
        .from('orders')
        .update({
          status: 'completed',
          payment_method: 'openpay',
          openpay_charge_id: data.id ?? null,
        })
        .in('id', orderIds);
    } catch (e: any) {
      // Log pero no fallar — el cobro sí pasó en OpenPay.
      console.error('Error al actualizar orders tras cargo aprobado:', e);
    }
  }

  return json({
    ok: approved,
    status,
    charge_id: data.id ?? null,
    authorization: data.authorization ?? null,
    error_message: data.error_message ?? null,
    detail: data,
  });
}

async function consultarCargo(body: any) {
  const cfg = await loadConfig();
  const merchantId = cfg.openpay_merchant_id ?? '';
  const privateKey = cfg.openpay_private_key ?? '';
  const apiBase = (cfg.openpay_api_base ||
    'https://sandbox-api.openpay.mx/v1/').replace(/\/$/, '') + '/';
  const chargeId = String(body.charge_id ?? '').trim();
  if (!merchantId || !privateKey) {
    return json({ ok: false, message: 'Credenciales OpenPay no configuradas' }, 500);
  }
  if (!chargeId) return json({ ok: false, message: 'Falta charge_id' }, 400);

  const url = `${apiBase}${merchantId}/charges/${encodeURIComponent(chargeId)}`;
  let resp: Response;
  try {
    resp = await fetch(url, {
      method: 'GET',
      headers: { 'Authorization': openpayAuthHeader(privateKey) },
    });
  } catch (e: any) {
    return json({ ok: false, detail: String(e?.message ?? e) }, 500);
  }
  const text = await resp.text();
  let data: any = {};
  try { data = JSON.parse(text); } catch (_) { data = { raw: text }; }
  if (!resp.ok) {
    return json({ ok: false, http_status: resp.status, detail: data }, resp.status);
  }
  return json({
    ok: true,
    status: String(data.status ?? ''),
    charge_id: data.id,
    detail: data,
  });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return json({ ok: false, message: 'Método no permitido' }, 405);
  }
  let body: any;
  try {
    body = await req.json();
  } catch (_) {
    return json({ ok: false, message: 'JSON inválido' }, 400);
  }
  const action = String(body.action ?? '').toLowerCase();
  try {
    if (action === 'charge') return await procesarCargo(body);
    if (action === 'check') return await consultarCargo(body);
    return json({ ok: false, message: `Acción desconocida: ${action}` }, 400);
  } catch (e: any) {
    return json(
      { ok: false, message: 'Error interno', detail: String(e?.message ?? e) },
      500,
    );
  }
});
