-- Agrega columna meat_type a la tabla guisados con 4 valores posibles:
--   'res'        🐄
--   'cerdo'      🐷
--   'pollo'      🐔
--   'sin_carne'  🌽
ALTER TABLE guisados
  ADD COLUMN IF NOT EXISTS meat_type TEXT
  CHECK (meat_type IN ('res', 'cerdo', 'pollo', 'sin_carne'));
