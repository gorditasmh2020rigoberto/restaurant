import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  // Borrar gorditas actuales (que no estén en órdenes históricas)
  print('Borrando gorditas anteriores...');
  final current = await supabase
      .from('dishes')
      .select('id, name')
      .eq('category', 'gorditas');

  for (final d in (current as List)) {
    try {
      await supabase.from('dishes').delete().eq('id', d['id']);
      print('  ✔ Borrado: ${d['name']}');
    } catch (e) {
      // En órdenes históricas — desactivar
      await supabase.from('dishes').update({'is_sale': false}).eq('id', d['id']);
      print('  ⚠ Desactivado (en historial): ${d['name']}');
    }
  }

  // Insertar 6 gorditas separadas
  const gorditas = [
    {'name': 'Gordita de Maíz',             'description': 'Sin queso', 'price': 37},
    {'name': 'Gordita de Maíz con Queso',   'description': 'Con queso', 'price': 42},
    {'name': 'Gordita de Maíz Frita',       'description': 'Sin queso', 'price': 37},
    {'name': 'Gordita Frita con Queso',     'description': 'Con queso', 'price': 42},
    {'name': 'Gordita de Harina',           'description': 'Sin queso', 'price': 37},
    {'name': 'Gordita de Harina con Queso', 'description': 'Con queso', 'price': 42},
  ];

  print('\nInsertando gorditas...');
  for (final g in gorditas) {
    await supabase.from('dishes').insert({
      'name': g['name'],
      'description': g['description'],
      'price': g['price'],
      'cost': 0,
      'category': 'gorditas',
      'requires_guisado': true,
      'max_time': 10,
    });
    print('  ✔ ${g['name']} - \$${g['price']}');
  }

  print('\n✔ Gorditas actualizadas: ${gorditas.length}');
  exit(0);
}
