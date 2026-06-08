import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';

enum SubscriptionStatus {
  /// Pago al día — todo funciona normal.
  active,

  /// El pago venció hace ≤ graceDays. La app sigue funcionando pero
  /// muestra banner de aviso.
  grace,

  /// Pago vencido fuera del periodo de gracia. Bloquea acceso.
  expired,

  /// No hay registro de suscripción para esta sucursal (primera vez,
  /// problema de configuración, etc.). Por seguridad se trata como
  /// expired hasta que el admin lo configure.
  missing,
}

class SubscriptionStatusInfo {
  final SubscriptionStatus status;
  final DateTime? paidUntil;
  final String contactInfo;

  /// Días que faltan (positivos) o pasaron (negativos) desde paid_until.
  /// null si no hay registro.
  final int? daysFromExpiry;

  const SubscriptionStatusInfo({
    required this.status,
    this.paidUntil,
    this.contactInfo = 'Contacta a tu proveedor',
    this.daysFromExpiry,
  });
}

/// Periodo de gracia (días después del vencimiento donde la app sigue
/// funcionando pero con banner).
const int kSubscriptionGraceDays = 3;

/// Días antes del vencimiento donde ya aparece el banner amarillo
/// "Próximo a vencer".
const int kSubscriptionWarnDays = 7;

/// Consulta el estado de la suscripción de la sucursal actual.
/// Devuelve `missing` si la tabla aún no existe o no hay registro —
/// la UI debe tratarlo como bloqueante.
Future<SubscriptionStatusInfo> checkSubscription() async {
  try {
    final row = await Supabase.instance.client
        .from('subscriptions')
        .select()
        .eq('branch_name', Globals.currentBranch)
        .maybeSingle();
    if (row == null) {
      return const SubscriptionStatusInfo(status: SubscriptionStatus.missing);
    }
    final paidUntil = DateTime.parse(row['paid_until'] as String);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final paidDate =
        DateTime(paidUntil.year, paidUntil.month, paidUntil.day);
    final diff = paidDate.difference(todayDate).inDays; // >0 vigente
    final contact = (row['contact_info'] as String?) ?? '';

    SubscriptionStatus status;
    if (diff >= 0) {
      status = SubscriptionStatus.active;
    } else if (diff >= -kSubscriptionGraceDays) {
      status = SubscriptionStatus.grace;
    } else {
      status = SubscriptionStatus.expired;
    }
    return SubscriptionStatusInfo(
      status: status,
      paidUntil: paidDate,
      contactInfo: contact,
      daysFromExpiry: diff,
    );
  } catch (_) {
    // Tabla no existe aún o sin red. Por defecto NO bloqueamos en este
    // caso para no dejar caído al cliente por un problema técnico nuestro.
    return const SubscriptionStatusInfo(status: SubscriptionStatus.active);
  }
}
