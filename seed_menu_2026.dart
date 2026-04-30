import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  print('Borrando platillos no usados en órdenes históricas...');
  try {
    // Get IDs used in order_items
    final usedRows = await supabase.from('order_items').select('dish_id');
    final usedIds = (usedRows as List)
        .map((r) => r['dish_id'])
        .where((id) => id != null)
        .toSet()
        .toList();

    // Delete dishes NOT in used IDs
    if (usedIds.isEmpty) {
      await supabase.from('dishes').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    } else {
      final inList = usedIds.map((e) => '"$e"').join(',');
      await supabase.from('dishes').delete().not('id', 'in', '($inList)');
    }
    print('  ✔ Platillos antiguos eliminados');
  } catch (e) {
    print('  ⚠ Error en delete: $e');
  }

  final menuItems = <Map<String, dynamic>>[
    // HUEVOS
    {'name': 'Huevos Rancheros', 'description': '2 huevos estrellados en tortilla frita con salsa molcajeteada', 'price': 95, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Huevos Divorciados', 'description': '2 huevos estrellados en tortilla frita con salsa verde, roja o molcajeteada', 'price': 95, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Huevos Poblanos', 'description': '2 huevos estrellados en tortilla frita con mole poblano', 'price': 120, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Huevos Revueltos', 'description': '2 huevos revueltos con jamón o tocino', 'price': 110, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Huevos Naturales', 'description': '2 huevos revueltos o estrellados', 'price': 95, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Huevos a la Mexicana', 'description': '2 huevos revueltos con cebolla, jitomate y chile serrano', 'price': 95, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 10},

    // MOLLETES
    {'name': 'Molletes Naturales (Orden)', 'description': '2 piezas', 'price': 90, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Molletes Naturales (1/2)', 'description': '1 pieza', 'price': 55, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 8},
    {'name': 'Molletes con Arrachera (Orden)', 'description': '2 piezas', 'price': 140, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Molletes con Arrachera (1/2)', 'description': '1 pieza', 'price': 85, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Molletes con Guisado (Orden)', 'description': '2 piezas. El mesero elegirá el guisado', 'price': 130, 'category': 'breakfast', 'requires_guisado': true, 'max_time': 12},
    {'name': 'Molletes con Guisado (1/2)', 'description': '1 pieza. El mesero elegirá el guisado', 'price': 75, 'category': 'breakfast', 'requires_guisado': true, 'max_time': 10},
    {'name': 'Molletes de Chilaquiles (Orden)', 'description': 'Chilaquiles verdes o rojos en cama de frijol con crema, cebolla y queso. 2 piezas', 'price': 150, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Molletes de Chilaquiles (1/2)', 'description': 'Chilaquiles verdes o rojos en cama de frijol con crema, cebolla y queso. 1 pieza', 'price': 90, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 10},

    // SOPES
    {'name': 'Sopes Sencillos (Orden)', 'description': '2 piezas', 'price': 100, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Sopes Sencillos (1/2)', 'description': '1 pieza', 'price': 65, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Sopes con Arrachera (Orden)', 'description': '2 piezas', 'price': 140, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Sopes con Arrachera (1/2)', 'description': '1 pieza', 'price': 85, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Sopes con Guisado (Orden)', 'description': '2 piezas. El mesero elegirá el guisado', 'price': 130, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 15},
    {'name': 'Sopes con Guisado (1/2)', 'description': '1 pieza. El mesero elegirá el guisado', 'price': 75, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 12},

    // ENCHILADAS
    {'name': 'Enchiladas de Cebolla (Orden)', 'description': '4 piezas', 'price': 100, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Enchiladas de Cebolla (1/2)', 'description': '2 piezas', 'price': 70, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Enchiladas de Queso (Orden)', 'description': '4 piezas', 'price': 120, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Enchiladas de Queso (1/2)', 'description': '2 piezas', 'price': 80, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Enchiladas de Pollo (Orden)', 'description': '4 piezas', 'price': 130, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Enchiladas de Pollo (1/2)', 'description': '2 piezas', 'price': 90, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 12},

    // ENMOLADAS
    {'name': 'Enmoladas de Cebolla (Orden)', 'description': '4 piezas con mole', 'price': 115, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Enmoladas de Cebolla (1/2)', 'description': '2 piezas con mole', 'price': 75, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Enmoladas de Queso (Orden)', 'description': '4 piezas con mole', 'price': 135, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Enmoladas de Queso (1/2)', 'description': '2 piezas con mole', 'price': 85, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Enmoladas de Pollo (Orden)', 'description': '4 piezas con mole', 'price': 150, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Enmoladas de Pollo (1/2)', 'description': '2 piezas con mole', 'price': 95, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 12},

    // LO DULCE
    {'name': 'Molletes Dulces', 'description': 'Con mantequilla y mermelada. 2 piezas', 'price': 80, 'category': 'dessert', 'requires_guisado': false, 'max_time': 8},
    {'name': 'Hot Cakes Naturales (3 pzas.)', 'description': '3 hot cakes naturales', 'price': 90, 'category': 'dessert', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Hot Cakes Naturales (2 pzas.)', 'description': '2 hot cakes naturales', 'price': 70, 'category': 'dessert', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Hot Cakes Naturales (1 pza.)', 'description': '1 hot cake natural', 'price': 40, 'category': 'dessert', 'requires_guisado': false, 'max_time': 8},
    {'name': 'Churros', 'description': '', 'price': 12, 'category': 'dessert', 'requires_guisado': false, 'max_time': 8},

    // GORDITAS
    {'name': 'Gordita', 'description': 'Maíz, Maíz frita o Harina', 'price': 37, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 10},
    {'name': 'Gordita con Queso', 'description': 'Maíz, Maíz frita o Harina, con queso', 'price': 42, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 10},

    // QUESADILLAS Y MÁS
    {'name': 'Quesadilla de Maíz', 'description': 'De comal o frita', 'price': 80, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 10},
    {'name': 'Mamalona', 'description': 'Quesadilla frita con lechuga, crema, queso sierra, jitomate y cebolla', 'price': 100, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Taco Chico', 'description': 'Con guisado', 'price': 30, 'category': 'tacos', 'requires_guisado': true, 'max_time': 8},
    {'name': 'Taco Chico con Queso', 'description': 'Con guisado y queso', 'price': 35, 'category': 'tacos', 'requires_guisado': true, 'max_time': 8},
    {'name': 'Taco Grande', 'description': 'Tortilla a mano, con guisado', 'price': 55, 'category': 'tacos', 'requires_guisado': true, 'max_time': 10},
    {'name': 'Burrito con Guisado', 'description': '', 'price': 90, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 12},
    {'name': 'Bolillo con Guisado', 'description': '', 'price': 60, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 10},
    {'name': 'Volcán con Guisado', 'description': '', 'price': 50, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 10},
    {'name': 'Plato de Guisado', 'description': 'Con arroz y frijoles', 'price': 120, 'category': 'mainCourse', 'requires_guisado': true, 'max_time': 12},

    // ARRACHERA
    {'name': 'Gordita de Arrachera', 'description': '', 'price': 60, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Gordita de Arrachera con Queso', 'description': '', 'price': 65, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Quesadilla de Arrachera', 'description': '', 'price': 100, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Taco Chico de Arrachera', 'description': '', 'price': 45, 'category': 'tacos', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Taco Grande de Arrachera', 'description': '', 'price': 70, 'category': 'tacos', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Burrito de Arrachera', 'description': '', 'price': 100, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Bolillo de Arrachera', 'description': '', 'price': 90, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Bolillo de Arrachera con Queso', 'description': '', 'price': 100, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Volcán de Arrachera', 'description': '', 'price': 70, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},

    // CHILE RELLENO
    {'name': 'Chile Relleno con Arroz y Frijoles', 'description': 'Con tortilla o pan', 'price': 70, 'category': 'mainCourse', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Chile Relleno en Taco', 'description': 'Tortilla a mano con 1 chile completo', 'price': 65, 'category': 'tacos', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Chile Relleno en Gordita', 'description': 'Con 1 chile completo', 'price': 65, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Chile Relleno en Bolillo', 'description': '', 'price': 70, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Chile Relleno en Quesadilla', 'description': 'Doble queso', 'price': 85, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 12},

    // CHILAQUILES
    {'name': 'Chilaquiles', 'description': 'Rojos, verdes o rancheros con salsa molcajeteada', 'price': 110, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 12},
    {'name': 'Chilaquiles con Huevo', 'description': 'Con huevo estrellado o revuelto. Salsa roja, verde o ranchera', 'price': 130, 'category': 'breakfast', 'requires_guisado': false, 'max_time': 12},

    // HUARACHES
    {'name': 'Huarache Sencillo', 'description': 'Con frijoles, lechuga, queso, crema y salsa', 'price': 100, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Huarache con Arrachera', 'description': 'Con frijoles, lechuga, queso, crema y salsa', 'price': 160, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 15},
    {'name': 'Huarache con Guisado', 'description': 'Con frijoles, lechuga, queso, crema y salsa. El mesero elegirá el guisado', 'price': 140, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 15},
    {'name': 'Huarache con Chorizo', 'description': 'Con frijoles, lechuga, queso, crema y salsa', 'price': 140, 'category': 'especialidades', 'requires_guisado': false, 'max_time': 15},

    // TAPAS DE GUISADO
    {'name': 'Tapas de Guisado', 'description': '5 rebanadas de pan con guisado de tu preferencia', 'price': 100, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 10},
    {'name': 'Tapas de Guisado con Queso', 'description': '5 rebanadas de pan con guisado y queso', 'price': 125, 'category': 'especialidades', 'requires_guisado': true, 'max_time': 10},

    // MENUDO
    {'name': 'Menudo Chico', 'description': 'Con o sin carne. Solo sábados y domingos', 'price': 100, 'category': 'soup', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Menudo Mediano', 'description': 'Con o sin carne. Solo sábados y domingos', 'price': 110, 'category': 'soup', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Menudo Grande', 'description': 'Con o sin carne. Solo sábados y domingos', 'price': 120, 'category': 'soup', 'requires_guisado': false, 'max_time': 10},
    {'name': 'Cuajadilla Chica', 'description': 'Tortilla tortillería', 'price': 40, 'category': 'side', 'requires_guisado': false, 'max_time': 8},
    {'name': 'Cuajadilla Grande', 'description': 'Tortilla hecha a mano', 'price': 80, 'category': 'side', 'requires_guisado': false, 'max_time': 8},

    // PARA LLEVAR
    {'name': '½ Litro Guisado con Carne', 'description': 'Para llevar', 'price': 140, 'category': 'side', 'requires_guisado': false, 'max_time': 10},
    {'name': '½ Litro Guisado sin Carne', 'description': 'Para llevar', 'price': 100, 'category': 'side', 'requires_guisado': false, 'max_time': 10},
    {'name': '½ Litro Arroz o Frijoles', 'description': 'Para llevar', 'price': 60, 'category': 'side', 'requires_guisado': false, 'max_time': 5},
    {'name': '¼ Litro Salsa', 'description': 'Para llevar', 'price': 40, 'category': 'side', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Chile Relleno con Salsa (Para llevar)', 'description': 'Para llevar', 'price': 60, 'category': 'side', 'requires_guisado': false, 'max_time': 10},

    // ÓRDENES EXTRAS
    {'name': 'Tocino o Jamón (3 pzas.)', 'description': 'Orden extra', 'price': 30, 'category': 'side', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Guisado Extra', 'description': 'Orden extra', 'price': 40, 'category': 'side', 'requires_guisado': true, 'max_time': 5},
    {'name': 'Arrachera Extra', 'description': 'Orden extra', 'price': 40, 'category': 'side', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Huevo Estrellado o Revuelto', 'description': 'Orden extra', 'price': 20, 'category': 'side', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Pieza de Bolillo', 'description': '', 'price': 16, 'category': 'side', 'requires_guisado': false, 'max_time': 3},

    // BEBIDAS
    {'name': 'Café de Olla con Refill', 'description': '', 'price': 45, 'category': 'drink', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Café Instantáneo', 'description': '', 'price': 45, 'category': 'drink', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Jugo Verde (330 ml)', 'description': 'Natural', 'price': 45, 'category': 'drink', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Jugo Verde (1 litro)', 'description': 'Natural', 'price': 120, 'category': 'drink', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Jugo de Naranja Natural (330 ml)', 'description': '', 'price': 45, 'category': 'drink', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Jugo de Naranja Natural (1 litro)', 'description': '', 'price': 120, 'category': 'drink', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Jugo de Zanahoria Natural (330 ml)', 'description': '', 'price': 40, 'category': 'drink', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Jugo de Zanahoria Natural (1 litro)', 'description': '', 'price': 100, 'category': 'drink', 'requires_guisado': false, 'max_time': 5},
    {'name': 'Agua Fresca (600 ml)', 'description': '', 'price': 40, 'category': 'drink', 'requires_guisado': false, 'max_time': 3},
    {'name': 'Agua Fresca (1 litro)', 'description': '', 'price': 70, 'category': 'drink', 'requires_guisado': false, 'max_time': 3},
    {'name': 'Agua Natural (500 ml)', 'description': '', 'price': 15, 'category': 'drink', 'requires_guisado': false, 'max_time': 3},
    {'name': 'Refresco (355 ml vidrio)', 'description': '', 'price': 35, 'category': 'drink', 'requires_guisado': false, 'max_time': 3},
    {'name': 'Refresco (600 ml no retornable)', 'description': '', 'price': 40, 'category': 'drink', 'requires_guisado': false, 'max_time': 3},
    {'name': 'Vaso de Leche (330 ml)', 'description': '', 'price': 40, 'category': 'drink', 'requires_guisado': false, 'max_time': 3},
    {'name': 'Choco (600 ml)', 'description': '', 'price': 45, 'category': 'drink', 'requires_guisado': false, 'max_time': 3},
    {'name': 'Té', 'description': '', 'price': 45, 'category': 'drink', 'requires_guisado': false, 'max_time': 3},
  ];

  print('Insertando ${menuItems.length} platillos...');
  int ok = 0, err = 0;
  for (final item in menuItems) {
    try {
      await supabase.from('dishes').insert(item);
      ok++;
    } catch (e) {
      err++;
      print('  ✗ Error en "${item['name']}": $e');
    }
  }

  print('\n✔ Insertados: $ok');
  if (err > 0) print('✗ Errores: $err');
  exit(0);
}
