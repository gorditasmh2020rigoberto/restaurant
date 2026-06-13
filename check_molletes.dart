import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  final rows = await supabase
      .from('dishes')
      .select('name, category, requires_guisado, price')
      .eq('category', 'molletes')
      .order('name');
  final list = (rows as List).cast<Map<String, dynamic>>();
  print('Molletes en la DB (${list.length}):');
  for (final d in list) {
    print('  • ${d['name']}  [\$${d['price']}]  '
        'requires_guisado=${d['requires_guisado']}');
  }
  exit(0);
}
