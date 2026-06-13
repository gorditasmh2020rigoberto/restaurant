import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  final rows = await supabase
      .from('guisados')
      .select()
      .order('name');
  final list = (rows as List).cast<Map<String, dynamic>>();
  print('Guisados (${list.length}):');
  for (final g in list) {
    print('  • ${g['name']}  branch=${g['branch_name'] ?? "(todas)"}  '
        'available=${g['available']}  with_meat=${g['with_meat']}');
  }
  exit(0);
}
