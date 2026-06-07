import 'package:flutter/material.dart';

/// Stub para builds non-web. Cuando la app corre como APK no hay
/// "limpiar caché del navegador / service worker", así que estas
/// funciones son no-op y el widget no muestra nada.

Future<void> forceAppUpdate(BuildContext context) async {
  // No-op fuera de web.
}

class UpdateAppButton extends StatelessWidget {
  final bool compact;
  const UpdateAppButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
