import 'dart:io';
import 'package:supabase/supabase.dart';

/// Marca una sucursal como pagada hasta una fecha dada, o por X días
/// más a partir de hoy.
///
/// Ejemplos:
///   dart run set_subscription.dart list
///   dart run set_subscription.dart "Sucursal Maravillas" 30
///   dart run set_subscription.dart "Sucursal Pocitos" 2026-12-31
void main(List<String> args) async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  // ── Comando: list ─────────────────────────────────────────────────
  if (args.isEmpty || args.first.toLowerCase() == 'list') {
    final rows = await supabase.from('subscriptions').select();
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) {
      print('(sin suscripciones registradas)');
      exit(0);
    }
    print('Suscripciones activas:');
    for (final r in list) {
      final paid = r['paid_until'];
      final today = DateTime.now();
      final paidDate = DateTime.parse(paid as String);
      final days = paidDate.difference(DateTime(today.year, today.month, today.day)).inDays;
      final state = days < 0
          ? '⛔ vencida hace ${-days} día(s)'
          : (days <= 7 ? '⚠️  vence en $days día(s)' : '✓ vigente ($days días)');
      print('  ${r['branch_name']}  →  $paid   $state');
    }
    exit(0);
  }

  // ── Comando: <branch> <fecha-o-días> ──────────────────────────────
  if (args.length < 2) {
    print('Uso:');
    print('  dart run set_subscription.dart list');
    print('  dart run set_subscription.dart "Sucursal Maravillas" 30');
    print('  dart run set_subscription.dart "Sucursal Pocitos" 2026-12-31');
    exit(1);
  }

  final branch = args[0];
  final spec = args[1];

  DateTime paidUntil;
  // Intenta parsear como número de días
  final asInt = int.tryParse(spec);
  if (asInt != null) {
    paidUntil = DateTime.now().add(Duration(days: asInt));
  } else {
    try {
      paidUntil = DateTime.parse(spec);
    } catch (_) {
      print('✗ Fecha inválida: $spec (usa YYYY-MM-DD o un número de días).');
      exit(1);
    }
  }

  final dateStr =
      '${paidUntil.year}-${paidUntil.month.toString().padLeft(2, '0')}-${paidUntil.day.toString().padLeft(2, '0')}';

  try {
    await supabase.from('subscriptions').upsert(
      {
        'branch_name': branch,
        'paid_until': dateStr,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'branch_name',
    );
    print('✔ $branch  pagada hasta  $dateStr');
  } catch (e) {
    print('✗ Error: $e');
    print('Sugerencia: ¿corriste create_subscriptions_table.sql en Supabase?');
    exit(1);
  }
  exit(0);
}
