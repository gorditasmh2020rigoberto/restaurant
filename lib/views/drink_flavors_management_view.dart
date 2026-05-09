import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DrinkFlavorsManagementView extends StatefulWidget {
  const DrinkFlavorsManagementView({super.key});

  @override
  State<DrinkFlavorsManagementView> createState() => _DrinkFlavorsManagementViewState();
}

class _DrinkFlavorsManagementViewState extends State<DrinkFlavorsManagementView>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _refrescos = [];
  List<Map<String, dynamic>> _aguas = [];
  List<Map<String, dynamic>> _jugos = [];
  bool _loading = true;
  final Map<String, double> _jugoPrices = {};
  final Map<String, double> _refrescoPrices = {};
  final Map<String, double> _aguaPrices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchFlavors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFlavors() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('drink_flavors')
          .select()
          .order('name', ascending: true);
      final list = (data as List<dynamic>).cast<Map<String, dynamic>>();

      try {
        final priceRows = await _supabase
            .from('drink_type_prices')
            .select()
            .order('type');
        final jugoP = <String, double>{};
        final refrescoP = <String, double>{};
        final aguaP = <String, double>{};
        for (final r in (priceRows as List)) {
          final t = r['type'] as String;
          final p = (r['price'] as num).toDouble();
          if (t.startsWith('jugo')) jugoP[t] = p;
          else if (t.startsWith('refresco')) refrescoP[t] = p;
          else if (t.startsWith('agua')) aguaP[t] = p;
        }
        if (mounted) {
          setState(() {
            _jugoPrices..clear()..addAll(jugoP);
            _refrescoPrices..clear()..addAll(refrescoP);
            _aguaPrices..clear()..addAll(aguaP);
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _refrescos = list
              .where((f) =>
                  f['type'] == 'refresco' ||
                  f['type'] == 'refresco_255' ||
                  f['type'] == 'refresco_600')
              .toList();
          _aguas = list.where((f) =>
              f['type'] == 'agua_fresca' ||
              f['type'] == 'agua_600' ||
              f['type'] == 'agua_1litro').toList();
          _jugos = list
              .where((f) =>
                  f['type'] == 'jugo' ||
                  f['type'] == 'jugo_330' ||
                  f['type'] == 'jugo_1litro')
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar: $e')),
        );
      }
    }
  }

  Future<void> _toggleAvailable(Map<String, dynamic> flavor) async {
    final newValue = !(flavor['available'] as bool? ?? true);
    _updateLocal(flavor['type'] as String, flavor['id'], {'available': newValue});
    try {
      await _supabase
          .from('drink_flavors')
          .update({'available': newValue})
          .eq('id', flavor['id']);
    } catch (e) {
      _updateLocal(flavor['type'] as String, flavor['id'], {'available': !newValue});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _updateLocal(String type, dynamic id, Map<String, dynamic> changes) {
    setState(() {
      final list = _listForType(type);
      final index = list.indexWhere((f) => f['id'] == id);
      if (index != -1) list[index] = {...list[index], ...changes};
    });
  }

  List<Map<String, dynamic>> _listForType(String type) {
    if (type == 'agua_fresca' || type == 'agua_600' || type == 'agua_1litro') return _aguas;
    if (type == 'jugo' || type == 'jugo_330' || type == 'jugo_1litro') return _jugos;
    return _refrescos;
  }

  String _subtypeLabel(String type) {
    switch (type) {
      case 'refresco_255': return '355 ml';
      case 'refresco_600': return '600 ml';
      case 'jugo_330':     return '330 ml';
      case 'jugo_1litro':  return '1 litro';
      case 'agua_600':     return '600 ml';
      case 'agua_1litro':  return '1 litro';
      default:             return '';
    }
  }

  Color _subtypeColor(String type) {
    switch (type) {
      case 'refresco_255': return const Color(0xFF38BDF8);
      case 'refresco_600': return const Color(0xFFA78BFA);
      case 'jugo_330':     return const Color(0xFF4ADE80);
      case 'jugo_1litro':  return const Color(0xFFFBBF24);
      case 'agua_600':     return const Color(0xFF67E8F9);
      case 'agua_1litro':  return const Color(0xFF6EE7B7);
      default:             return const Color(0xFF94A3B8);
    }
  }

  Future<void> _deleteFlavor(Map<String, dynamic> flavor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Eliminar sabor?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.2)),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final type = flavor['type'] as String;
    final id = flavor['id'];
    setState(() {
      _listForType(type).removeWhere((f) => f['id'] == id);
    });
    try {
      await _supabase.from('drink_flavors').delete().eq('id', id);
    } catch (e) {
      _fetchFlavors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Future<void> _showFlavorDialog({Map<String, dynamic>? flavor, required String type}) async {
    final isEditing = flavor != null;
    final nameController = TextEditingController(text: isEditing ? flavor['name'] as String : '');

    // Map any size-specific type to its parent category
    final rawType = isEditing ? (flavor['type'] as String? ?? type) : type;
    String selectedCategory;
    if (rawType.startsWith('agua')) {
      selectedCategory = 'agua_fresca';
    } else if (rawType.startsWith('jugo')) {
      selectedCategory = 'jugo';
    } else {
      selectedCategory = 'refresco';
    }

    const typeOptions = [
      ('refresco',   'Refresco',     Icons.local_drink),
      ('agua_fresca','Agua Fresca',  Icons.water_drop),
      ('jugo',       'Jugo',         Icons.blender),
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            isEditing ? 'Editar sabor' : 'Nuevo sabor',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setDlgState(() {}),
                decoration: InputDecoration(
                  hintText: selectedCategory == 'agua_fresca'
                      ? 'Ej. Jamaica, Horchata...'
                      : selectedCategory == 'jugo'
                          ? 'Ej. Naranja, Verde...'
                          : 'Ej. Coca-Cola, Sprite...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF6D00))),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF6D00), width: 2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Categoría',
                  style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              ...typeOptions.map((opt) {
                final isSelected = selectedCategory == opt.$1;
                return GestureDetector(
                  onTap: () => setDlgState(() => selectedCategory = opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF6D00).withValues(alpha: 0.15)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFF6D00) : const Color(0xFF334155),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18,
                          color: isSelected ? const Color(0xFFFF6D00) : Colors.white38,
                        ),
                        const SizedBox(width: 10),
                        Icon(opt.$3, size: 16,
                            color: isSelected ? const Color(0xFFFF6D00) : Colors.white38),
                        const SizedBox(width: 8),
                        Text(
                          opt.$2,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: nameController.text.trim().isNotEmpty
                  ? () async {
                      final name = nameController.text.trim();
                      Navigator.pop(ctx);
                      try {
                        if (isEditing) {
                          final oldType = flavor['type'] as String;
                          await _supabase
                              .from('drink_flavors')
                              .update({'name': name, 'type': selectedCategory})
                              .eq('id', flavor['id']);
                          if (oldType != selectedCategory) {
                            _fetchFlavors();
                          } else {
                            _updateLocal(selectedCategory, flavor['id'],
                                {'name': name, 'type': selectedCategory});
                          }
                        } else {
                          final result = await _supabase.from('drink_flavors').insert({
                            'name': name,
                            'type': selectedCategory,
                            'available': true,
                          }).select().single();
                          setState(() {
                            final list = _listForType(selectedCategory);
                            list.add(result);
                            list.sort((a, b) =>
                                (a['name'] as String).compareTo(b['name'] as String));
                          });
                        }
                      } catch (e) {
                        _fetchFlavors();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    }
                  : null,
              style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6D00).withValues(alpha: 0.15)),
              child: Text(isEditing ? 'Guardar' : 'Agregar',
                  style: const TextStyle(color: Color(0xFFFF6D00))),
            ),
          ],
        ),
      ),
    );
  }

  String _sizeLabel(String type) {
    const labels = {
      'refresco_355': '355 ml', 'refresco_600': '600 ml',
      'agua_600': '600 ml',    'agua_1litro': '1 litro',
      'jugo_330': '330 ml',    'jugo_1litro': '1 litro',
    };
    return labels[type] ?? type;
  }

  Color _colorForType(String type) {
    const colors = {
      'refresco_355': Color(0xFF38BDF8), 'refresco_600': Color(0xFFA78BFA),
      'agua_600': Color(0xFF67E8F9),     'agua_1litro': Color(0xFF6EE7B7),
      'jugo_330': Color(0xFF4ADE80),     'jugo_1litro': Color(0xFFFBBF24),
    };
    if (type.startsWith('refresco')) return colors[type] ?? const Color(0xFF38BDF8);
    if (type.startsWith('agua'))    return colors[type] ?? const Color(0xFF67E8F9);
    return colors[type] ?? const Color(0xFF4ADE80);
  }

  Future<void> _deletePriceEntry(String type, Map<String, double> prices) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Eliminar tamaño?', style: TextStyle(color: Colors.white)),
        content: Text('Se eliminará el precio para "$type".', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.2)),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _supabase.from('drink_type_prices').delete().eq('type', type);
      setState(() => prices.remove(type));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showAddSizeDialog() async {
    String category = 'refresco';
    final labelCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    const categoryOptions = [
      ('refresco',    'Refresco',    Icons.local_drink),
      ('agua',        'Agua Fresca', Icons.water_drop),
      ('jugo',        'Jugo',        Icons.blender),
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Nuevo tamaño', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Categoría', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              ...categoryOptions.map((opt) {
                final isSelected = category == opt.$1;
                return GestureDetector(
                  onTap: () => setDlgState(() => category = opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF6D00).withValues(alpha: 0.15) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFF6D00) : const Color(0xFF334155),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 18, color: isSelected ? const Color(0xFFFF6D00) : Colors.white38),
                        const SizedBox(width: 10),
                        Icon(opt.$3, size: 16, color: isSelected ? const Color(0xFFFF6D00) : Colors.white38),
                        const SizedBox(width: 8),
                        Text(opt.$2, style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        )),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: labelCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Tamaño',
                        labelStyle: TextStyle(color: Colors.white54),
                        hintText: 'Ej. 500 ml',
                        hintStyle: TextStyle(color: Colors.white38),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00), width: 2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Precio',
                        labelStyle: TextStyle(color: Colors.white54),
                        prefixText: '\$',
                        prefixStyle: TextStyle(color: Color(0xFFFF6D00)),
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.white38),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00), width: 2)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text);
                if (label.isEmpty || price == null) return;
                final sanitized = label.toLowerCase().replaceAll(' ', '').replaceAll('.', '');
                final type = '${category}_$sanitized';
                Navigator.pop(ctx);
                try {
                  await _supabase.from('drink_type_prices').upsert(
                    {'type': type, 'price': price}, onConflict: 'type');
                  final map = category == 'refresco' ? _refrescoPrices
                      : category == 'agua' ? _aguaPrices
                      : _jugoPrices;
                  setState(() => map[type] = price);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: TextButton.styleFrom(backgroundColor: const Color(0xFFFF6D00).withValues(alpha: 0.15)),
              child: const Text('Agregar', style: TextStyle(color: Color(0xFFFF6D00))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPriceDialog({
    required String type,
    required String label,
    required Color color,
    required Map<String, double> prices,
  }) async {
    final ctrl = TextEditingController(text: prices[type]?.toStringAsFixed(0) ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Precio $label', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            prefixText: '\$',
            prefixStyle: TextStyle(color: color),
            hintText: '0',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: color, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final p = double.tryParse(ctrl.text);
              if (p == null) return;
              Navigator.pop(ctx);
              try {
                await _supabase.from('drink_type_prices').upsert(
                  {'type': type, 'price': p},
                  onConflict: 'type',
                );
                setState(() => prices[type] = p);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF6D00).withValues(alpha: 0.15)),
            child: const Text('Guardar', style: TextStyle(color: Color(0xFFFF6D00))),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow({
    required String type,
    required Map<String, double> prices,
  }) {
    final price = prices[type];
    final label = _sizeLabel(type);
    final color = _colorForType(type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          Text(
            price != null ? '\$${price.toStringAsFixed(0)}' : 'Sin precio',
            style: TextStyle(
              color: price != null ? Colors.white : Colors.white38,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
            onPressed: () =>
                _showPriceDialog(type: type, label: label, color: color, prices: prices),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () => _deletePriceEntry(type, prices),
          ),
        ],
      ),
    );
  }

  Widget _buildPricesSection(String title, Map<String, double> prices) {
    if (prices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        ...prices.keys.map((type) => _buildPriceRow(type: type, prices: prices)),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF334155)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPricesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
      children: [
        _buildPricesSection('Refrescos', _refrescoPrices),
        _buildPricesSection('Aguas Frescas', _aguaPrices),
        _buildPricesSection('Jugos', _jugoPrices),
        if (_refrescoPrices.isEmpty && _aguaPrices.isEmpty && _jugoPrices.isEmpty)
          const Center(
            child: Text('Sin precios configurados.\nPresiona + para agregar un tamaño.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
          ),
      ],
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String tabType) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00)));
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No hay sabores registrados.\nPresiona + para agregar uno.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155)),
      itemBuilder: (context, index) {
        final f = items[index];
        final available = f['available'] as bool? ?? true;
        final ftype = f['type'] as String;
        final sizeLabel = _subtypeLabel(ftype);
        final icon = ftype.startsWith('agua')
            ? Icons.water_drop
            : ftype.startsWith('jugo')
                ? Icons.blender
                : Icons.local_drink;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: available
                  ? const Color(0xFFFF6D00).withValues(alpha: 0.15)
                  : const Color(0xFF334155),
              child: Icon(
                icon,
                color: available ? const Color(0xFFFF6D00) : Colors.white38,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    f['name'] as String,
                    style: TextStyle(
                      color: available ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (sizeLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _subtypeColor(ftype).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _subtypeColor(ftype).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      sizeLabel,
                      style: TextStyle(
                        color: _subtypeColor(ftype),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              available ? 'Disponible' : 'No disponible',
              style: TextStyle(
                color: available ? const Color(0xFF34D399) : Colors.redAccent,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: available,
                  onChanged: (_) => _toggleAvailable(f),
                  activeColor: const Color(0xFFFF6D00),
                  inactiveThumbColor: Colors.white38,
                  inactiveTrackColor: const Color(0xFF334155),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                  onPressed: () => _showFlavorDialog(flavor: f, type: ftype),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _deleteFlavor(f),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const tabTypes = ['refresco', 'agua_fresca', 'jugo', 'precios'];
    final currentType = tabTypes[_tabController.index];
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: FloatingActionButton(
        onPressed: _tabController.index == 3
            ? _showAddSizeDialog
            : () => _showFlavorDialog(type: currentType),
        backgroundColor: const Color(0xFFFF6D00),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sabores de Bebidas',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                  tooltip: 'Actualizar',
                  onPressed: _fetchFlavors,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Administra los sabores y precios por tamaño para bebidas.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFF6D00),
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF94A3B8),
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(icon: Icon(Icons.local_drink, size: 18), child: Text('Refrescos')),
              Tab(icon: Icon(Icons.water_drop,   size: 18), child: Text('Aguas')),
              Tab(icon: Icon(Icons.blender,      size: 18), child: Text('Jugos')),
              Tab(icon: Icon(Icons.attach_money, size: 18), child: Text('Tamaños')),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(_refrescos, 'refresco'),
                _buildList(_aguas,     'agua_fresca'),
                _buildList(_jugos,     'jugo'),
                _buildPricesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
