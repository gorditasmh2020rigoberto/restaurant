-- El tamaño real del refresco de vidrio es 355 ml (así está en
-- drink_type_prices y en el nombre del dish "Refresco 355 ml vidrio"),
-- pero el constraint de drink_flavors.type solo aceptaba 'refresco_255'
-- (typo histórico) y rechazaba 'refresco_355'. El 255ml nunca existió
-- como producto real — se corrige aquí.
ALTER TABLE drink_flavors DROP CONSTRAINT IF EXISTS drink_flavors_type_check;

UPDATE drink_flavors SET type = 'refresco_355' WHERE type = 'refresco_255';

ALTER TABLE drink_flavors ADD CONSTRAINT drink_flavors_type_check
  CHECK (type IN (
    'refresco', 'refresco_355', 'refresco_600',
    'agua_fresca', 'agua_600', 'agua_1litro',
    'jugo', 'jugo_330', 'jugo_1litro'
  ));
