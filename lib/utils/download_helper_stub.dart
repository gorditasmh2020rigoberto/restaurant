import 'dart:typed_data';

/// Stub para builds non-web. En el APK los reportes no se "descargan"
/// como archivos del navegador; si llegaran a llamarse, no hacen nada.
void downloadBytes(Uint8List bytes, String filename,
    {String mimeType = 'application/octet-stream'}) {
  // No-op fuera de web.
}
