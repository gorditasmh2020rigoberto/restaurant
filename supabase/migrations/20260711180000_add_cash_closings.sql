-- Cierre de caja: al final del día, la cajera cuenta el efectivo físico
-- y lo captura aquí junto con lo que el sistema esperaba (fondo inicial +
-- ventas en efectivo + entradas - salidas), para detectar faltantes o
-- sobrantes.
CREATE TABLE IF NOT EXISTS cash_closings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_name TEXT NOT NULL,
  closed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expected_cash NUMERIC NOT NULL,
  counted_cash NUMERIC NOT NULL,
  difference NUMERIC NOT NULL,
  registered_by TEXT,
  notes TEXT
);

CREATE INDEX IF NOT EXISTS cash_closings_branch_idx
  ON cash_closings (branch_name, closed_at DESC);
