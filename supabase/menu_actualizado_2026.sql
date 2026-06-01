-- ============================================================
-- MENÚ ACTUALIZADO - Gorditas Mis Hermanas (2026)
-- Basado en menú físico fotografiado
-- Ejecutar en: Supabase > SQL Editor (proyecto jcaqolmacqhhgtjdgvaz)
-- ============================================================

-- 1. Borrar platillos que NO estén en órdenes históricas
DELETE FROM dishes
WHERE id NOT IN (
  SELECT DISTINCT dish_id FROM order_items WHERE dish_id IS NOT NULL
);

-- 2. INSERTAR MENÚ COMPLETO
INSERT INTO dishes (name, description, price, cost, category, requires_guisado, max_time) VALUES

-- ─── HUEVOS (Con frijoles, queso y bolillo rebanado o tortillas) ───
('Huevos Rancheros', '2 huevos estrellados en tortilla frita con salsa molcajeteada', 95, 0, 'breakfast', false, 12),
('Huevos Divorciados', '2 huevos estrellados en tortilla frita con salsa verde, roja o molcajeteada', 95, 0, 'breakfast', false, 12),
('Huevos Poblanos', '2 huevos estrellados en tortilla frita con mole poblano', 120, 0, 'breakfast', false, 12),
('Huevos Revueltos', '2 huevos revueltos con jamón o tocino', 110, 0, 'breakfast', false, 10),
('Huevos Naturales', '2 huevos revueltos o estrellados', 95, 0, 'breakfast', false, 10),
('Huevos a la Mexicana', '2 huevos revueltos con cebolla, jitomate y chile serrano', 95, 0, 'breakfast', false, 10),

-- ─── MOLLETES (2 piezas = Orden) ───
('Molletes Naturales (Orden)', '2 piezas', 90, 0, 'breakfast', false, 10),
('Molletes Naturales (1/2)', '1 pieza', 55, 0, 'breakfast', false, 8),
('Molletes con Arrachera (Orden)', '2 piezas', 140, 0, 'breakfast', false, 12),
('Molletes con Arrachera (1/2)', '1 pieza', 85, 0, 'breakfast', false, 10),
('Molletes con Guisado (Orden)', '2 piezas. El mesero elegirá el guisado', 130, 0, 'breakfast', true, 12),
('Molletes con Guisado (1/2)', '1 pieza. El mesero elegirá el guisado', 75, 0, 'breakfast', true, 10),
('Molletes de Chilaquiles (Orden)', 'Chilaquiles verdes o rojos en cama de frijol con crema, cebolla y queso. 2 piezas', 150, 0, 'breakfast', false, 12),
('Molletes de Chilaquiles (1/2)', 'Chilaquiles verdes o rojos en cama de frijol con crema, cebolla y queso. 1 pieza', 90, 0, 'breakfast', false, 10),

-- ─── SOPES (2 piezas = Orden) ───
('Sopes Sencillos (Orden)', '2 piezas', 100, 0, 'especialidades', false, 12),
('Sopes Sencillos (1/2)', '1 pieza', 65, 0, 'especialidades', false, 10),
('Sopes con Arrachera (Orden)', '2 piezas', 140, 0, 'especialidades', false, 15),
('Sopes con Arrachera (1/2)', '1 pieza', 85, 0, 'especialidades', false, 12),
('Sopes con Guisado (Orden)', '2 piezas. El mesero elegirá el guisado', 130, 0, 'especialidades', true, 15),
('Sopes con Guisado (1/2)', '1 pieza. El mesero elegirá el guisado', 75, 0, 'especialidades', true, 12),

-- ─── ENCHILADAS (4 piezas = Orden) ───
('Enchiladas de Cebolla (Orden)', '4 piezas', 100, 0, 'mainCourse', false, 15),
('Enchiladas de Cebolla (1/2)', '2 piezas', 70, 0, 'mainCourse', false, 12),
('Enchiladas de Queso (Orden)', '4 piezas', 120, 0, 'mainCourse', false, 15),
('Enchiladas de Queso (1/2)', '2 piezas', 80, 0, 'mainCourse', false, 12),
('Enchiladas de Pollo (Orden)', '4 piezas', 130, 0, 'mainCourse', false, 15),
('Enchiladas de Pollo (1/2)', '2 piezas', 90, 0, 'mainCourse', false, 12),

