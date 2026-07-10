-- Cuando el cajero toca "Imprimir Corte del Día", se inserta una fila
-- aquí. La Pi de Caja/Recibo (PRINT_AREA=receipt) escucha esta tabla,
-- calcula el resumen de ventas del día (por método de pago) y lo
-- imprime como un ticket más, sin estar atado a ninguna orden
-- específica (a diferencia de cuenta_requested_at).
CREATE TABLE IF NOT EXISTS corte_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_name TEXT NOT NULL,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  printed_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS corte_requests_branch_idx
  ON corte_requests (branch_name);

ALTER PUBLICATION supabase_realtime ADD TABLE corte_requests;
