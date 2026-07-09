import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';

/// Mismas categorías que cuentan como bebida en kitchen_view.dart y en
/// print-worker/index.js (DRINK_CATEGORIES). Mantenerlas sincronizadas.
const _drinkCategories = [
  'drink', 'alcohol', 'bebidas', 'drinks', 'aguas', 'jugos', 'cafes', 'refrescos',
];

bool _isDrinkCategory(String? category) =>
    _drinkCategories.contains((category ?? '').toLowerCase().trim());

/// Pantalla de solo lectura: para cada orden activa, muestra si ya se
/// imprimió en cada área física (Bebidas, y Cocina o Para Llevar según
/// el tipo de orden) — sin tener que revisar Supabase ni las Raspberries
/// a mano. Se basa en `order_items.printed_at`, que cada Pi marca al
/// imprimir sus items (ver print-worker/index.js).
class PrintStatusView extends StatefulWidget {
  const PrintStatusView({super.key});

  @override
  State<PrintStatusView> createState() => _PrintStatusViewState();
}

class _PrintStatusViewState extends State<PrintStatusView> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Estado de Impresión',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFFFF6D00)),
                tooltip: 'Actualizar',
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 16),
            child: Text(
              'Qué órdenes activas ya se imprimieron en cada área (Bebidas, Cocina/Para Llevar).',
              style: TextStyle(color: Color(0xFFA08F70)),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('restaurant_tables')
                  .stream(primaryKey: ['id'])
                  .eq('branch_name', Globals.currentBranch),
              builder: (context, tablesSnapshot) {
                final tableNumbers = <String, dynamic>{
                  for (final t in (tablesSnapshot.data ?? const []))
                    t['id'] as String: t['table_number'],
                };

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('orders')
                      .stream(primaryKey: ['id'])
                      .inFilter('status', ['pending', 'ready']),
                  builder: (context, orderSnapshot) {
                    if (!orderSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final orders = orderSnapshot.data!
                        .where((o) => o['branch_name'] == Globals.currentBranch)
                        .toList()
                      ..sort((a, b) => (a['created_at'] as String? ?? '')
                          .compareTo(b['created_at'] as String? ?? ''));

                    if (orders.isEmpty) {
                      return const Center(
                        child: Text('No hay órdenes activas.',
                            style: TextStyle(color: Colors.grey)),
                      );
                    }

                    final orderIds = orders.map((o) => o['id'] as String).toList();

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _supabase
                          .from('order_items')
                          .stream(primaryKey: ['id'])
                          .inFilter('order_id', orderIds)
                          .asyncMap((_) async {
                            final rows = await _supabase
                                .from('order_items')
                                .select('id, order_id, printed_at, status, dishes(name, category)')
                                .inFilter('order_id', orderIds);
                            return List<Map<String, dynamic>>.from(rows);
                          }),
                      builder: (context, itemsSnapshot) {
                        if (!itemsSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final allItems = itemsSnapshot.data!;

                        return ListView.separated(
                          itemCount: orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            final items = allItems
                                .where((it) =>
                                    it['order_id'] == order['id'] &&
                                    it['status'] != 'cancelled')
                                .toList();
                            return _OrderPrintCard(
                              order: order,
                              items: items,
                              tableNumbers: tableNumbers,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderPrintCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> tableNumbers;

  const _OrderPrintCard({
    required this.order,
    required this.items,
    required this.tableNumbers,
  });

  @override
  Widget build(BuildContext context) {
    final orderType = (order['order_type'] as String? ?? 'dine_in').toLowerCase();
    final isToGo = orderType == 'takeout' || orderType == 'to_go' || orderType == 'delivery';
    final foodAreaLabel = isToGo ? 'Para Llevar' : 'Cocina';

    final drinkItems = items.where((it) {
      final dish = it['dishes'] as Map<String, dynamic>?;
      return _isDrinkCategory(dish?['category'] as String?);
    }).toList();
    final foodItems = items.where((it) {
      final dish = it['dishes'] as Map<String, dynamic>?;
      return !_isDrinkCategory(dish?['category'] as String?);
    }).toList();

    bool? drinkStatus;
    if (drinkItems.isNotEmpty) {
      drinkStatus = drinkItems.every((it) => it['printed_at'] != null);
    }
    bool? foodStatus;
    if (foodItems.isNotEmpty) {
      foodStatus = foodItems.every((it) => it['printed_at'] != null);
    }

    String title;
    if (order['table_id'] != null) {
      final number = tableNumbers[order['table_id']];
      title = number != null ? 'Mesa $number' : 'Mesa';
    } else {
      final name = (order['customer_name'] as String?)?.trim();
      title = '${isToGo ? (orderType == 'delivery' ? 'Delivery' : 'To Go') : 'Orden'}'
          '${name != null && name.isNotEmpty ? ' — $name' : ''}';
    }
    if (order['daily_folio'] != null) {
      title += ' · Folio #${order['daily_folio']}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF1DE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5DCC4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3D2E1A)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          _PrintStatusChip(label: 'Bebidas', status: drinkStatus),
          const SizedBox(width: 8),
          _PrintStatusChip(label: foodAreaLabel, status: foodStatus),
        ],
      ),
    );
  }
}

/// status == null  → N/A (la orden no tiene items de esa área)
/// status == true   → ya se imprimió todo lo de esa área
/// status == false  → falta imprimir algo de esa área
class _PrintStatusChip extends StatelessWidget {
  final String label;
  final bool? status;

  const _PrintStatusChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String statusText;
    if (status == null) {
      color = const Color(0xFFB6A88A);
      icon = Icons.remove;
      statusText = 'N/A';
    } else if (status == true) {
      color = Colors.green;
      icon = Icons.check_circle;
      statusText = 'Impreso';
    } else {
      color = Colors.orange;
      icon = Icons.hourglass_bottom;
      statusText = 'Pendiente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text('$label: $statusText',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
