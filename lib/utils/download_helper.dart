/// Re-export condicional para descargar archivos. En web usa dart:html
/// (Blob + AnchorElement). En APK Android/iOS es no-op.
export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';
