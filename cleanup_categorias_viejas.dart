import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  const newCats = {
    'huevos','molletes','sopes','enchiladas','enmoladas','gorditas',
    'quesadillas','arrachera','chile_relleno','chilaquiles','huaraches',
    'tapas','menudo','lo_dulce','para_llevar','extras','bebidas',
  };

  final dishes = await supabase.from('dishes').select('id, name, category');
  final toDelete = (dishes as List)
      .where((d) => !newCats.contains(d['category']))
      .toList();

  print('Platillos con categoría vieja: ${toDelete.length}');
  for (final d in toDelete) {
    print('  - "${d['name']}" (${d['category']})');
  }

  int ok = 0, blocked = 0;
  for (final d in toDelete) {
    try {
      await supabase.from('dishes').delete().eq('id', d['id']);
      ok++;
    } catch (e) {
      blocked++;
      print('  ⚠ No se pudo borrar "${d['name']}" (en órdenes históricas): $e');
    }
  }

  print('\n✔ Borrados: $ok');
  if (blocked > 0) print('⚠ Bloqueados (en órdenes): $blocked');
  exit(0);
}
