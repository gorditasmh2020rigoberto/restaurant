# Edge Function: openpay-pago

Procesa pagos con tarjeta vía [OpenPay](https://www.openpay.mx/) (sandbox o producción) y actualiza el estado de la orden en Supabase.

## Setup (una sola vez)

### 1. Migrar `orders`

Agrega la columna `openpay_charge_id` para trazar el charge de OpenPay:

```sql
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS openpay_charge_id TEXT;
```

### 2. Guardar credenciales en `app_config`

```sql
INSERT INTO app_config (key, value) VALUES
  ('openpay_merchant_id', 'mj0jf0tulhemboyhoabj'),
  ('openpay_private_key', 'sk_NUEVA_LLAVE_ROTADA'),
  ('openpay_api_base',    'https://sandbox-api.openpay.mx/v1/')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
```

⚠ **La `openpay_private_key` debe ser la NUEVA rotada** — la primera se compartió en un chat, se considera comprometida.

Para producción, cambiar `openpay_api_base` a `https://api.openpay.mx/v1/` y usar la private key de producción (`sk_...` sin `test`).

### 3. Deploy

```bash
supabase functions deploy openpay-pago --no-verify-jwt
```

*(El flag `--no-verify-jwt` permite que el frontend PWA anónimo la llame; internamente valida contra `app_config` y OpenPay).*

## Flujo end-to-end

```
Frontend Flutter                 openpay-pago (Edge)              OpenPay
─────────────────                ──────────────────                ───────
1. Cliente tap "Tarjeta"
2. OpenPay JS SDK render form
3. Cliente ingresa tarjeta
4. SDK.tokenize()         ────────────────────────────────────►    (tokeniza)
5.                        ◄────────────────────────────────────    token_id
6. POST action=charge     ──►
   { order_ids, amount,
     source_id=token_id,
     device_session_id }
                                7. loadConfig() → app_config
                                8. POST /v1/{merchantId}/charges  ──►
                                                                    (procesa)
                                                                  ◄──
                                9. Si status=completed:
                                     UPDATE orders SET
                                       status='completed',
                                       payment_method='openpay',
                                       openpay_charge_id
                                10. Return { ok:true, status, charge_id }
                            ◄─── 
11. Muestra QR ticket ✓
```

## Acciones

### `charge` — cobrar una tarjeta ya tokenizada

**Request:**
```json
{
  "action": "charge",
  "order_ids": ["abc-uuid-1", "def-uuid-2"],
  "amount": 250.50,
  "source_id": "tokr9lygosygx6hjvcik",
  "device_session_id": "kR1MiQhz2otdIuUdQe7Wqbafuk...",
  "description": "Pedido Sucursal Pocitos mesa 3",
  "customer": { "name": "Mario", "phone_number": "4491234567" }
}
```

**Response (aprobado):**
```json
{
  "ok": true,
  "status": "completed",
  "charge_id": "tr123abc",
  "authorization": "801585",
  "detail": { ... }
}
```

**Response (rechazado):**
```json
{
  "ok": false,
  "status": "rejected",
  "http_status": 402,
  "message": "Tarjeta declinada por el emisor",
  "detail": { ... }
}
```

### `check` — consulta status de un charge

**Request:**
```json
{ "action": "check", "charge_id": "tr123abc" }
```

**Response:**
```json
{ "ok": true, "status": "completed", "charge_id": "tr123abc", "detail": { ... } }
```

## Prueba rápida en sandbox

Tarjetas de prueba OpenPay:
- **Aprobada:** `4111111111111111` — cualquier CVV / fecha futura.
- **Rechazada:** `4000000000000002`.

Amount mínimo: cualquier valor > 0 (no cobra dinero real en sandbox).

## Troubleshooting

| Error | Causa | Fix |
|---|---|---|
| `Credenciales de OpenPay no configuradas` | Falta `openpay_merchant_id` o `openpay_private_key` en `app_config` | Corre el `INSERT` del paso 2. |
| `401 Unauthorized` de OpenPay | Private key mal | Rota la key en el dashboard, actualiza `app_config`. |
| `Falta source_id` | El frontend no está enviando el token | Verifica que el JS SDK tokenizó bien y estás mandando `source_id`. |
| Cargo aprobado pero orden no actualizada | Error en el UPDATE de orders | Revisa logs de la function y que `openpay_charge_id` exista como columna. |
