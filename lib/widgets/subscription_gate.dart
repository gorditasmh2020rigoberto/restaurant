import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

/// Envuelve la app inicial: hace la consulta de suscripción y, según el
/// estado, deja pasar al [child], muestra un banner arriba (grace o
/// próximo a vencer) o bloquea con pantalla "Servicio pausado".
///
/// La consulta se hace una sola vez en initState; si necesitas
/// re-validar (después de actualizar el pago) recarga la app.
class SubscriptionGate extends StatefulWidget {
  final Widget child;
  const SubscriptionGate({super.key, required this.child});

  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate> {
  SubscriptionStatusInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final info = await checkSubscription();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF1DE),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6D00)),
        ),
      );
    }
    final info = _info!;
    if (info.status == SubscriptionStatus.expired ||
        info.status == SubscriptionStatus.missing) {
      return _BlockedScreen(info: info, onRetry: _check);
    }

    // Si está en periodo de gracia o cerca de vencer, mostrar banner
    // arriba del [child].
    final showBanner = info.status == SubscriptionStatus.grace ||
        (info.daysFromExpiry != null &&
            info.daysFromExpiry! >= 0 &&
            info.daysFromExpiry! <= kSubscriptionWarnDays);
    if (!showBanner) return widget.child;

    return Column(
      children: [
        _ExpiryBanner(info: info),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _ExpiryBanner extends StatelessWidget {
  final SubscriptionStatusInfo info;
  const _ExpiryBanner({required this.info});

  @override
  Widget build(BuildContext context) {
    final isGrace = info.status == SubscriptionStatus.grace;
    final color = isGrace ? const Color(0xFFB7472A) : const Color(0xFFE07A30);
    final msg = isGrace
        ? 'Pago vencido hace ${-info.daysFromExpiry!} día(s). Renueva pronto para evitar interrupción.'
        : 'Pago próximo a vencer en ${info.daysFromExpiry!} día(s). ${info.contactInfo}';
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFAF1DE), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                    color: Color(0xFFFAF1DE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  final SubscriptionStatusInfo info;
  final VoidCallback onRetry;
  const _BlockedScreen({required this.info, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final missing = info.status == SubscriptionStatus.missing;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF1DE),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB7472A).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline,
                      size: 64, color: Color(0xFFB7472A)),
                ),
                const SizedBox(height: 24),
                Text(
                  missing ? 'Servicio sin configurar' : 'Servicio pausado',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3D2E1A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  missing
                      ? 'Esta sucursal aún no tiene una suscripción activa. Contacta a tu proveedor para activarla.'
                      : 'El pago de tu suscripción venció. Para reanudar el servicio, contacta a tu proveedor.',
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF7A6E5A), height: 1.4),
                  textAlign: TextAlign.center,
                ),
                if (info.paidUntil != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Vencido el ${info.paidUntil!.day}/${info.paidUntil!.month}/${info.paidUntil!.year}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA08F70),
                        fontStyle: FontStyle.italic),
                  ),
                ],
                if (info.contactInfo.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFF6D00)
                              .withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.support_agent,
                            color: Color(0xFFFF6D00), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          info.contactInfo,
                          style: const TextStyle(
                              color: Color(0xFFFF6D00),
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    foregroundColor: const Color(0xFFFAF1DE),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
