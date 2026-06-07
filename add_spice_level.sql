-- Agrega columna spice_level (0..3) a la tabla guisados.
-- 0 = no pica, 3 = muy picoso. Default 0.
ALTER TABLE guisados
  ADD COLUMN IF NOT EXISTS spice_level SMALLINT NOT NULL DEFAULT 0
  CHECK (spice_level BETWEEN 0 AND 3);
