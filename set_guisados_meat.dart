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

  const conCarne = [
    'Bistec',
    'Buche',
    'Chicharrón prensado verde',
    'Chicharrón prensado rojo',
    'Chicharrón prensado morita',
    'Duro',
    'Costilla',
    'Mole',
    'Lengua',
    'Picadillo',
    'Tinga',
    'Trocito',
  ];
  const sinCarne = [
    'Champiñones',
    'Papas con chorizo',
    'Papas a la mexicana',
    'Nopales',
    'Huevo en salsa',
    'Rajas a la mexicana',
    'Rajas con crema',
  ];

  print('Borrando todos los guisados existentes…');
  await supabase
      .from('guisados')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');

  print('Insertando ${conCarne.length + sinCarne.length} guisados…\n');
  int ok = 0;
  for (final name in conCarne) {
    await supabase.from('guisados').insert({
      'name': name,
      'with_meat': true,
      'available': true,
      'branch_name': null,
    });
    print('  ✔ $name  (CON CARNE)');
    ok++;
  }
  for (final name in sinCarne) {
    await supabase.from('guisados').insert({
      'name': name,
      'with_meat': false,
      'available': true,
      'branch_name': null,
    });
    print('  ✔ $name  (SIN CARNE)');
    ok++;
  }

  print('\n✔ Total insertados: $ok');
  print('  CON CARNE: ${conCarne.length}');
  print('  SIN CARNE: ${sinCarne.length}');
  exit(0);
}
