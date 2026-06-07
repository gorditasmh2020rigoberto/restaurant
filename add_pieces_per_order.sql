-- Cuántas piezas trae una "orden" del platillo (ej. 3 molletes por orden).
-- NULL / 0 = no se muestra. Solo se usa visualmente en el menú/diálogo.
ALTER TABLE dishes
  ADD COLUMN IF NOT EXISTS pieces_per_order SMALLINT;
