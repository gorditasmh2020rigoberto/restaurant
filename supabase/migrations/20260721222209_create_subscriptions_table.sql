-- Tabla de suscripciones por sucursal.
-- paid_until = última fecha (inclusive) en la que el servicio está pagado.
-- Cuando paid_until < hoy, la app bloquea el acceso (con 3 días de gracia).
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  branch_name TEXT UNIQUE NOT NULL,
  paid_until DATE NOT NULL,
  contact_info TEXT DEFAULT 'WhatsApp: 449 111 2564',
  notes TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Estado inicial: 90 días por delante para las sucursales actuales.
INSERT INTO subscriptions (branch_name, paid_until)
VALUES
  ('Sucursal Maravillas', (CURRENT_DATE + INTERVAL '90 days')::date),
  ('Sucursal Pocitos',    (CURRENT_DATE + INTERVAL '90 days')::date)
ON CONFLICT (branch_name) DO NOTHING;
