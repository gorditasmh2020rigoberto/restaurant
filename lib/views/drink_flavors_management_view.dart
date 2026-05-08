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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      if (mounted) {
        setState(() {
          _refrescos = list
              .where((f) =>
                  f['type'] == 'refresco' ||
                  f['type'] == 'refresco_255' ||
                  f['type'] == 'refresco_600')
              .toList();
          _aguas  = list.where((f) => f['type'] == 'agua_fresca').toList();
          _jugos  = list.where((f) => f['type'] == 'jugo').toList();
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
    if (type == 'agua_fresca') return _aguas;
    if (type == 'jugo') return _jugos;
    return _refrescos;
  }

  String _subtypeLabel(String type) {
    switch (type) {
      case 'refresco_255': return '255 ml';
      case 'refresco_600': return '600 ml';
      default:             return 'Genérico';
    }
  }

  Color _subtypeColor(String type) {
    switch (type) {
      case 'refresco_255': return const Color(0xFF38BDF8);
      case 'refresco_600': return const Color(0xFFA78BFA);
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
            style: TextButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2)),
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
    final initialType = isEditing ? (flavor['type'] as String? ?? type) : type;

    // Refrescos usan checkboxes (multi); agua/jugo usan radio (único)
    final Set<String> selectedRefrescoSizes = {};
    String? selectedNonRefresco;

    const refrescoTypes = ['refresco_255', 'refresco_600'];
    if (refrescoTypes.contains(initialType)) {
      selectedRefrescoSizes.add(initialType);
      // Si estamos editando, buscar si ya existe el otro tamaño con el mismo nombre
      if (isEditing) {
        try {
          final rows = await _supabase
              .from('drink_flavors')
              .select()
              .inFilter('type', refrescoTypes)
              .eq('name', flavor['name'] as String);
          for (final r in (rows as List)) {
            selectedRefrescoSizes.add(r['type'] as String);
          }
        } catch (_) {}
      }
    } else {
      selectedNonRefresco = initialType;
    }

    Widget _optionTile({
      required String key,
      required String label,
      required bool isSelected,
      required bool isCheckbox,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF6D00).withOpacity(0.15) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF6D00) : const Color(0xFF334155),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isCheckbox
                    ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                    : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                size: 18,
                color: isSelected ? const Color(0xFFFF6D00) : Colors.white38,
              ),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              )),
            ],
          ),
        ),
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final hintText = selectedNonRefresco == 'agua_fresca'
              ? 'Ej. Jamaica, Horchata...'
              : 'Ej. Coca-Cola, Sprite...';
          final canSave = nameController.text.trim().isNotEmpty &&
              (selectedRefrescoSizes.isNotEmpty || selectedNonRefresco != null);

          return AlertDialog(
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
                    hintText: hintText,
                    hintStyle: const TextStyle(color: Colors.white38),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00), width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Subgrupo', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 8),
                // Refrescos — checkboxes (se pueden seleccionar ambos)
                _optionTile(
                  key: 'refresco_255',
                  label: 'Refresco 255 ml',
                  isSelected: selectedRefrescoSizes.contains('refresco_255'),
                  isCheckbox: true,
                  onTap: () => setDlgState(() {
                    selectedNonRefresco = null;
                    if (selectedRefrescoSizes.contains('refresco_255')) {
                      selectedRefrescoSizes.remove('refresco_255');
                    } else {
                      selectedRefrescoSizes.add('refresco_255');
                    }
                  }),
                ),
                _optionTile(
                  key: 'refresco_600',
                  label: 'Refresco 600 ml',
                  isSelected: selectedRefrescoSizes.contains('refresco_600'),
                  isCheckbox: true,
                  onTap: () => setDlgState(() {
                    selectedNonRefresco = null;
                    if (selectedRefrescoSizes.contains('refresco_600')) {
                      selectedRefrescoSizes.remove('refresco_600');
                    } else {
                      selectedRefrescoSizes.add('refresco_600');
                    }
                  }),
                ),
                // Agua Fresca y Jugo — radio (excluyente)
                _optionTile(
                  key: 'agua_fresca',
                  label: 'Agua Fresca',
                  isSelected: selectedNonRefresco == 'agua_fresca',
                  isCheckbox: false,
                  onTap: () => setDlgState(() {
                    selectedRefrescoSizes.clear();
                    selectedNonRefresco = 'agua_fresca';
                  }),
                ),
                _optionTile(
                  key: 'jugo',
                  label: 'Jugo',
                  isSelected: selectedNonRefresco == 'jugo',
                  isCheckbox: false,
                  onTap: () => setDlgState(() {
                    selectedRefrescoSizes.clear();
                    selectedNonRefresco = 'jugo';
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: canSave ? () async {
                  final name = nameController.text.trim();
                  Navigator.pop(ctx);
                  try {
                    if (selectedNonRefresco != null) {
                      // Agua Fresca o Jugo — una sola fila
                      if (isEditing) {
                        await _supabase.from('drink_flavors')
                            .update({'name': name, 'type': selectedNonRefresco})
                            .eq('id', flavor['id']);
                      } else {
                        await _supabase.from('drink_flavors').insert({
                          'name': name,
                          'type': selectedNonRefresco,
                          'available': true,
                        });
                      }
                    } else {
                      // Refrescos — una fila por tamaño seleccionado
                      final existingRows = await _supabase
                          .from('drink_flavors')
                          .select()
                          .inFilter('type', refrescoTypes)
                          .eq('name', isEditing ? (flavor['name'] as String) : name);
                      final existingByType = <String, dynamic>{};
                      for (final r in (existingRows as List)) {
                        existingByType[r['type'] as String] = r;
                      }
                      for (final t in refrescoTypes) {
                        if (selectedRefrescoSizes.contains(t)) {
                          if (existingByType.containsKey(t)) {
                            await _supabase.from('drink_flavors')
                                .update({'name': name})
                                .eq('id', existingByType[t]['id']);
                          } else {
                            await _supabase.from('drink_flavors').insert({
                              'name': name,
                              'type': t,
                              'available': true,
                            });
                          }
                        } else if (existingByType.containsKey(t)) {
                          await _supabase.from('drink_flavors')
                              .delete()
                              .eq('id', existingByType[t]['id']);
                        }
                      }
                    }
                    _fetchFlavors();
                  } catch (e) {
                    _fetchFlavors();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                } : null,
                style: TextButton.styleFrom(backgroundColor: const Color(0xFFFF6D00).withOpacity(0.15)),
                child: Text(isEditing ? 'Guardar' : 'Agregar',
                    style: const TextStyle(color: Color(0xFFFF6D00))),
              ),
            ],
          );
        },
      ),
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
        final icon = tabType == 'agua_fresca'
            ? Icons.water_drop
            : tabType == 'jugo'
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
                  ? const Color(0xFFFF6D00).withOpacity(0.15)
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
                if (tabType != 'agua_fresca' && tabType != 'jugo') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _subtypeColor(ftype).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _subtypeColor(ftype).withOpacity(0.4)),
                    ),
                    child: Text(
                      _subtypeLabel(ftype),
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
    const tabTypes = ['refresco', 'agua_fresca', 'jugo'];
    final currentType = tabTypes[_tabController.index];
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFlavorDialog(type: currentType),
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
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
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
              'Administra los sabores y marcas disponibles para refrescos y aguas frescas.',
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
              Tab(icon: Icon(Icons.water_drop, size: 18), child: Text('Aguas Frescas')),
              Tab(icon: Icon(Icons.blender,     size: 18), child: Text('Jugos')),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(_refrescos, 'refresco'),
                _buildList(_aguas,     'agua_fresca'),
                _buildList(_jugos,     'jugo'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
