import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );
  final r = await supabase
      .from('dishes')
      .select('id, name, price, category, requires_guisado, is_sale, max_time')
      .or('name.eq.1 Litro Arroz,name.eq.1 Litro Frijoles');
  for (final row in (r as List)) {
    print(row);
  }
}
