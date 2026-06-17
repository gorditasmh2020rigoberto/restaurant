-- Para que el print-worker pueda imprimir SOLO los items nuevos cuando
-- el mesero agrega más comida a una orden ya enviada, marcamos cada
-- order_item individualmente como impreso.
--
-- Flujo:
--   1. El mesero crea orden + 3 items → INSERT en orders (sent_to_kitchen_at=NOW),
--      INSERT de 3 items (printed_at=NULL). Worker imprime los 3, marca cada
--      item con printed_at=NOW, marca orders.printed_at=NOW.
--   2. Mesero abre la misma mesa, agrega 1 item más → UPDATE de orders
--      (sent_to_kitchen_at=NOW, printed_at=NULL), INSERT de 1 nuevo
--      order_item (printed_at=NULL). Worker fetch items con printed_at=NULL,
--      encuentra solo el item nuevo, imprime SOLO ese, lo marca.

ALTER TABLE order_items
ADD COLUMN IF NOT EXISTS printed_at TIMESTAMPTZ NULL;

-- Índice parcial para el filtro del worker.
CREATE INDEX IF NOT EXISTS order_items_printed_at_pending_idx
  ON order_items (order_id)
  WHERE printed_at IS NULL;

-- Backfill: los items que YA EXISTEN antes de esta migración los
-- consideramos impresos (no queremos reimprimir órdenes históricas).
UPDATE order_items
SET printed_at = NOW()
WHERE printed_at IS NULL;
