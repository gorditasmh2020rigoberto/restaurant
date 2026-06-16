// Fechas en las que la cuota de delivery cobra el extra de "festivo".
// Mezcla los días de descanso oficial (incluyendo los que se mueven
// cada año por la "Ley de Lunes Festivos" y Semana Santa) con las
// fechas del negocio que históricamente disparan demanda alta.
// Para agregar/quitar fechas fijas, edita [_fixedHolidays].

const List<(int month, int day)> _fixedHolidays = [
  // Oficial — descanso obligatorio
  (1, 1),    // Año Nuevo
  (5, 1),    // Día del Trabajo
  (9, 16),   // Independencia
  (12, 25),  // Navidad

  // Curados del negocio (no oficiales pero pico de pedidos)
  (2, 14),   // San Valentín
  (5, 10),   // Día de las Madres
  (9, 15),   // Grito de Independencia
  (11, 1),   // Todos los Santos
  (11, 2),   // Día de Muertos
  (12, 12),  // Virgen de Guadalupe
  (12, 24),  // Nochebuena
  (12, 31),  // Fin de año
];

/// N-ésima ocurrencia de un día de la semana en un mes/año dado.
/// `weekday` usa convención de DateTime: lunes=1 ... domingo=7.
DateTime _nthWeekdayOfMonth(int year, int month, int weekday, int n) {
  final first = DateTime(year, month, 1);
  final firstMatch = first.add(Duration(days: (weekday - first.weekday + 7) % 7));
  return firstMatch.add(Duration(days: (n - 1) * 7));
}

/// Algoritmo de Computus de Anónimo Gregoriano para calcular el
/// Domingo de Pascua del año dado. De ahí derivamos Jueves y Viernes
/// Santo (3 y 2 días antes).
DateTime _easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// `true` si [date] cae en alguna fecha festiva del negocio.
bool isHoliday(DateTime date) {
  // Fijas
  for (final (m, d) in _fixedHolidays) {
    if (date.month == m && date.day == d) return true;
  }
  // Móviles oficiales (Ley de Lunes Festivos)
  final y = date.year;
  final movables = <DateTime>[
    _nthWeekdayOfMonth(y, 2, DateTime.monday, 1),   // Constitución
    _nthWeekdayOfMonth(y, 3, DateTime.monday, 3),   // Natalicio de Juárez
    _nthWeekdayOfMonth(y, 11, DateTime.monday, 3),  // Revolución
    _nthWeekdayOfMonth(y, 6, DateTime.sunday, 3),   // Día del Padre
  ];
  for (final m in movables) {
    if (_isSameDay(date, m)) return true;
  }
  // Semana Santa
  final easter = _easterSunday(y);
  final juevesSanto = easter.subtract(const Duration(days: 3));
  final viernesSanto = easter.subtract(const Duration(days: 2));
  if (_isSameDay(date, juevesSanto) || _isSameDay(date, viernesSanto)) {
    return true;
  }
  return false;
}

/// Atajo: ¿hoy es festivo? (zona horaria local del dispositivo).
bool isHolidayToday() {
  final now = DateTime.now();
  return isHoliday(DateTime(now.year, now.month, now.day));
}
