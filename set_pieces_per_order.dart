import 'package:supabase/supabase.dart';
import 'dart:io';

/// Asigna pieces_per_order a cada platillo según su categoría y nombre.
/// Sólo actualiza si el valor actual está vacío (null) — no pisa lo que
/// ya hayas configurado manualmente.
///
/// Correr con:  dart run set_pieces_per_order.dart
///
/// Para forzar overwrite (re-aplicar a TODOS, incluso a los que ya tienen
/// valor), correr con:  dart run set_pieces_per_order.dart --force
void main(List<String> args) async {
  final force = args.contains('--force');

  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  // Reglas: el primero que machee gana. Se evalúan en orden.
  // [predicado(name, category) -> piezas]
  final rules = <int Function(String name, String cat)>[
    (n, c) {
      final ln = n.toLowerCase();
      // Variantes 1/2 orden → la mitad (mínimo 1).
      final isMedia = ln.contains('1/2') || ln.contains('½');
      // Sopes
      if (c == 'sopes') return isMedia ? 2 : 4;
      // Molletes
      if (c == 'molletes') return isMedia ? 2 : 3;
      // Enchiladas
      if (c == 'enchiladas') return isMedia ? 2 : 3;
      // Enmoladas
      if (c == 'enmoladas') return isMedia ? 2 : 3;
      // Tapas de guisado
      if (c == 'tapas') return isMedia ? 3 : 5;
      // Huaraches: por orden suelen ser 1 pieza grande
      if (c == 'huaraches') return 1;
      // Gorditas: 1 pieza
      if (c == 'gorditas') return 1;
      // Chilaquiles: 1 plato
      if (c == 'chilaquiles') return 1;
      // Chile Relleno: 1 pieza (relleno entero)
      if (c == 'chile_relleno') return 1;
      // Arrachera (tacos chico/grande)
      if (c == 'arrachera') return 1;
      // Quesadillas
      if (c == 'quesadillas') return 1;
      // Huevos: 2 huevos por orden
      if (c == 'huevos') return 2;
      // Lo dulce / postres
      if (c == 'lo_dulce' || c == 'dessert') {
        if (ln.contains('hot cake')) return 3;
        if (ln.contains('churro')) return 5;
        if (ln.contains('mollete')) return 3;
        return 1;
      }
      // Menudo: 1 plato
      if (c == 'menudo') return 1;
      // Para llevar / litros: 1 envase
      if (c == 'para_llevar' || ln.contains('litro')) return 1;
      // Bebidas / extras → 1 (o sin valor)
      return -1;
    },
  ];

  int? piecesFor(String name, String cat) {
    for (final r in rules) {
      final v = r(name, cat);
      if (v > 0) return v;
    }
    return null;
  }

  print('Leyendo platillos…');
  final rows = await supabase.from('dishes').select();
  final list = (rows as List).cast<Map<String, dynamic>>();
  print('Encontrados: ${list.length}\n');

  int updated = 0;
  int skipped = 0;
  for (final d in list) {
    final name = d['name'] as String? ?? '';
    final cat = (d['category'] as String? ?? '').toLowerCase();
    final current = d['pieces_per_order'] as int?;
    final target = piecesFor(name, cat);

    if (target == null) {
      print('  ·  $name  [${cat}]  — sin sugerencia');
      skipped++;
      continue;
    }
    if (!force && current != null) {
      print('  =  $name  [${cat}]  — ya tiene $current, no se pisa');
      skipped++;
      continue;
    }
    if (current == target) {
      print('  =  $name  [${cat}]  — ya en $target');
      skipped++;
      continue;
    }

    await supabase
        .from('dishes')
        .update({'pieces_per_order': target}).eq('id', d['id']);
    print('  ✔  $name  [${cat}]  →  $target piezas');
    updated++;
  }

  print('\nResumen:');
  print('  Actualizados: $updated');
  print('  Sin cambios:  $skipped');
  exit(0);
}
