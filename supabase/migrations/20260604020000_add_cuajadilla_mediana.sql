-- Agrega la "Cuajadilla Mediana" como tamaño intermedio entre la Chica y
-- la Grande dentro de la categoría Menudo. La sección CUAJADILLA del
-- diálogo de Menudo la mostrará junto a las otras dos.

INSERT INTO dishes (name, description, price, cost, category, requires_guisado, max_time)
SELECT 'Cuajadilla Mediana (tortilla a mano)', 'Tortilla a mano', 50, 0, 'menudo', false, 15
WHERE NOT EXISTS (
  SELECT 1 FROM dishes
  WHERE LOWER(TRIM(name)) LIKE 'cuajadilla mediana%'
);
