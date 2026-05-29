-- Actualiza los datos visibles en la BD: "Para llevar" → "To Go".
-- No modifica la clave interna de categoría (sigue siendo `para_llevar`).

UPDATE dishes
SET description = 'To Go'
WHERE description = 'Para llevar';

UPDATE dishes
SET name = REPLACE(name, '(Para llevar)', '(To Go)')
WHERE name LIKE '%(Para llevar)%';
