import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Resultado de geocoding: coordenadas + nombre formateado.
class GeocodeResult {
  final double lat;
  final double lon;
  final String displayName;
  const GeocodeResult({
    required this.lat,
    required this.lon,
    required this.displayName,
  });
}

/// Genera varias variantes del query para intentar el geocoding.
/// Nominatim no es muy bueno con direcciones residenciales mexicanas,
/// así que probamos diferentes formatos hasta que uno acierte.
List<String> _queryVariants(String address) {
  var raw = address.trim();
  // Asegura "Aguascalientes, México" al final
  if (!raw.toLowerCase().contains('aguascalientes')) {
    raw = '$raw, Aguascalientes';
  }
  if (!raw.toLowerCase().contains('méxico') &&
      !raw.toLowerCase().contains('mexico')) {
    raw = '$raw, México';
  }
  final variants = <String>[raw];

  // Intentar separar "calle número" → "Calle Nombre N, Colonia, Agus, Mx"
  final m = RegExp(r'^([a-záéíóúñü ]+?)\s+(\d+)\s+(.+)$',
          caseSensitive: false)
      .firstMatch(address.trim());
  if (m != null) {
    final street = m.group(1)!.trim();
    final number = m.group(2)!.trim();
    final rest = m.group(3)!.trim();
    variants.add('Calle $street $number, $rest, Aguascalientes, México');
    variants.add('$street $number, $rest, Aguascalientes, México');
    variants.add('Avenida $street $number, $rest, Aguascalientes, México');
    // Solo colonia (sin calle/número)
    variants.add('$rest, Aguascalientes, México');
  }
  // Dedup conservando orden
  final seen = <String>{};
  return variants.where((v) => seen.add(v.toLowerCase())).toList();
}

/// Geocodifica una dirección usando Nominatim (OpenStreetMap, gratis).
/// Intenta varias variantes del query para mejorar hit rate.
/// Devuelve null si ninguna variante encontró nada.
Future<GeocodeResult?> geocodeAddress(String address) async {
  if (address.trim().isEmpty) return null;
  final variants = _queryVariants(address);

  for (final q in variants) {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&limit=1&countrycodes=mx&q=${Uri.encodeComponent(q)}',
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'GorditasMisHermanas/1.0 (delivery-fee-calc)',
        'Accept': 'application/json',
        'Accept-Language': 'es',
      }).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) continue;
      final list = jsonDecode(resp.body) as List;
      if (list.isEmpty) continue;
      final first = list.first as Map<String, dynamic>;
      return GeocodeResult(
        lat: double.parse(first['lat'].toString()),
        lon: double.parse(first['lon'].toString()),
        displayName: first['display_name']?.toString() ?? address,
      );
    } catch (_) {
      // pasa a la siguiente variante
    }
    // Rate-limit cortés entre intentos
    await Future<void>.delayed(const Duration(milliseconds: 1100));
  }
  return null;
}

/// Distancia en kilómetros entre dos puntos (lat, lon) usando fórmula
/// haversine. Es distancia en línea recta (no por carretera), pero da
/// una aproximación razonable para tarifas escalonadas.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);

/// Factor de "ajuste de calle" — la distancia en carretera suele ser
/// 1.3× la línea recta en zonas urbanas mexicanas. Multiplicamos por
/// esto para tener una mejor aproximación a km reales de viaje.
const double kStreetFactor = 1.3;

/// Calcula km aproximados desde una sucursal hasta una dirección destino
/// (geocodea el destino, usa haversine + factor de calle). null si no
/// pudo geocodear.
Future<double?> kmFromBranchTo({
  required double branchLat,
  required double branchLon,
  required String destinationAddress,
}) async {
  final dest = await geocodeAddress(destinationAddress);
  if (dest == null) return null;
  final raw = haversineKm(branchLat, branchLon, dest.lat, dest.lon);
  return double.parse((raw * kStreetFactor).toStringAsFixed(1));
}
