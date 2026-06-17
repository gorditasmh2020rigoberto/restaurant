-- Marca cuándo se imprimió el ticket en la impresora térmica de cocina.
-- El print-worker (Node.js en la mini-PC) hace UPDATE de este campo
-- después de imprimir, y filtra por `printed_at IS NULL` para no
-- duplicar tickets.
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS printed_at TIMESTAMPTZ NULL;

-- Índice parcial: el worker query es "todas las órdenes sin imprimir
-- ordenadas por created_at". Filtra rápido sin escanear el histórico.
CREATE INDEX IF NOT EXISTS orders_printed_at_pending_idx
  ON orders (created_at)
  WHERE printed_at IS NULL;

-- Permitir UPDATE del campo desde el worker (autenticado con service key).
CREATE POLICY "Allow update for orders.printed_at"
  ON orders FOR UPDATE USING (true) WITH CHECK (true);
