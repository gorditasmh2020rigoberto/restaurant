import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  // Mapa de patrón en nombre -> nueva categoría
  // Se evalúa en orden; el primer match gana
  final rules = <Map<String, String>>[
    // Bebidas (primero, por palabras como "Café", "Jugo", "Agua", etc.)
    {'pattern': r'^(Café|Jugo|Agua|Refresco|Vaso de Leche|Choco|Té)', 'category': 'bebidas'},

    // To Go
    {'pattern': r'(Para llevar|½ Litro|¼ Litro|1/2 [Ll]itro|1/4 [Ll]itro)', 'category': 'para_llevar'},

    // Extras
    {'pattern': r'(Tocino o Jamón|Guisado Extra|Arrachera Extra|Huevo Estrellado o Revuelto|Pieza de Bolillo|Orden Extra)', 'category': 'extras'},

    // Menudo
    {'pattern': r'(Menudo|Cuajadilla)', 'category': 'menudo'},

    // Tapas
    {'pattern': r'^Tapas de Guisado', 'category': 'tapas'},

    // Lo dulce
    {'pattern': r'(Hot Cakes?|Churros|Molletes Dulces)', 'category': 'lo_dulce'},

    // Huaraches
    {'pattern': r'^Huarache', 'category': 'huaraches'},

    // Chilaquiles (no molletes de chilaquiles)
    {'pattern': r'^Chilaquiles', 'category': 'chilaquiles'},

    // Chile Relleno
    {'pattern': r'^Chile Relleno', 'category': 'chile_relleno'},

    // Arrachera (cuando el nombre lo dice explícitamente)
    {'pattern': r'(de Arrachera|Arrachera con|Arrachera$)', 'category': 'arrachera'},

    // Gorditas
    {'pattern': r'^Gordita', 'category': 'gorditas'},

    // Quesadillas y más
    {'pattern': r'(^Quesadilla|^Mamalona|^Taco |^Burrito|^Bolillo con|^Volcán|^Plato de Guisado)', 'category': 'quesadillas'},

    // Enmoladas
    {'pattern': r'^Enmoladas', 'category': 'enmoladas'},

    // Enchiladas
    {'pattern': r'^Enchiladas', 'category': 'enchiladas'},

    // Sopes
    {'pattern': r'^Sopes', 'category': 'sopes'},

    // Molletes (incl. de chilaquiles)
    {'pattern': r'^Molletes', 'category': 'molletes'},

    // Huevos
    {'pattern': r'^Huevos', 'category': 'huevos'},
  ];

  final dishes = await supabase.from('dishes').select('id, name, category');
  print('Total platillos: ${(dishes as List).length}');

  int updated = 0;
  int skipped = 0;
  for (final dish in dishes) {
    final name = dish['name'] as String;
    final currentCat = dish['category'] as String;
    String? newCat;

    for (final rule in rules) {
      if (RegExp(rule['pattern']!).hasMatch(name)) {
        newCat = rule['category'];
        break;
      }
    }

    if (newCat == null) {
      print('  ⚠ Sin match: "$name" (cat actual: $currentCat)');
      skipped++;
      continue;
    }

    if (newCat == currentCat) {
      skipped++;
      continue;
    }

    try {
      await supabase.from('dishes').update({'category': newCat}).eq('id', dish['id']);
      print('  ✔ "$name": $currentCat → $newCat');
      updated++;
    } catch (e) {
      print('  ✗ Error en "$name": $e');
    }
  }

  print('\n✔ Actualizados: $updated');
  print('— Sin cambio: $skipped');
  exit(0);
}
