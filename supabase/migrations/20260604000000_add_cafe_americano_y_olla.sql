-- Agrega "Café Americano" y "Café de Olla" a la categoría de cafés.
-- Sólo inserta si no existen ya (evita duplicados al ejecutarlo varias veces).

INSERT INTO dishes (name, description, price, cost, category, requires_guisado, max_time)
SELECT 'Café Americano', '', 45, 0, 'cafes', false, 5
WHERE NOT EXISTS (
  SELECT 1 FROM dishes WHERE LOWER(TRIM(name)) = 'café americano'
);

INSERT INTO dishes (name, description, price, cost, category, requires_guisado, max_time)
SELECT 'Café de Olla', '', 45, 0, 'cafes', false, 5
WHERE NOT EXISTS (
  SELECT 1 FROM dishes WHERE LOWER(TRIM(name)) = 'café de olla'
);

-- Normalizar categoría 'drink' → 'cafes' para los cafés existentes,
-- para que aparezcan en el grupo correcto del menú.
UPDATE dishes
SET category = 'cafes'
WHERE category = 'drink'
  AND (
    LOWER(name) LIKE 'café%'
    OR LOWER(name) LIKE 'cafe%'
    OR LOWER(name) LIKE '%capuchino%'
    OR LOWER(name) LIKE '%nescafé%'
    OR LOWER(name) LIKE '%nescafe%'
  );
