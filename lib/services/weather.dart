import 'dart:convert';
import 'package:http/http.dart' as http;

/// Open-Meteo es gratis y no requiere API key. Devuelve `true` cuando hay
/// precipitación activa o el `weather_code` indica lluvia/llovizna/tormenta.
/// Si el endpoint falla por cualquier razón, devuelve `false` — no es
/// crítico: el usuario siempre puede prender el toggle manualmente.
Future<bool> isRainingNow({
  required double lat,
  required double lon,
}) async {
  final uri = Uri.parse(
    'https://api.open-meteo.com/v1/forecast'
    '?latitude=$lat&longitude=$lon'
    '&current=precipitation,weather_code'
    '&timezone=America%2FMexico_City',
  );
  try {
    final res = await http.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return false;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final current = body['current'] as Map<String, dynamic>?;
    if (current == null) return false;
    final precip = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    return precip > 0.1 || _isRainCode(code);
  } catch (_) {
    return false;
  }
}

/// WMO weather codes considerados lluvia para efectos de cuota:
///   51-57  Llovizna / llovizna helada
///   61-67  Lluvia / lluvia helada
///   80-82  Chubascos
///   95-99  Tormentas
bool _isRainCode(int code) {
  return (code >= 51 && code <= 67) ||
      (code >= 80 && code <= 82) ||
      (code >= 95 && code <= 99);
}
