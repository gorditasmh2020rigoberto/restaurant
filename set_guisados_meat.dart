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

  // [nombre, spice_level (0..3), meat_type]
  const conCarne = <List<dynamic>>[
    // 🐄 Res
    ['Bistec a la mexicana', 1, 'res'],
    ['Lengua en salsa verde', 1, 'res'],
    ['Picadillo', 1, 'res'],
    // 🐷 Cerdo
    ['Buche a la mexicana', 2, 'cerdo'],
    ['Chicharrón prensado rojo', 2, 'cerdo'],
    ['Chicharrón prensado verde', 2, 'cerdo'],
    ['Chicharrón prensado chile morita', 3, 'cerdo'],
    ['Costillas en salsa verde', 2, 'cerdo'],
    ['Trocito en pasilla', 2, 'cerdo'],
    // 🐔 Pollo
    ['Tinga', 2, 'pollo'],
  ];
  const sinCarne = <List<dynamic>>[
    ['Arroz rojo', 0, 'sin_carne'],
    ['Champiñones', 0, 'sin_carne'],
    ['Papas con chorizo', 1, 'sin_carne'],
    ['Frijoles adobados', 1, 'sin_carne'],
    ['Frijoles refritos', 0, 'sin_carne'],
    ['Huevo en salsa', 1, 'sin_carne'],
    ['Papas', 1, 'sin_carne'],
    ['Mole rojo', 1, 'sin_carne'],
    ['Nopales', 1, 'sin_carne'],
    ['Duro', 1, 'sin_carne'],
    ['Rajas a la mexicana', 3, 'sin_carne'],
    ['Rajas con crema y elote', 0, 'sin_carne'],
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
    final meat = entry[2] as String;
    await supabase.from('guisados').insert({
      'name': name,
      'with_meat': true,
      'available': true,
      'branch_name': null,
      'spice_level': spice,
      'meat_type': meat,
    });
    print('  ✔ $name  ($meat, picor $spice)');
    ok++;
  }
  for (final entry in sinCarne) {
    final name = entry[0] as String;
    final spice = entry[1] as int;
    final meat = entry[2] as String;
    await supabase.from('guisados').insert({
      'name': name,
      'with_meat': false,
      'available': true,
      'branch_name': null,
      'spice_level': spice,
      'meat_type': meat,
    });
    print('  ✔ $name  ($meat, picor $spice)');
    ok++;
  }

  print('\n✔ Total insertados: $ok');
  print('  CON CARNE: ${conCarne.length}');
  print('  SIN CARNE: ${sinCarne.length}');
  exit(0);
}
