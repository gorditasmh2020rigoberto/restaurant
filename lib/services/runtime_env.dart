/// Lee variables de entorno inyectadas en runtime.
/// - Web: window.NAME (puesto por env-config.js).
/// - APK / iOS: siempre devuelve "" (usa --dart-define en su lugar).
export 'runtime_env_stub.dart' if (dart.library.html) 'runtime_env_web.dart';
