# Edge Function `clip-pago`

Procesa pagos con Clip y envía tickets por correo desde el Supabase del restaurante.

## Variables de entorno (obligatorias)

Configúralas en el panel de Supabase → Settings → Edge Functions → Secrets:

| Variable | Valor de ejemplo | Para qué |
|---|---|---|
| `CLIP_SECRET_KEY` | `eccc0d71-f36a-4c23-8c12-5876cae1999e` | Autenticar contra la API de Clip |
| `CLIP_API_URL` | `https://api.payclip.com` | Base URL de Clip (sandbox o prod) |
| `RESEND_API_KEY` | `re_xxxxxxxx` | Token de Resend para enviar email |
| `TICKET_FROM_EMAIL` | `tickets@misdominio.mx` | Remitente del correo (debe estar verificado en Resend) |
| `RESTAURANT_NAME` | `Gorditas Mis Hermanas` | Nombre que aparece en el ticket |

## Despliegue

```bash
# Desde la raíz del repo
supabase login                                  # solo la primera vez
supabase link --project-ref jcaqolmacqhhgtjdgvaz
supabase functions deploy clip-pago --no-verify-jwt
```

## Probar

```bash
# Procesar un pago (necesitas un token_id de Clip)
curl -X POST \
  "https://jcaqolmacqhhgtjdgvaz.supabase.co/functions/v1/clip-pago" \
  -H "Content-Type: application/json" \
  -d '{"action":"clip","token":"tok_xxx","amount":40,"email":"test@gmail.com"}'

# Enviar un ticket
curl -X POST \
  "https://jcaqolmacqhhgtjdgvaz.supabase.co/functions/v1/clip-pago" \
  -H "Content-Type: application/json" \
  -d '{"action":"ticket","email":"test@gmail.com","payment_id":"pi_123","total":40,"items":[{"nombre":"Refresco","cantidad":1,"precio":40}]}'
```

## Cambiar la URL en el cliente

Una vez desplegada, actualiza `lib/services/clip_service.dart`:

```dart
static const _pvSupabaseUrl = 'https://jcaqolmacqhhgtjdgvaz.supabase.co';
static const _pvAnonKey = 'TU_ANON_KEY_AQUI'; // del proyecto del restaurante
static const _fnUrl = '$_pvSupabaseUrl/functions/v1/clip-pago';
```

(Y renombra las constantes para que no se llamen `_pvSupabaseUrl` ya que apuntan al restaurante.)
