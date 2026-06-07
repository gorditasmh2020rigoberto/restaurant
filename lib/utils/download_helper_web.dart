// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Dispara la descarga de [bytes] como [filename] desde el navegador.
void downloadBytes(Uint8List bytes, String filename,
    {String mimeType = 'application/octet-stream'}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