-- ─── ENMOLADAS (4 piezas = Orden) ───
('Enmoladas de Cebolla (Orden)', '4 piezas con mole', 115, 0, 'mainCourse', false, 15),
('Enmoladas de Cebolla (1/2)', '2 piezas con mole', 75, 0, 'mainCourse', false, 12),
('Enmoladas de Queso (Orden)', '4 piezas con mole', 135, 0, 'mainCourse', false, 15),
('Enmoladas de Queso (1/2)', '2 piezas con mole', 85, 0, 'mainCourse', false, 12),
('Enmoladas de Pollo (Orden)', '4 piezas con mole', 150, 0, 'mainCourse', false, 15),
('Enmoladas de Pollo (1/2)', '2 piezas con mole', 95, 0, 'mainCourse', false, 12),

-- ─── LO DULCE / POSTRES ───
('Molletes Dulces', 'Con mantequilla y mermelada. 2 piezas', 80, 0, 'dessert', false, 8),
('Hot Cakes Naturales (3 pzas.)', '3 hot cakes naturales', 90, 0, 'dessert', false, 10),
('Hot Cakes Naturales (2 pzas.)', '2 hot cakes naturales', 70, 0, 'dessert', false, 10),
('Hot Cakes Naturales (1 pza.)', '1 hot cake natural', 40, 0, 'dessert', false, 8),
('Churros', '', 12, 0, 'dessert', false, 8),

-- ─── GORDITAS ───
('Gordita', 'Maíz, Maíz frita o Harina', 37, 0, 'especialidades', true, 10),
('Gordita con Queso', 'Maíz, Maíz frita o Harina, con queso', 42, 0, 'especialidades', true, 10),

-- ─── QUESADILLAS Y MÁS (con guisado) ───
('Quesadilla de Maíz', 'De comal o frita', 80, 0, 'especialidades', true, 10),
('Mamalona', 'Quesadilla frita con lechuga, crema, queso sierra, jitomate y cebolla', 100, 0, 'especialidades', false, 12),
('Taco Chico', 'Con guisado', 30, 0, 'tacos', true, 8),
('Taco Chico con Queso', 'Con guisado y queso', 35, 0, 'tacos', true, 8),
('Taco Grande', 'Tortilla a mano, con guisado', 55, 0, 'tacos', true, 10),
('Burrito con Guisado', '', 90, 0, 'especialidades', true, 12),
('Bolillo con Guisado', '', 60, 0, 'especialidades', true, 10),
('Volcán con Guisado', '', 50, 0, 'especialidades', true, 10),
('Plato de Guisado', 'Con arroz y frijoles', 120, 0, 'mainCourse', true, 12),

-- ─── ARRACHERA ───
('Gordita de Arrachera', '', 60, 0, 'especialidades', false, 12),
('Gordita de Arrachera con Queso', '', 65, 0, 'especialidades', false, 12),
('Quesadilla de Arrachera', '', 100, 0, 'especialidades', false, 12),
('Taco Chico de Arrachera', '', 45, 0, 'tacos', false, 10),
('Taco Grande de Arrachera', '', 70, 0, 'tacos', false, 12),
('Burrito de Arrachera', '', 100, 0, 'especialidades', false, 12),
('Bolillo de Arrachera', '', 90, 0, 'especialidades', false, 12),
('Bolillo de Arrachera con Queso', '', 100, 0, 'especialidades', false, 12),
('Volcán de Arrachera', '', 70, 0, 'especialidades', false, 12),

-- ─── CHILE RELLENO ───
('Chile Relleno con Arroz y Frijoles', 'Con tortilla o pan', 70, 0, 'mainCourse', false, 15),
('Chile Relleno en Taco', 'Tortilla a mano con 1 chile completo', 65, 0, 'tacos', false, 12),
('Chile Relleno en Gordita', 'Con 1 chile completo', 65, 0, 'especialidades', false, 12),
('Chile Relleno en Bolillo', '', 70, 0, 'especialidades', false, 12),
('Chile Relleno en Quesadilla', 'Doble queso', 85, 0, 'especialidades', false, 12),

