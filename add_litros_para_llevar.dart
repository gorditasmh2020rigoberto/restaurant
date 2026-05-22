// Script de un solo uso: agrega "1 Litro Arroz" y "1 Litro Frijoles" a la
// categoría 'para_llevar' en Supabase.
//
// Ejecutar:
//   dart run add_litros_para_llevar.dart
//
// Idempotente: si los nombres ya existen, no los inserta de nuevo.

import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  final nuevos = [
    {
      'name': '1 Litro Arroz',
      'description': 'Para llevar',
      'price': 60,
      'cost': 0,
      'category': 'para_llevar',
      'max_time': 5,
      'requires_guisado': false,
      'is_sale': true,
      'is_purchase': false,
    },
    {
      'name': '1 Litro Frijoles',
      'description': 'Para llevar',
      'price': 60,
      'cost': 0,
      'category': 'para_llevar',
      'max_time': 5,
      'requires_guisado': false,
      'is_sale': true,
      'is_purchase': false,
    },
  ];

  // Verificar existentes
  final existing = await supabase
      .from('dishes')
      .select('name')
      .or('name.eq.1 Litro Arroz,name.eq.1 Litro Frijoles');
  final yaExisten = (existing as List)
      .cast<Map<String, dynamic>>()
      .map((r) => r['name'] as String)
      .toSet();
  print('Ya existen en BD: $yaExisten');

  final aInsertar = nuevos
      .where((d) => !yaExisten.contains(d['name']))
      .toList();

  if (aInsertar.isEmpty) {
    print('Nada que insertar — ambos ya existen.');
    return;
  }

  print('Insertando ${aInsertar.length} platillos…');
  try {
    final result = await supabase.from('dishes').insert(aInsertar).select();
    print('OK. Insertados:');
    for (final r in (result as List)) {
      print('  - ${r['name']}  \$${r['price']}  (id: ${r['id']})');
    }
  } catch (e) {
    print('ERROR insertando: $e');
  }
}
