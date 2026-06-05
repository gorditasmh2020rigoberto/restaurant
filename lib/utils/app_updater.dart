import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:js_interop';

/// Enlace a window.forceUpdate() definida en web/index.html
/// Desregistra service workers, limpia todos los caches y recarga.
@JS('forceUpdate')
external void _jsForceUpdate();

/// Fallback: recarga simple sin limpiar caché
@JS('location.reload')
external void _jsReload();

/// Limpia caché del navegador y service workers, luego recarga la app.
/// Solo funciona en web (PWA). En nativo no hace nada.
Future<void> forceAppUpdate(BuildContext context) async {
  if (!kIsWeb) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Limpiando caché... se recargará en un momento'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );

  await Future.delayed(const Duration(milliseconds: 900));

  try {
    _jsForceUpdate(); // Llama window.forceUpdate() del index.html
  } catch (_) {
    _jsReload(); // Fallback: recarga simple
  }
}

/// Botón reutilizable "Actualizar App" para cualquier pantalla.
class UpdateAppButton extends StatelessWidget {
  /// [compact] = versión pequeña tipo TextButton (para mesero / login)
  final bool compact;
  const UpdateAppButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    if (compact) {
      return TextButton.icon(
        onPressed: () => forceAppUpdate(context),
        icon: const Icon(Icons.system_update_alt,
            size: 15, color: Color(0xFF64748B)),
        label: const Text(
          'Actualizar versión',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: () => forceAppUpdate(context),
      icon: const Icon(Icons.system_update_alt, size: 16),
      label: const Text('Actualizar App', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
