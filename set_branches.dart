import 'dart:convert';
import 'dart:io';
import 'package:supabase/supabase.dart';

/// Pone la lista oficial de sucursales en admin_settings.branches_list.
/// Editar abajo si necesitas agregar más.
///
/// Correr con:  dart run set_branches.dart
void main() async {
  final supabase = SupabaseClient(
    'https://jcaqolmacqhhgtjdgvaz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk',
  );

  const branches = [
    'Sucursal Maravillas',
    'Sucursal Pocitos',
  ];

  final value = jsonEncode(branches);

  // Upsert por setting_key (asume PK o unique en setting_key).
  try {
    await supabase.from('admin_settings').upsert(
      {
        'setting_key': 'branches_list',
        'setting_value': value,
      },
      onConflict: 'setting_key',
    );
    print('✔ admin_settings.branches_list = $value');
  } catch (e) {
    // Fallback si no hay unique constraint: borrar + insertar.
    try {
      await supabase
          .from('admin_settings')
          .delete()
          .eq('setting_key', 'branches_list');
      await supabase.from('admin_settings').insert({
        'setting_key': 'branches_list',
        'setting_value': value,
      });
      print('✔ admin_settings.branches_list (re-creado) = $value');
    } catch (e2) {
      print('✗ Error: $e2');
      exit(1);
    }
  }
  exit(0);
}
