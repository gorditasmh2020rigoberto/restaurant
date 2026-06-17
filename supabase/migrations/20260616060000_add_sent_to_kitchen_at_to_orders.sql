-- Marca cuándo la orden se "manda a cocina" (gate explícito para que
-- el print-worker imprima). Antes el worker imprimía cualquier orden
-- nueva; ahora solo imprime las que tienen este campo seteado.
--
-- Flujo:
--   - Cliente (auto-servicio) crea orden con sent_to_kitchen_at = NULL
--     → queda en cola esperando aprobación del mesero.
--   - Mesero crea/guarda comanda → sent_to_kitchen_at = NOW() de una vez.
--   - Mesero tap "Mandar a cocina" en orden del cliente → UPDATE
--     sent_to_kitchen_at = NOW().
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS sent_to_kitchen_at TIMESTAMPTZ NULL;

-- Índice parcial para el query del worker:
-- "órdenes mandadas a cocina pero aún no impresas".
CREATE INDEX IF NOT EXISTS orders_sent_to_kitchen_pending_idx
  ON orders (sent_to_kitchen_at)
  WHERE sent_to_kitchen_at IS NOT NULL AND printed_at IS NULL;
