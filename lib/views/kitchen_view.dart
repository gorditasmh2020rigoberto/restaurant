import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';

class KitchenView extends StatefulWidget {
  final bool isTakeoutOnly;
  final bool isDrinksOnly;
  const KitchenView({
    super.key, 
    this.isTakeoutOnly = false,
    this.isDrinksOnly = false,
  });

  @override
  State<KitchenView> createState() => _KitchenViewState();
}

class _KitchenViewState extends State<KitchenView> {
  final _supabase = Supabase.instance.client;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Panel de guisados disponibles ──────────────────────────────────
  void _showGuisadosSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF1DE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          builder: (_, controller) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFFCFC7B2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.soup_kitchen, color: Color(0xFFFF6D00), size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Guisados disponibles hoy',
                        style: TextStyle(
                          color: Color(0xFFFF6D00),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 20, right: 20, bottom: 8),
                  child: Text(
                    'Desactiva los que ya no hay para que no se puedan ordenar.',
                    style: TextStyle(color: Color(0xFFA08F70), fontSize: 12),
                  ),
                ),
                const Divider(color: Color(0xFFE5DCC4)),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('guisados')
                        .stream(primaryKey: ['id'])
                        .order('name', ascending: true),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFF6D00)),
                        );
                      }
                      final guisados = snapshot.data!.where((g) {
                        final branch = g['branch_name'] as String?;
                        return branch == null || branch == Globals.currentBranch;
                      }).toList();

                      if (guisados.isEmpty) {
                        return const Center(
                          child: Text('No hay guisados registrados.',
                              style: TextStyle(color: Color(0xFFA08F70))),
                        );
                      }

                      return ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: guisados.length,
                        itemBuilder: (_, index) {
                          final g = guisados[index];
                          final available = g['available'] as bool? ?? true;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF1DE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: available
                                    ? const Color(0xFFFF6D00).withOpacity(0.15)
                                    : const Color(0xFFE5DCC4),
                                child: Icon(
                                  Icons.lunch_dining,
                                  color: available
                                      ? const Color(0xFFFF6D00)
                                      : Color(0xFFB6A88A),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                g['name'] as String,
                                style: TextStyle(
                                  color: available ? Color(0xFFFAF1DE) : Color(0xFFB6A88A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                available ? 'Disponible' : 'No disponible',
                                style: TextStyle(
                                  color: available
                                      ? const Color(0xFF34D399)
                                      : Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Switch(
                                value: available,
                                onChanged: (_) async {
                                  await _supabase
                                      .from('guisados')
                                      .update({'available': !available})
                                      .eq('id', g['id']);
                                },
                                activeColor: const Color(0xFFFF6D00),
                                inactiveThumbColor: Color(0xFFB6A88A),
                                inactiveTrackColor: const Color(0xFFE5DCC4),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      appBar: AppBar(
        leading: screenWidth < 1000 ? Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ) : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isDrinksOnly ? 'Bar de Bebidas' : (widget.isTakeoutOnly ? 'Cocina To Go' : 'Línea de Producción'), 
                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 18 : 22)),
            Text('Sucursal: ${Globals.currentBranch}', style: const TextStyle(fontSize: 12, color: Color(0xFFA08F70))),
          ],
        ),
        actions: [
          // Botón de guisados: visible en Línea de Producción y Cocina (no en Bar)
          if (!widget.isDrinksOnly)
            IconButton(
              icon: const Icon(Icons.soup_kitchen),
              tooltip: 'Guisados disponibles',
              onPressed: () => _showGuisadosSheet(context),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase.from('admin_settings').stream(primaryKey: ['setting_key']).eq('setting_key', 'split_kitchen_mode'),
        builder: (context, settingsSnapshot) {
          // Actualizar valor global en tiempo real si el admin lo cambia
          if (settingsSnapshot.hasData && settingsSnapshot.data!.isNotEmpty) {
            final settingValue = settingsSnapshot.data!.first['setting_value'];
            Globals.splitKitchenMode = settingValue == 'true';
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('orders')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: true),
            builder: (context, orderSnapshot) {
              if (orderSnapshot.hasError) {
                return Center(child: Text('Error: ${orderSnapshot.error}'));
              }
              if (!orderSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filtrado de órdenes según modo de cocina
              final orders = orderSnapshot.data!.where((o) {
                final isPending = o['status'] == 'pending';
                final isBranch = o['branch_name'] == Globals.currentBranch;
                final type = o['order_type'] ?? 'dine_in';
                
                if (widget.isDrinksOnly) {
                  // Bar: shows all pending orders that have drinks (filtering done in _OrderTicket)
                  return isPending && isBranch;
                }

                if (widget.isTakeoutOnly) {
                  // Vista especializada: Solo To Go / Delivery
                  return isPending && isBranch && (type == 'takeout' || type == 'delivery');
                } else {
                  // Línea de Producción:
                  if (Globals.splitKitchenMode) {
                    // Modo Dividido: Solo Comensales (Mesa)
                    return isPending && isBranch && type == 'dine_in';
                  } else {
                    // Modo Unificado: TODO (To Go y Dine-In)
                    return isPending && isBranch;
                  }
                }
              }).toList();

              if (orders.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 100, color: Colors.green),
                      SizedBox(height: 16),
                      Text('No hay órdenes pendientes', style: TextStyle(fontSize: 24, color: Colors.grey)),
                    ],
                  ),
                );
              }

              final screenWidth = MediaQuery.of(context).size.width;
              final isMobile = screenWidth < 800;
              
              return GridView.builder(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: isMobile ? screenWidth : 450,
                  crossAxisSpacing: isMobile ? 8 : 16,
                  mainAxisSpacing: isMobile ? 8 : 16,
                  childAspectRatio: isMobile ? 1.0 : 0.75,
                ),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _OrderTicket(order: order, isDrinksOnly: widget.isDrinksOnly);
                },
              );
            },
          );
        },
      ),
      drawer: screenWidth < 1000 ? _buildSidebar(context) : null,
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFAF1DE),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFFAF1DE)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.restaurant, color: Color(0xFFFF6D00), size: 40),
                const SizedBox(height: 12),
                Text(
                  widget.isDrinksOnly ? 'Bar' : (widget.isTakeoutOnly ? 'Cocina To Go' : 'Cocina'),
                  style: const TextStyle(color: Color(0xFF3D2E1A), fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(Globals.currentBranch, style: const TextStyle(color: Color(0xFF7A6E5A))),
              ],
            ),
          ),
          _sidebarItem(context, Icons.kitchen, 'Línea de Producción', widget.isDrinksOnly == false && widget.isTakeoutOnly == false),
          _sidebarItem(context, Icons.local_bar, 'Bar de Bebidas', widget.isDrinksOnly),
          _sidebarItem(context, Icons.takeout_dining, 'Cocina To Go / Uber', widget.isTakeoutOnly),
          const Divider(color: Color(0xFFE5DCC4)),
          ListTile(
            leading: const Icon(Icons.arrow_back, color: Color(0xFFA08F70)),
            title: const Text('Volver al Menú Principal', style: TextStyle(color: Color(0xFF7A6E5A))),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(BuildContext context, IconData icon, String title, bool isSelected) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFFFF6D00) : Color(0xFFA08F70)),
      title: Text(title, style: TextStyle(color: isSelected ? Color(0xFFFAF1DE) : Color(0xFF7A6E5A), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedTileColor: const Color(0xFFFF6D00).withValues(alpha: 0.1),
      onTap: () {
        // Here you would navigate or update state
        Navigator.pop(context);
        if (title.contains('Bebidas')) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const KitchenView(isDrinksOnly: true)));
        } else if (title.contains('Llevar')) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const KitchenView(isTakeoutOnly: true)));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const KitchenView()));
        }
      },
    );
  }
}

