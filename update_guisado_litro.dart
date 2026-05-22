// Marca los ½ Litro Guisado (con y sin Carne) como requires_guisado=true
// para que en el diálogo de pedido aparezca el selector de guisado.
//
// Ejecutar: dart run update_guisado_litro.dart
// Idempotente: se puede correr varias veces sin efecto.

import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  // Buscar primero para ver estado actual
  final before = await supabase
      .from('dishes')
      .select('id, name, price, requires_guisado, category')
      .or('name.eq.½ Litro Guisado con Carne,name.eq.½ Litro Guisado sin Carne');
  print('Antes:');
  for (final r in (before as List)) {
    print('  ${r['name']} — requires_guisado=${r['requires_guisado']} category=${r['category']}');
  }

  // Update
  final updated = await supabase
      .from('dishes')
      .update({'requires_guisado': true})
      .or('name.eq.½ Litro Guisado con Carne,name.eq.½ Litro Guisado sin Carne')
      .select();
  print('\nActualizados ${(updated as List).length} platillos:');
  for (final r in updated) {
    print('  ${r['name']} — requires_guisado=${r['requires_guisado']}');
  }
}
