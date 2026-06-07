import 'package:supabase/supabase.dart';
import 'dart:io';

/// Resetea la tabla `guisados`: borra todos los registros y deja
/// exactamente los 19 que el usuario quiere ofrecer, con `with_meat`
/// asignado correctamente y `available = true`.
///
/// Correr con:  dart run set_guisados_meat.dart
void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  // [nombre, spice_level (0..3)]
  const conCarne = <List<dynamic>>[
    ['Bistec', 1],
    ['Buche', 2],
    ['Chicharrón prensado verde', 2],
    ['Chicharrón prensado rojo', 2],
    ['Chicharrón prensado morita', 3],
    ['Duro', 1],
    ['Costilla', 2],
    ['Mole', 1],
    ['Lengua', 1],
    ['Picadillo', 1],
    ['Tinga', 2],
    ['Trocito', 2],
  ];
  const sinCarne = <List<dynamic>>[
    ['Champiñones', 0],
    ['Papas con chorizo', 1],
    ['Papas a la mexicana', 2],
    ['Nopales', 1],
    ['Huevo en salsa', 1],
    ['Rajas a la mexicana', 3],
    ['Rajas con crema', 0],
  ];

  print('Borrando todos los guisados existentes…');
  await supabase
      .from('guisados')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');

  print('Insertando ${conCarne.length + sinCarne.length} guisados…\n');
  int ok = 0;
  for (final entry in conCarne) {
    final name = entry[0] as String;
    final spice = entry[1] as int;
    await supabase.from('guisados').insert({
      'name': name,
      'with_meat': true,
      'available': true,
      'branch_name': null,
      'spice_level': spice,
    });
    print('  ✔ $name  (CON CARNE, picor $spice)');
    ok++;
  }
  for (final entry in sinCarne) {
    final name = entry[0] as String;
    final spice = entry[1] as int;
    await supabase.from('guisados').insert({
      'name': name,
      'with_meat': false,
      'available': true,
      'branch_name': null,
      'spice_level': spice,
    });
    print('  ✔ $name  (SIN CARNE, picor $spice)');
    ok++;
  }

  print('\n✔ Total insertados: $ok');
  print('  CON CARNE: ${conCarne.length}');
  print('  SIN CARNE: ${sinCarne.length}');
  exit(0);
}
