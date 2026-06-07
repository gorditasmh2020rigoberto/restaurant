/// Re-export condicional para que el código que importa
/// `widgets/clip_brick_widget.dart` funcione tanto en web (carga el JS
/// real de Clip) como en Android/iOS (carga un stub que no compila
/// dart:html / dart:js).
export 'clip_brick_widget_stub.dart'
    if (dart.library.html) 'clip_brick_widget_web.dart';
