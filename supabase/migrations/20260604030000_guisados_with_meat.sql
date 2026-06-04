-- Clasificación CON CARNE / SIN CARNE para los guisados.
-- Por defecto todos son "con carne". Marcamos los vegetarianos explícitamente.

ALTER TABLE guisados
ADD COLUMN IF NOT EXISTS with_meat BOOLEAN NOT NULL DEFAULT true;

-- Asegurar que los guisados base existan (idempotente).
INSERT INTO guisados (name, with_meat, available)
SELECT v.name, v.with_meat, true
FROM (VALUES
  -- Con carne
  ('Bistec', true),
  ('Buche', true),
  ('Chicharrón prensado verde', true),
  ('Chicharrón prensado rojo', true),
  ('Chicharrón prensado morita', true),
  ('Duro', true),
  ('Costilla', true),
  ('Mole', true),
  ('Lengua', true),
  ('Picadillo', true),
  ('Tinga', true),
  ('Trocito', true),
  -- Sin carne
  ('Champiñones', false),
  ('Papas con chorizo', false),
  ('Papas a la mexicana', false),
  ('Nopales', false),
  ('Huevo en salsa', false),
  ('Rajas a la mexicana', false),
  ('Rajas con crema', false)
) AS v(name, with_meat)
WHERE NOT EXISTS (
  SELECT 1 FROM guisados g
  WHERE LOWER(TRIM(g.name)) = LOWER(TRIM(v.name))
);

-- Marcar como sin carne los existentes que coinciden con la lista vegetariana.
UPDATE guisados
SET with_meat = false
WHERE LOWER(TRIM(name)) IN (
  'champiñones', 'champiñónes', 'champinones',
  'papas con chorizo', 'papa con chorizo',
  'papas a la mexicana', 'papa a la mexicana',
  'nopales',
  'huevo en salsa', 'huevos en salsa',
  'rajas a la mexicana',
  'rajas con crema'
);

-- Para los demás, asegurar with_meat=true (idempotente).
UPDATE guisados
SET with_meat = true
WHERE with_meat IS NULL;