class _OrderTicket extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool isDrinksOnly;

  const _OrderTicket({required this.order, this.isDrinksOnly = false});

  @override
  State<_OrderTicket> createState() => _OrderTicketState();
}

class _OrderTicketState extends State<_OrderTicket> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>>? _items;
  String? _tableNumber;
  String _orderTypeStr = '...';
  String? _customerName;
  String _deliveryAddress = '';
  String _deliveryPhone = '';
  String? _waiterName;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  bool _stationDone = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateElapsed();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateElapsed();
        });
      }
    });
  }

  void _updateElapsed() {
    if (widget.order['created_at'] != null) {
      try {
        final created = DateTime.parse(widget.order['created_at']).toLocal();
        _elapsed = DateTime.now().difference(created);
      } catch (_) {
        _elapsed = Duration.zero;
      }
    }
  }

  int get _maxAllowedMinutes {
    if (_items == null || _items!.isEmpty) return 15;
    int maxT = 0;
    for (var item in _items!) {
      final dish = item['dishes'] as Map<String, dynamic>?;
      final dynamic tRaw = dish?['max_time'];
      final int t = (tRaw is int) ? tRaw : (tRaw is num ? tRaw.toInt() : 15);
      if (t > maxT) maxT = t;
    }
    return maxT == 0 ? 15 : maxT;
  }

  String get _formattedElapsed {
    if (_elapsed.isNegative) return '00:00';
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remainingMins.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final orderId = widget.order['id'];
    final orderType = widget.order['order_type'] ?? 'dine_in';
    _customerName = widget.order['customer_name'];

    // Para órdenes de delivery, extraer la dirección y el teléfono del
    // customer_name (formato: "Nombre (Pago: X) - DIR: ... - TEL: ...").
    if (orderType == 'delivery' && _customerName != null) {
      final dirMatch = RegExp(r'-\s*DIR:\s*([^-]+?)(?:\s*-\s*TEL:|$)')
          .firstMatch(_customerName!);
      final telMatch = RegExp(r'-\s*TEL:\s*(.+?)(?:\s*-\s*|$)')
          .firstMatch(_customerName!);
      _deliveryAddress = dirMatch?.group(1)?.trim() ?? '';
      _deliveryPhone = telMatch?.group(1)?.trim() ?? '';
      // Limpiar el nombre visible: quitar la cola "- DIR: ... - TEL: ..." para
      // que en el encabezado se vea sólo "Nombre (Pago: X)".
      _customerName = _customerName!
          .replaceAll(RegExp(r'\s*-\s*DIR:.*'), '')
          .trim();
    }
    
    // Load table number asynchronously if dine_in
    if (orderType == 'dine_in' && widget.order['table_id'] != null) {
      supabase.from('restaurant_tables').select('table_number').eq('id', widget.order['table_id'] as Object).single().then((value) {
        if (mounted) {
          setState(() {
            _tableNumber = value['table_number'].toString();
            _orderTypeStr = 'Mesa $_tableNumber';
          });
        }
      }).catchError((_) {});
    } else {
      if (mounted) {
        setState(() {
          _orderTypeStr = orderType == 'takeout' ? 'To Go' : 'Delivery';
        });
      }
    }

    // Load waiter name asynchronously
    if (widget.order['waiter_id'] != null) {
      supabase.from('waiters').select('name').eq('id', widget.order['waiter_id']).single().then((value) {
        if (mounted) setState(() => _waiterName = value['name'].toString());
      }).catchError((_) {});
    }

    // Load items
    try {
      final response = await supabase.from('order_items').select('''
        id, quantity, status, price_at_time, guisados_selected, client_label,
        dishes (name, category, max_time)
      ''').eq('order_id', orderId).order('id');
      
      if (mounted) {
        var itemsList = List<Map<String, dynamic>>.from(response);
        
        // Clasificar bebidas según la categoría del platillo
        bool isDrink(Map<String, dynamic> item) {
          final dish = item['dishes'] as Map<String, dynamic>?;
          final category = dish?['category']?.toString().toLowerCase().trim() ?? '';
          const drinkCategories = ['drink', 'alcohol', 'bebidas', 'drinks'];
          return drinkCategories.contains(category);
        }

        if (widget.isDrinksOnly) {
          // Bar: Solo bebidas
          itemsList = itemsList.where(isDrink).toList();
        } else {
          // Cocina: Excluye bebidas
          itemsList = itemsList.where((item) => !isDrink(item)).toList();
        }

        setState(() {
          _items = itemsList;
        });
      }
    } catch (e) {
      debugPrint('Error loading items: $e');
      if (mounted) {
        setState(() {
          _items = []; // Para detener el spinner
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando pedido: Verifica que la columna "max_time" exista en "dishes". Error detallado: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          )
        );
      }
    }
  }

  void _toggleItemStatus(int index, bool currentIsReady) async {
    if (_items == null) return;
    
    final item = _items![index];
    final newStatus = currentIsReady ? 'pending' : 'ready';
    
    // Optimistic update for instant UI feedback
    setState(() {
      _items![index]['status'] = newStatus;
    });

    try {
      await supabase
          .from('order_items')
          .update({'status': newStatus})
          .eq('id', item['id']);
    } catch (e) {
      // Revert if error
      if (mounted) {
        setState(() {
          _items![index]['status'] = currentIsReady ? 'ready' : 'pending';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar estado')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stationDone) return const SizedBox.shrink();
    // Si estamos en modo bebidas y este pedido no tiene bebidas cargadas, ocultamos el ticket
    if (widget.isDrinksOnly && _items != null && _items!.isEmpty) {
      return const SizedBox.shrink();
    }

    final orderId = widget.order['id'];
    final bool isOverTime = _elapsed.inMinutes >= _maxAllowedMinutes;
    final Color warningColor = _elapsed.inSeconds % 2 == 0 ? Colors.red : Colors.orange;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isOverTime ? warningColor.withValues(alpha: 0.15) : const Color(0xFFFAF1DE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverTime ? warningColor : Colors.transparent,
          width: isOverTime ? 5 : 4, // Keep width fixed approx to avoid layout shifts
        ),
        boxShadow: isOverTime ? [
          BoxShadow(
            color: warningColor.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 8,
          )
        ] : [
          const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFFFF6D00), width: 6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URGENT Banner
            if (isOverTime)
              Container(
                color: warningColor,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Text(
                  '¡URGENTE! TIEMPO EXCEDIDO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFAF1DE),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    fontSize: 14,
                  ),
                ),
              ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _orderTypeStr,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF6D00)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Folio #${widget.order['daily_folio'] ?? '---'}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6D00)),
                            ),
                            const Text(' • ', style: TextStyle(color: Color(0xFFA08F70))),
                            Text(
                              widget.order['created_at'] != null 
                                ? widget.order['created_at'].toString().substring(0, 10).split('-').reversed.join('/')
                                : '',
                              style: const TextStyle(fontSize: 14, color: Color(0xFFA08F70)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Servidor: ${_waiterName ?? 'Caja'}${_customerName != null && _customerName!.isNotEmpty ? ' • $_customerName' : ''}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFFA08F70)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Datos de entrega visibles cuando es delivery, para
                        // que cocina/línea pueda pedir transporte (Uber, etc.).
                        if ((widget.order['order_type'] ?? '') == 'delivery')
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6D00).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFF6D00),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.delivery_dining,
                                          size: 18, color: Color(0xFFFF6D00)),
                                      SizedBox(width: 6),
                                      Text('ENTREGA A DOMICILIO',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                            color: Color(0xFFFF6D00),
                                          )),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_deliveryAddress.isNotEmpty)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 16, color: Color(0xFFFF6D00)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: SelectableText(
                                            _deliveryAddress,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFFFF6D00),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (_deliveryPhone.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone,
                                            size: 16, color: Color(0xFFFF6D00)),
                                        const SizedBox(width: 6),
                                        SelectableText(
                                          _deliveryPhone,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFFFF6D00),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Timer Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOverTime ? warningColor : const Color(0xFFFF6D00).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isOverTime ? [
                        BoxShadow(color: warningColor.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)
                      ] : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isOverTime ? Icons.warning_amber_rounded : Icons.schedule, 
                             color: isOverTime ? Color(0xFFFAF1DE) : const Color(0xFFFF6D00), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _formattedElapsed,
                          style: TextStyle(
                            color: isOverTime ? Color(0xFFFAF1DE) : const Color(0xFFFF6D00),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Color(0xFFE5DCC4), height: 1, thickness: 1),
          
            // Items list
            Expanded(
              child: _items == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items!.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _items![index];
                        final dishName = item['dishes']['name'] as String;
                        final isReady = item['status'] == 'ready';

                        // Parse guisados_selected JSON
                        List<String> extras = [];
                        final raw = item['guisados_selected'];
                        if (raw != null && raw.toString().isNotEmpty) {
                          try {
                            extras = (jsonDecode(raw.toString()) as List).cast<String>();
                          } catch (_) {}
                        }

                        final clientLabel = item['client_label'] as String? ?? 'Cliente 1';
                        final extrasText = extras.isNotEmpty ? extras.join(' • ') : null;

                        // Always show client label; additionally show extras in kitchen
                        final String subtitleLine1 = clientLabel;
                        final String? subtitleLine2 = !widget.isDrinksOnly ? extrasText : null;

                        return InkWell(
                          onTap: () => _toggleItemStatus(index, isReady),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item['quantity']}x ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isReady ? Colors.green : Color(0xFFFAF1DE),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dishName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: isReady ? Colors.grey : Color(0xFFFAF1DE),
                                          decoration: isReady ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      // Client label (always shown)
                                      Text(
                                        subtitleLine1,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isReady
                                              ? Colors.grey
                                              : (widget.isDrinksOnly
                                                  ? const Color(0xFF38BDF8)
                                                  : const Color(0xFFFF6D00)),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      // Guisados (kitchen only)
                                      if (subtitleLine2 != null)
                                        Text(
                                          subtitleLine2,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isReady ? Colors.grey : Color(0xFFA08F70),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: isReady,
                                  activeColor: Colors.green,
                                  onChanged: (bool? value) => _toggleItemStatus(index, isReady),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

          // Action button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Builder(
              builder: (context) {
                final bool isAllStationReady = _items?.every((item) => item['status'] == 'ready') ?? false;

                return ElevatedButton.icon(
                  onPressed: () async {
                    if (_items == null) return;

                    if (!isAllStationReady) {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFFFAF1DE),
                          title: const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('¿Orden Incompleta?', style: TextStyle(color: Color(0xFF3D2E1A))),
                            ],
                          ),
                          content: const Text(
                            'Faltan platillos por marcar como listos.\n\nSi continúas, le avisaremos al mesero que faltan platillos (agotados).',
                            style: TextStyle(color: Color(0xFF7A6E5A)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              child: const Text('Avisar Platillo Agotado', style: TextStyle(color: Color(0xFF3D2E1A))),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true) return;
                    }

                    try {
                      // 1. Mark this station's items as ready or cancel pending ones
                      if (!isAllStationReady) {
                        num amountToDeduct = 0;
                        List<String> cancelledIds = [];
                        List<String> readyIds = [];

                        for (var item in _items!) {
                          if (item['status'] == 'pending') {
                            cancelledIds.add(item['id'].toString());
                            num qty = item['quantity'] as num;
                            num p = item['price_at_time'] as num;
                            amountToDeduct += (qty * p);
                          } else if (item['status'] == 'ready') {
                            readyIds.add(item['id'].toString());
                          }
                        }

                        if (cancelledIds.isNotEmpty) {
                          await supabase.from('order_items').update({'status': 'cancelled'}).inFilter('id', cancelledIds);
                        }

                        if (amountToDeduct > 0) {
                          final orderRes = await supabase.from('orders').select('total_amount').eq('id', orderId).single();
                          num currentTotal = orderRes['total_amount'] as num;
                          num newTotal = currentTotal - amountToDeduct;
                          if (newTotal < 0) newTotal = 0;
                          await supabase.from('orders').update({'total_amount': newTotal}).eq('id', orderId);
                        }
                      } else {
                        // Ensure all station items are marked ready
                        final stationIds = _items!.map((i) => i['id'].toString()).toList();
                        await supabase.from('order_items').update({'status': 'ready'}).inFilter('id', stationIds);
                      }

                      // 2. Check if ALL order_items (across both stations) are now done
                      final allItems = await supabase.from('order_items').select('status').eq('order_id', orderId);
                      final allItemsList = (allItems as List).cast<Map<String, dynamic>>();
                      final allDone = allItemsList.every((i) {
                        final s = i['status']?.toString() ?? 'pending';
                        return s == 'ready' || s == 'cancelled';
                      });

                      // 3. Update station-ready flag and optionally close the whole order
                      if (widget.isDrinksOnly) {
                        await supabase.from('orders').update({'drinks_ready': true}).eq('id', orderId);
                      } else {
                        await supabase.from('orders').update({'food_ready': true}).eq('id', orderId);
                      }

                      if (allDone) {
                        final anyIncomplete = allItemsList.any((i) => i['status'] == 'cancelled');
                        await supabase.from('orders').update({'status': anyIncomplete ? 'incomplete' : 'ready'}).eq('id', orderId);
                      }

                      // 4. Hide this station's ticket locally
                      if (mounted) setState(() => _stationDone = true);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isAllStationReady
                            ? 'Comanda de ${widget.isDrinksOnly ? "bebidas" : "cocina"} lista'
                            : 'Aviso enviado. Productos agotados descontados del total.')),
                      );
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                  icon: Icon(isAllStationReady ? Icons.done_all : Icons.warning_amber),
                  label: Text(isAllStationReady ? 'Comanda Lista' : 'Avisar Agotado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAllStationReady ? Colors.green : const Color(0xFFFF6D00),
                    foregroundColor: Color(0xFFFAF1DE),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                );
              }
            ),
          )
        ],
      ),
      ),
    );
  }
}