-- ─── CHILAQUILES (con frijoles, queso, cebolla, crema y bolillo) ───
('Chilaquiles', 'Rojos, verdes o rancheros con salsa molcajeteada', 110, 0, 'breakfast', false, 12),
('Chilaquiles con Huevo', 'Con huevo estrellado o revuelto. Salsa roja, verde o ranchera', 130, 0, 'breakfast', false, 12),

-- ─── HUARACHES (con frijoles, lechuga, queso, crema y salsa) ───
('Huarache Sencillo', 'Con frijoles, lechuga, queso, crema y salsa', 100, 0, 'especialidades', false, 15),
('Huarache con Arrachera', 'Con frijoles, lechuga, queso, crema y salsa', 160, 0, 'especialidades', false, 15),
('Huarache con Guisado', 'Con frijoles, lechuga, queso, crema y salsa. El mesero elegirá el guisado', 140, 0, 'especialidades', true, 15),
('Huarache con Chorizo', 'Con frijoles, lechuga, queso, crema y salsa', 140, 0, 'especialidades', false, 15),

-- ─── TAPAS DE GUISADO ───
('Tapas de Guisado', '5 rebanadas de pan con guisado de tu preferencia', 100, 0, 'especialidades', true, 10),
('Tapas de Guisado con Queso', '5 rebanadas de pan con guisado y queso', 125, 0, 'especialidades', true, 10),

-- ─── MENUDO (Sábados y Domingos) ───
('Menudo Chico', 'Con o sin carne. Solo sábados y domingos', 100, 0, 'soup', false, 10),
('Menudo Mediano', 'Con o sin carne. Solo sábados y domingos', 110, 0, 'soup', false, 10),
('Menudo Grande', 'Con o sin carne. Solo sábados y domingos', 120, 0, 'soup', false, 10),
('Cuajadilla Chica', 'Tortilla tortillería', 40, 0, 'side', false, 8),
('Cuajadilla Grande', 'Tortilla hecha a mano', 80, 0, 'side', false, 8),

-- ─── TO GO ───
('½ Litro Guisado con Carne', 'To Go', 140, 0, 'side', false, 10),
('½ Litro Guisado sin Carne', 'To Go', 100, 0, 'side', false, 10),
('¼ Litro Salsa', 'To Go', 40, 0, 'side', false, 5),
('Chile Relleno con Salsa (To Go)', 'To Go', 60, 0, 'side', false, 10),

-- ─── ÓRDENES EXTRAS ───
('Tocino o Jamón (3 pzas.)', 'Orden extra', 30, 0, 'side', false, 5),
('Guisado Extra', 'Orden extra', 40, 0, 'side', true, 5),
('Arrachera Extra', 'Orden extra', 40, 0, 'side', false, 5),
('Huevo Estrellado o Revuelto', 'Orden extra', 20, 0, 'side', false, 5),
('Pieza de Bolillo', '', 16, 0, 'side', false, 3),

-- ─── BEBIDAS ───
('Café de Olla con Refill', '', 45, 0, 'drink', false, 5),
('Café Instantáneo', '', 45, 0, 'drink', false, 5),
('Jugo Verde (330 ml)', 'Natural', 45, 0, 'drink', false, 5),
('Jugo Verde (1 litro)', 'Natural', 120, 0, 'drink', false, 5),
('Jugo de Naranja Natural (330 ml)', '', 45, 0, 'drink', false, 5),
('Jugo de Naranja Natural (1 litro)', '', 120, 0, 'drink', false, 5),
('Jugo de Zanahoria Natural (330 ml)', '', 40, 0, 'drink', false, 5),
('Jugo de Zanahoria Natural (1 litro)', '', 100, 0, 'drink', false, 5),
('Agua Fresca (600 ml)', '', 40, 0, 'drink', false, 3),
('Agua Fresca (1 litro)', '', 70, 0, 'drink', false, 3),
('Agua Natural (500 ml)', '', 15, 0, 'drink', false, 3),
('Refresco (355 ml vidrio)', '', 35, 0, 'drink', false, 3),
('Refresco (600 ml no retornable)', '', 40, 0, 'drink', false, 3),
('Vaso de Leche (330 ml)', '', 40, 0, 'drink', false, 3),
('Choco (600 ml)', '', 45, 0, 'drink', false, 3),
('Té', '', 45, 0, 'drink', false, 3);
