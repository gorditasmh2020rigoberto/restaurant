/// Re-export condicional. En web usa html.window.open; en APK es no-op.
export 'url_opener_stub.dart' if (dart.library.html) 'url_opener_web.dart';
