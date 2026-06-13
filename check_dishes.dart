import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  final rows = await supabase
      .from('dishes')
      .select('name, category, price, pieces_per_order, requires_guisado')
      .order('category')
      .order('name');
  final list = (rows as List).cast<Map<String, dynamic>>();
  print('Total dishes en DB: ${list.length}\n');

  // Agrupado por categoría
  final byCat = <String, List<Map<String, dynamic>>>{};
  for (final d in list) {
    final cat = (d['category'] as String?) ?? '?';
    byCat.putIfAbsent(cat, () => []).add(d);
  }
  final cats = byCat.keys.toList()..sort();
  for (final cat in cats) {
    final items = byCat[cat]!;
    print('━━━ $cat  (${items.length})');
    for (final d in items) {
      final n = d['name'];
      final p = d['price'];
      final pcs = d['pieces_per_order'];
      final rg = d['requires_guisado'] == true ? ' [G]' : '';
      final pcsStr = pcs != null ? '  (${pcs} pzas)' : '';
      print('   • \$${p}   $n$rg$pcsStr');
    }
    print('');
  }
  exit(0);
}
