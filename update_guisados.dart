import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  // Borrar guisados existentes
  print('Borrando guisados anteriores...');
  await supabase.from('guisados').delete().neq('id', '00000000-0000-0000-0000-000000000000');

  // Lista completa del menú físico
  const guisados = [
    'Arroz rojo',
    'Bistec a la mexicana',
    'Buche a la mexicana',
    'Champiñones',
    'Chicharrón prensado rojo',
    'Chicharrón prensado verde',
    'Chicharrón prensado chile morita',
    'Costillas en salsa verde',
    'Papas con chorizo',
    'Frijoles adobados',
    'Frijoles refritos',
    'Huevo en salsa',
    'Papas',
    'Mole rojo',
    'Nopales',
    'Lengua en salsa verde',
    'Duro',
    'Picadillo',
    'Rajas a la mexicana',
    'Rajas con crema y elote',
    'Tinga',
    'Trocito en pasilla',
  ];

  print('Insertando ${guisados.length} guisados...');
  int ok = 0;
  for (final name in guisados) {
    await supabase.from('guisados').insert({'name': name, 'available': true});
    print('  ✔ $name');
    ok++;
  }

  print('\n✔ Total insertados: $ok');
  exit(0);
}
