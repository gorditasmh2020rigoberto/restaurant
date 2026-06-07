// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Abre una URL en una nueva pestaña del navegador.
void openInNewTab(String url) {
  html.window.open(url, '_blank');
}
