import 'dart:io';
import 'package:supabase/supabase.dart';

/// Actualiza precios de dishes existentes (match por nombre case-insensitive).
/// NO agrega ni borra dishes — solo actualiza el precio de los que ya están.
///
/// Para cada (patrón, precio nuevo):
///   1. Busca dish cuyo name == patrón (case-insensitive).
///   2. Si lo encuentra y el precio es distinto, lo actualiza.
///   3. Si no, lo reporta como "no match".
///
/// Correr:  dart run update_dish_prices.dart
void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  // [nombre exacto en DB] → precio nuevo
  const updates = <String, double>{
    // Gorditas
    'Gordita de Maíz': 37,
    'Gordita de Maíz Frita': 37,
    'Gordita de Harina': 37,

    // Arrachera
    'Gordita de Arrachera': 60,
    'Quesadilla de Arrachera': 100,
    'Taco Chico de Arrachera': 45,
    'Taco Grande de Arrachera': 70,
    'Burrito de Arrachera': 100,
    'Bolillo de Arrachera': 90,
    'Bolillo de Arrachera con Queso': 100,
    'Volcán de Arrachera': 70,

    // Chile Relleno
    'Chile Relleno con Arroz y Frijoles': 70,
    'Chile Relleno en Taco': 65,
    'Chile Relleno en Gordita': 65,
    'Chile Relleno en Bolillo': 70,
    'Chile Relleno en Quesadilla': 85,

    // Chilaquiles
    'Chilaquiles': 110,

    // Huaraches
    'Huarache Sencillo': 100,
    'Huarache con Arrachera': 160,
    'Huarache con Guisado': 140,
    'Huarache con Chorizo': 140,

    // Quesadillas y más
    'Quesadilla de Maíz': 80,
    'Mamalona': 100,
    'Taco Chico': 30,
    'Taco Grande': 55,
    'Burrito con Guisado': 90,
    'Bolillo con Guisado': 60,
    'Volcán con Guisado': 50,
    'Plato de Guisado': 120,

    // Huevos
    'Huevos Rancheros': 95,
    'Huevos Divorciados': 95,
    'Huevos Poblanos': 120,
    'Huevos Revueltos': 110,
    'Huevos Naturales': 95,
    'Huevos a la Mexicana': 95,

    // Sopes
    'Sopes Sencillos (Orden)': 100,
    'Sopes Sencillos (1/2)': 65,
    'Sopes con Arrachera (Orden)': 140,
    'Sopes con Arrachera (1/2)': 85,
    'Sopes con Guisado (Orden)': 130,
    'Sopes con Guisado (1/2)': 75,

    // Molletes
    'Molletes Naturales (Orden)': 90,
    'Molletes Naturales (1/2)': 55,
    'Molletes con Arrachera (Orden)': 140,
    'Molletes con Arrachera (1/2)': 85,
    'Molletes con Guisado (Orden)': 130,
    'Molletes con Guisado (1/2)': 75,
    'Molletes de Chilaquiles (Orden)': 150,
    'Molletes de Chilaquiles (1/2)': 90,

    // Enchiladas
    'Enchiladas de Cebolla (Orden)': 100,
    'Enchiladas de Cebolla (1/2)': 70,
    'Enchiladas de Queso (Orden)': 120,
    'Enchiladas de Queso (1/2)': 80,
    'Enchiladas de Pollo (Orden)': 130,
    'Enchiladas de Pollo (1/2)': 90,

    // Enmoladas
    'Enmoladas de Cebolla (Orden)': 115,
    'Enmoladas de Cebolla (1/2)': 75,
    'Enmoladas de Queso (Orden)': 135,
    'Enmoladas de Queso (1/2)': 85,
    'Enmoladas de Pollo (Orden)': 150,
    'Enmoladas de Pollo (1/2)': 95,

    // Lo dulce
    'Molletes Dulces': 80,
    'Hot Cakes Naturales (3 pzas.)': 90,
    'Hot Cakes Naturales (2 pzas.)': 70,
    'Hot Cakes Naturales (1 pza.)': 40,
    'Churros': 12,

    // Bebidas
    'Café de Olla': 45,
    'Café Americano': 45,
    'Agua Natural (500 ml)': 15,
    'Vaso de Leche (330 ml)': 40,
    'Choco (600 ml)': 45,
    'Té': 45,

    // Menudo
    'Menudo Chico': 100,
    'Menudo Mediano': 110,
    'Menudo Grande': 120,
    'Cuajadilla Chica (tortilla tortilleria)': 40,
    'Cuajadilla Grande (tortilla a mano)': 80,

    // Para llevar
    '½ Litro Guisado con Carne': 140,
    '½ Litro Guisado sin Carne': 100,
    '½ Litro Arroz o Frijoles': 60,
    '¼ Litro Salsa': 40,
    'Chile Relleno con Salsa (Para llevar)': 60,

    // Órdenes extras
    'Orden Extra - Tocino o jamón (3 pzas.)': 30,
    'Tocino o Jamón (3 pzas.)': 30,
    'Orden Extra - Guisado': 40,
    'Guisado Extra': 40,
    'Orden Extra - Arrachera': 40,
    'Arrachera Extra': 40,
    'Orden Extra - Huevo estrellado o revuelto': 20,
    'Huevo Estrellado o Revuelto': 20,
    'Orden Extra - Pieza de bolillo': 16,
    'Pieza de Bolillo': 16,
  };

  // Carga todos los dishes una sola vez.
  final rows = await supabase.from('dishes').select('id, name, price');
  final allDishes = (rows as List).cast<Map<String, dynamic>>();
  print('Dishes en DB: ${allDishes.length}\n');

  // Index por nombre lowercase para match rápido.
  final byNameLower = <String, List<Map<String, dynamic>>>{};
  for (final d in allDishes) {
    final n = (d['name'] as String).toLowerCase().trim();
    byNameLower.putIfAbsent(n, () => []).add(d);
  }

  int updated = 0;
  int unchanged = 0;
  int notFound = 0;
  final notFoundList = <String>[];

  for (final entry in updates.entries) {
    final name = entry.key;
    final newPrice = entry.value;
    final matches = byNameLower[name.toLowerCase().trim()] ?? const [];
    if (matches.isEmpty) {
      notFound++;
      notFoundList.add(name);
      continue;
    }
    for (final d in matches) {
      final current = (d['price'] as num).toDouble();
      if (current == newPrice) {
        print('  =  $name   ya en \$${newPrice.toStringAsFixed(0)}');
        unchanged++;
        continue;
      }
      await supabase
          .from('dishes')
          .update({'price': newPrice}).eq('id', d['id']);
      print('  ✔  $name   \$${current.toStringAsFixed(0)} → \$${newPrice.toStringAsFixed(0)}');
      updated++;
    }
  }

  print('\nResumen:');
  print('  Actualizados:  $updated');
  print('  Sin cambios:   $unchanged');
  print('  No encontrados en DB: $notFound');
  if (notFoundList.isNotEmpty) {
    print('\nNo encontrados (revisa nombres exactos):');
    for (final n in notFoundList) {
      print('   • $n');
    }
  }
  exit(0);
}
