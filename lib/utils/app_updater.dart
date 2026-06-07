/// Re-export condicional: en web carga el código real (dart:js_interop),
/// en Android/iOS carga un stub no-op.
export 'app_updater_stub.dart' if (dart.library.html) 'app_updater_web.dart';
