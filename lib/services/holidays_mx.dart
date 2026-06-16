/// Fechas en las que la cuota de delivery cobra el extra de "festivo".
/// No es la lista oficial de descanso obligatorio — es la lista del
/// negocio (fechas de pico de pedidos). Edita libremente.
///
/// Los meses van 1-12 y los días 1-31 (como `DateTime.month`/`.day`).
const List<(int month, int day)> _fixedHolidays = [
  (1, 1),    // Año Nuevo
  (2, 14),   // San Valentín
  (5, 10),   // Día de las Madres
  (9, 15),   // Grito de Independencia
  (9, 16),   // Independencia
  (11, 1),   // Todos los Santos
  (11, 2),   // Día de Muertos
  (12, 12),  // Virgen de Guadalupe
  (12, 24),  // Nochebuena
  (12, 25),  // Navidad
  (12, 31),  // Fin de año
];

/// Tercer domingo de junio del año dado (Día del Padre en México).
DateTime _fathersDay(int year) {
  final firstOfJune = DateTime(year, 6, 1);
  // weekday: lunes=1 ... domingo=7
  final daysToFirstSunday = (7 - firstOfJune.weekday) % 7;
  final firstSunday = firstOfJune.add(Duration(days: daysToFirstSunday));
  return firstSunday.add(const Duration(days: 14));
}

/// `true` si [date] cae en alguna fecha festiva del negocio.
bool isHoliday(DateTime date) {
  for (final (m, d) in _fixedHolidays) {
    if (date.month == m && date.day == d) return true;
  }
  final fathers = _fathersDay(date.year);
  if (date.month == fathers.month && date.day == fathers.day) return true;
  return false;
}

/// Atajo: ¿hoy es festivo? (zona horaria local del dispositivo).
bool isHolidayToday() {
  final now = DateTime.now();
  return isHoliday(DateTime(now.year, now.month, now.day));
}
