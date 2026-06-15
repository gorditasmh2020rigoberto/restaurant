import 'dart:convert';
import 'package:http/http.dart' as http;

/// API key de Google Maps inyectada al build con --dart-define.
/// Si está vacía, la integración de Google se ignora y se cae al geocoder
/// OSM/Nominatim como fallback.
const String googleMapsApiKey =
    String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

bool get hasGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;

/// Calcula la distancia real por carretera (en km) desde el origen a la
/// dirección destino usando Google Distance Matrix API.
///
/// Devuelve null si falla (sin red, key inválida, dirección no encontrada,
/// etc.). El llamador debe caer a otro método.
Future<double?> googleDrivingDistanceKm({
  required double originLat,
  required double originLon,
  required String destinationAddress,
}) async {
  if (!hasGoogleMapsApiKey) return null;
  if (destinationAddress.trim().isEmpty) return null;

  // Sesgo regional para mejorar precisión local — Google ignora "región"
  // si la dirección no es ambigua, así que no estorba.
  var dest = destinationAddress.trim();
  if (!dest.toLowerCase().contains('aguascalientes')) {
    dest = '$dest, Aguascalientes, México';
  }

  try {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=$originLat,$originLon'
      '&destinations=${Uri.encodeComponent(dest)}'
      '&mode=driving'
      '&language=es'
      '&region=mx'
      '&units=metric'
      '&key=$googleMapsApiKey',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') return null;
    final rows = body['rows'] as List?;
    if (rows == null || rows.isEmpty) return null;
    final elements = (rows.first as Map)['elements'] as List?;
    if (elements == null || elements.isEmpty) return null;
    final first = elements.first as Map<String, dynamic>;
    if (first['status'] != 'OK') return null;
    final distance = first['distance'] as Map<String, dynamic>?;
    if (distance == null) return null;
    final meters = (distance['value'] as num).toDouble();
    final km = meters / 1000.0;
    // Redondear a 1 decimal
    return double.parse(km.toStringAsFixed(1));
  } catch (_) {
    return null;
  }
}
