-- Oculta "Café de Olla con Refill" del menú.
-- Si el platillo no tiene historial en order_items se elimina; si lo tiene,
-- sólo se marca is_sale = false para preservar la integridad histórica.

UPDATE dishes
SET is_sale = false
WHERE LOWER(TRIM(name)) = 'café de olla con refill';

DELETE FROM dishes
WHERE LOWER(TRIM(name)) = 'café de olla con refill'
  AND id NOT IN (SELECT DISTINCT dish_id FROM order_items WHERE dish_id IS NOT NULL);
