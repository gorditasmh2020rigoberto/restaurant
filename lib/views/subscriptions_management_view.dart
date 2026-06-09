import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';

/// Panel admin para gestionar las suscripciones (vigencia de pago) por
/// sucursal. Permite ver el estado, renovar por N días o cambiar la
/// fecha exacta.
class SubscriptionsManagementView extends StatefulWidget {
  const SubscriptionsManagementView({super.key});

  @override
  State<SubscriptionsManagementView> createState() =>
      _SubscriptionsManagementViewState();
}

class _SubscriptionsManagementViewState
    extends State<SubscriptionsManagementView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _subs = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final rows = await _supabase
          .from('subscriptions')
          .select()
          .order('branch_name');
      // Asegura que cada sucursal conocida tenga una fila para mostrar
      // (aunque el insert real lo hace el SQL inicial).
      final list = (rows as List).cast<Map<String, dynamic>>();
      final existingBranches = list.map((r) => r['branch_name']).toSet();
      for (final b in Globals.branches) {
        if (!existingBranches.contains(b)) {
          list.add({
            'branch_name': b,
            'paid_until': null,
            'contact_info': '',
            'notes': null,
            '__missing': true,
          });
        }
      }
      list.sort((a, b) =>
          (a['branch_name'] as String).compareTo(b['branch_name'] as String));
      if (mounted) setState(() => _subs = list);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg =
            'No se pudo cargar. ¿Ya corriste create_subscriptions_table.sql?\n\n$e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPaidUntil(String branch, DateTime newDate) async {
    final dateStr =
        '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
    try {
      await _supabase.from('subscriptions').upsert(
        {
          'branch_name': branch,
          'paid_until': dateStr,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'branch_name',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$branch pagada hasta $dateStr'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _renewByDays(Map<String, dynamic> sub, int days) async {
    final branch = sub['branch_name'] as String;
    // Si ya está vigente, suma días sobre paid_until; si está vencida,
    // suma desde hoy. Así no se pierden días pagados por adelantado.
    DateTime base;
    final pu = sub['paid_until'] as String?;
    if (pu != null) {
      final paidDate = DateTime.parse(pu);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      base = paidDate.isAfter(todayDate) ? paidDate : todayDate;
    } else {
      base = DateTime.now();
    }
    await _setPaidUntil(branch, base.add(Duration(days: days)));
  }

  Future<void> _pickDate(Map<String, dynamic> sub) async {
    final branch = sub['branch_name'] as String;
    final pu = sub['paid_until'] as String?;
    final initial = pu != null
        ? DateTime.parse(pu)
        : DateTime.now().add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Pagada hasta',
    );
    if (picked != null) {
      await _setPaidUntil(branch, picked);
    }
  }

  ({Color color, String label, IconData icon}) _statusOf(
      Map<String, dynamic> sub) {
    final pu = sub['paid_until'] as String?;
    if (pu == null) {
      return (
        color: const Color(0xFFB7472A),
        label: 'Sin configurar',
        icon: Icons.error_outline,
      );
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final paidDate = DateTime.parse(pu);
    final diff = paidDate.difference(todayDate).inDays;
    if (diff < -3) {
      return (
        color: const Color(0xFFB7472A),
        label: 'Vencida hace ${-diff} día(s)',
        icon: Icons.lock_outline,
      );
    }
    if (diff < 0) {
      return (
        color: const Color(0xFFE07A30),
        label: 'En gracia (vencida hace ${-diff} día(s))',
        icon: Icons.warning_amber_rounded,
      );
    }
    if (diff <= 7) {
      return (
        color: const Color(0xFFE07A30),
        label: 'Vence en $diff día(s)',
        icon: Icons.access_time,
      );
    }
    return (
      color: const Color(0xFF34D399),
      label: 'Vigente ($diff días)',
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF1DE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user,
                      color: Color(0xFFFF6D00), size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    'Vigencia de Pago',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6D00)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFFFF6D00)),
                    tooltip: 'Recargar',
                    onPressed: _load,
                  ),
                ],
              ),
              const Text(
                'Renueva el pago de cada sucursal. Cuando vence se bloquea el acceso (con 3 días de gracia).',
                style: TextStyle(color: Color(0xFFA08F70), fontSize: 13),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFF6D00)),
                      )
                    : _errorMsg != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _errorMsg!,
                                style: const TextStyle(
                                    color: Color(0xFFB7472A), fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _subs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) =>
                                _buildSubCard(_subs[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubCard(Map<String, dynamic> sub) {
    final branch = sub['branch_name'] as String;
    final pu = sub['paid_until'] as String?;
    final status = _statusOf(sub);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF1DE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store, color: Color(0xFFFF6D00), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  branch,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D2E1A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: status.color.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.icon, color: status.color, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      status.label,
                      style: TextStyle(
                          color: status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pu != null
                ? 'Pagada hasta: $pu'
                : 'Sin fecha de pago configurada',
            style: const TextStyle(
                color: Color(0xFF7A6E5A), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickBtn('+ 30 días', () => _renewByDays(sub, 30)),
              _quickBtn('+ 60 días', () => _renewByDays(sub, 60)),
              _quickBtn('+ 90 días', () => _renewByDays(sub, 90)),
              _quickBtn('+ 1 año', () => _renewByDays(sub, 365)),
              _customDateBtn(() => _pickDate(sub)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6D00),
        foregroundColor: const Color(0xFFFAF1DE),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 12),
      ),
      child: Text(label),
    );
  }

  Widget _customDateBtn(VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today, size: 14),
      label: const Text('Fecha exacta'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFF6D00),
        side: const BorderSide(color: Color(0xFFFF6D00), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
