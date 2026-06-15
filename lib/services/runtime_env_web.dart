// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

/// Lee una variable de window.* (ej. window.GOOGLE_MAPS_API_KEY) que
/// fue inyectada por env-config.js generado en docker-entrypoint.sh.
String runtimeEnv(String name) {
  try {
    final v = _window.getProperty(name.toJS);
    if (v == null) return '';
    return v.toString();
  } catch (_) {
    return '';
  }
}
