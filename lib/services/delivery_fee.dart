/// Calculador de cuota de Servicio de Delivery FLASH.
///
/// Tarifas base por zona (km):
///   0 – 1.9 km    → $35
///   2 – 3 km      → $40
///   3.1 – 5.5 km  → $50
///   5.6 – 8 km    → $60
///   8.1 – 10 km   → $70
///   > 10 km       → $70 + ($5 por cada km arriba de 10)
///
/// Cargos adicionales:
///   - Carretera: +$10 por cada km de carretera (input aparte).
///   - Día lluvioso: +$20.
///   - Día festivo: +$20.

class DeliveryFeeBreakdown {
  final double base; // por zona
  final double extraKm; // > 10 km
  final double carretera; // $10/km
  final double rain; // +$20
  final double holiday; // +$20
  double get total => base + extraKm + carretera + rain + holiday;

  const DeliveryFeeBreakdown({
    required this.base,
    required this.extraKm,
    required this.carretera,
    required this.rain,
    required this.holiday,
  });
}

double _baseForKm(double km) {
  if (km <= 0) return 0;
  if (km < 2) return 35;
  if (km <= 3) return 40;
  if (km <= 5.5) return 50;
  if (km <= 8) return 60;
  if (km <= 10) return 70;
  // > 10
  return 70;
}

DeliveryFeeBreakdown calculateDeliveryFee({
  required double km,
  double kmCarretera = 0,
  bool rain = false,
  bool holiday = false,
}) {
  final base = _baseForKm(km);
  final extraKm = km > 10 ? (km - 10) * 5 : 0.0;
  final carretera = kmCarretera * 10;
  return DeliveryFeeBreakdown(
    base: base,
    extraKm: extraKm,
    carretera: carretera,
    rain: rain ? 20 : 0,
    holiday: holiday ? 20 : 0,
  );
}

/// Dirección oficial de cada sucursal (origen para calcular distancia
/// en Google Maps). Si en el futuro se quiere mantener vía admin,
/// migrar esto a admin_settings.
const Map<String, String> kBranchAddresses = {
  'Sucursal Maravillas':
      'La Providencia 97-B, Esq. Siglo XXI, Aguascalientes',
  'Sucursal Pocitos': 'Garza Sada 108, Aguascalientes',
};

/// URL de Google Maps con ruta desde la sucursal al destino del cliente.
/// Si no hay dirección de cliente, abre solo la sucursal.
String buildMapsRouteUrl({
  required String branchName,
  String? destinationAddress,
}) {
  final origin =
      Uri.encodeComponent(kBranchAddresses[branchName] ?? branchName);
  if (destinationAddress == null || destinationAddress.trim().isEmpty) {
    return 'https://www.google.com/maps/search/?api=1&query=$origin';
  }
  final dest = Uri.encodeComponent(destinationAddress.trim());
  return 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest&travelmode=driving';
}
