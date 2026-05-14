// Supabase Edge Function: clip-pago
// Procesa pagos con Clip y envía el ticket por correo.
//
// Endpoint: POST {SUPABASE_URL}/functions/v1/clip-pago
//
// Lee la configuración de la tabla `app_config`:
//   key                  value
//   ------------------   -------------------------------------------------
//   clip_secret_key      eccc0d71-f36a-4c23-8c12-5876cae1999e
//   clip_api_url         https://api.payclip.com
//   resend_api_key       re_xxxxxx
//   ticket_from_email    tickets@misdominio.mx  (debe estar verificado en Resend)
//   restaurant_name      Gorditas Mis Hermanas
//
// Acciones (campo "action" del body):
//   - "clip"   → procesa un pago tokenizado contra la API de Clip
//   - "ticket" → envía un ticket por email vía Resend

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

// Cargar config desde la tabla app_config (cacheada por ejecución)
let _configCache: Record<string, string> | null = null;
async function loadConfig(): Promise<Record<string, string>> {
  if (_configCache) return _configCache;
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const { data, error } = await supabase
    .from('app_config')
    .select('key, value');
  if (error) throw new Error(`No se pudo leer app_config: ${error.message}`);
  const cfg: Record<string, string> = {};
  for (const row of (data ?? []) as Array<{ key: string; value: string }>) {
    cfg[row.key] = row.value;
  }
  _configCache = cfg;
  return cfg;
}

async function procesarPagoClip(body: any) {
  const cfg = await loadConfig();
  const token = String(body.token ?? '').trim();
  const amount = Number(body.amount ?? 0);
  const email = String(body.email ?? '').trim();
  if (!token) return json({ ok: false, message: 'Falta token' }, 400);
  if (!amount || amount <= 0) {
    return json({ ok: false, message: 'Monto inválido' }, 400);
  }
  const clipSecret = cfg.clip_secret_key;
  if (!clipSecret) {
    return json(
      { ok: false, message: 'clip_secret_key no configurada en app_config' },
      500,
    );
  }
  const clipApiUrl = cfg.clip_api_url || 'https://api.payclip.com';
  const restaurantName = cfg.restaurant_name || 'Restaurante';

  const resp = await fetch(`${clipApiUrl}/payments`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${clipSecret}`,
    },
    body: JSON.stringify({
      amount,
      currency: 'MXN',
      source: { token_id: token },
      capture: true,
      description: `Pedido ${restaurantName}`,
      receipt_email: email || undefined,
    }),
  });

  let data: any = {};
  try {
    data = await resp.json();
  } catch (_) {
    data = { raw: await resp.text() };
  }

  if (!resp.ok) {
    return json({
      ok: false,
      status: 'rejected',
      payment_id: data.id ?? null,
      status_detail: data.error_message ?? data.detail ?? `HTTP ${resp.status}`,
      message: data.message ?? 'Pago rechazado por Clip',
    });
  }

  const clipStatus = String(data.status ?? '').toLowerCase();
  return json({
    ok: clipStatus === 'approved' || clipStatus === 'succeeded',
    status: clipStatus || 'approved',
    payment_id: data.id ?? data.payment_id ?? null,
    status_detail: data.status_detail ?? null,
  });
}

function renderTicketHtml(payload: any, restaurantName: string): string {
  const items: Array<{ nombre: string; cantidad: number; precio: number }> =
    Array.isArray(payload.items) ? payload.items : [];
  const total = Number(payload.total ?? 0);
  const paymentId = String(payload.payment_id ?? '—');
  const fecha = new Date().toLocaleString('es-MX', {
    timeZone: 'America/Mexico_City',
  });
  const rows = items
    .map((i) => {
      const subtotal = Number(i.precio ?? 0) * Number(i.cantidad ?? 0);
      return `
        <tr>
          <td style="padding:6px 4px;border-bottom:1px solid #eee">${
            escapeHtml(i.nombre)
          }</td>
          <td style="padding:6px 4px;text-align:center;border-bottom:1px solid #eee">${i.cantidad}</td>
          <td style="padding:6px 4px;text-align:right;border-bottom:1px solid #eee">$${subtotal.toFixed(2)}</td>
        </tr>`;
    })
    .join('');
  return `<!doctype html><html><body style="font-family:system-ui,sans-serif;background:#f4f4f4;padding:24px;color:#0f172a">
    <div style="max-width:560px;margin:0 auto;background:#fff;border-radius:14px;padding:24px;box-shadow:0 2px 10px rgba(0,0,0,0.05)">
      <h2 style="margin:0 0 8px 0">${escapeHtml(restaurantName)}</h2>
      <p style="margin:0 0 16px 0;color:#64748b;font-size:13px">${fecha}</p>
      <p style="margin:0 0 4px 0;font-size:13px;color:#64748b">ID de pago: <code>${paymentId}</code></p>
      <table style="width:100%;border-collapse:collapse;margin-top:16px;font-size:14px">
        <thead>
          <tr style="background:#f1f5f9">
            <th style="padding:8px 4px;text-align:left">Producto</th>
            <th style="padding:8px 4px;text-align:center">Cant.</th>
            <th style="padding:8px 4px;text-align:right">Subtotal</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
      <div style="text-align:right;margin-top:16px;font-size:18px;font-weight:bold">
        Total: $${total.toFixed(2)}
      </div>
      <p style="margin-top:24px;color:#64748b;font-size:12px">Gracias por tu compra. Conserva este ticket como comprobante.</p>
    </div>
  </body></html>`;
}

function escapeHtml(s: string): string {
  return String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

async function enviarTicket(body: any) {
  const cfg = await loadConfig();
  const to = String(body.email ?? '').trim();
  if (!to) return json({ ok: false, message: 'Falta email' }, 400);
  const resendKey = cfg.resend_api_key;
  if (!resendKey || resendKey.startsWith('pon-')) {
    return json(
      { ok: false, message: 'resend_api_key no configurada en app_config' },
      500,
    );
  }
  const fromEmail = cfg.ticket_from_email || 'tickets@example.com';
  const restaurantName = cfg.restaurant_name || 'Restaurante';

  const html = renderTicketHtml(body, restaurantName);
  const resp = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${resendKey}`,
    },
    body: JSON.stringify({
      from: `${restaurantName} <${fromEmail}>`,
      to: [to],
      subject: `Ticket de tu pedido - ${restaurantName}`,
      html,
    }),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    return json({ ok: false, message: 'Error al enviar ticket', detail }, 500);
  }
  return json({ ok: true });
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
    if (action === 'clip') return await procesarPagoClip(body);
    if (action === 'ticket') return await enviarTicket(body);
    return json({ ok: false, message: `Acción desconocida: ${action}` }, 400);
  } catch (e: any) {
    return json(
      { ok: false, message: 'Error interno', detail: String(e?.message ?? e) },
      500,
    );
  }
});
