import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';

class GuisadosManagementView extends StatefulWidget {
  const GuisadosManagementView({super.key});

  @override
  State<GuisadosManagementView> createState() => _GuisadosManagementViewState();
}

class _GuisadosManagementViewState extends State<GuisadosManagementView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _guisados = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchGuisados();
  }

  Future<void> _fetchGuisados() async {
    try {
      final data = await _supabase
          .from('guisados')
          .select()
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          _guisados = (data as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .where((g) {
                final branch = g['branch_name'] as String?;
                return branch == null || branch == Globals.currentBranch;
              })
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

  Future<void> _toggleAvailable(Map<String, dynamic> guisado) async {
    final newValue = !(guisado['available'] as bool? ?? true);
    // Actualizar UI inmediatamente (optimista)
    setState(() {
      final index = _guisados.indexWhere((g) => g['id'] == guisado['id']);
      if (index != -1) _guisados[index] = {..._guisados[index], 'available': newValue};
    });
    try {
      await _supabase
          .from('guisados')
          .update({'available': newValue})
          .eq('id', guisado['id']);
    } catch (e) {
      // Revertir si falla
      setState(() {
        final index = _guisados.indexWhere((g) => g['id'] == guisado['id']);
        if (index != -1) _guisados[index] = {..._guisados[index], 'available': !newValue};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  Future<void> _deleteGuisado(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF1DE),
        title: const Text('¿Eliminar guisado?',
            style: TextStyle(color: Color(0xFFFAF1DE))),
        content: const Text('Esta acción no se puede deshacer.',
            style: TextStyle(color: Color(0xFF7A6E5A))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFFA08F70))),
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

    // Quitar de la lista inmediatamente
    setState(() => _guisados.removeWhere((g) => g['id'] == id));

    try {
      await _supabase.from('guisados').delete().eq('id', id);
    } catch (e) {
      // Recargar si falla
      _fetchGuisados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Future<void> _showGuisadoDialog({Map<String, dynamic>? guisado}) async {
    final isEditing = guisado != null;
    final nameController = TextEditingController(
      text: isEditing ? guisado['name'] as String : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF1DE),
        title: Text(
          isEditing ? 'Editar Guisado' : 'Nuevo Guisado',
          style: const TextStyle(color: Color(0xFFFAF1DE)),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFFAF1DE)),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: isEditing ? guisado['name'] as String : 'Nombre del guisado (ej. Picadillo)',
            hintStyle: const TextStyle(color: Color(0xFFB6A88A)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFF6D00)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFF6D00), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFFA08F70))),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                if (isEditing) {
                  // Actualizar UI inmediatamente
                  setState(() {
                    final index = _guisados.indexWhere((g) => g['id'] == guisado['id']);
                    if (index != -1) _guisados[index] = {..._guisados[index], 'name': name};
                  });
                  await _supabase
                      .from('guisados')
                      .update({'name': name})
                      .eq('id', guisado['id']);
                } else {
                  final result = await _supabase.from('guisados').insert({
                    'name': name,
                    'branch_name': null,
                    'available': true,
                  }).select().single();
                  // Agregar a la lista inmediatamente
                  setState(() {
                    _guisados.add(result);
                    _guisados.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                  });
                }
              } catch (e) {
                _fetchGuisados(); // Recargar si falla
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF6D00).withOpacity(0.15),
            ),
            child: Text(
              isEditing ? 'Guardar' : 'Agregar',
              style: const TextStyle(color: Color(0xFFFF6D00)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF1DE),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGuisadoDialog(),
        backgroundColor: const Color(0xFFFF6D00),
        child: const Icon(Icons.add, color: Color(0xFFFAF1DE)),
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
                    'Gestión de Guisados',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFF6D00)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFFA08F70)),
                  tooltip: 'Actualizar',
                  onPressed: _fetchGuisados,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              'Administra los rellenos disponibles para gorditas, tamales y más.',
              style: TextStyle(color: Color(0xFFA08F70), fontSize: 13),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00)))
                : _guisados.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay guisados registrados.\nPresiona + para agregar uno.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFA08F70), fontSize: 15),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                        itemCount: _guisados.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0xFFE5DCC4)),
                        itemBuilder: (context, index) {
                          final g = _guisados[index];
                          final available = g['available'] as bool? ?? true;

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF1DE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: available
                                    ? const Color(0xFFFF6D00).withOpacity(0.15)
                                    : const Color(0xFFE5DCC4),
                                child: Icon(
                                  Icons.lunch_dining,
                                  color: available ? const Color(0xFFFF6D00) : Color(0xFFB6A88A),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                g['name'] as String,
                                style: TextStyle(
                                  color: available ? Color(0xFFFAF1DE) : Color(0xFFB6A88A),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
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
                                    onChanged: (_) => _toggleAvailable(g),
                                    activeColor: const Color(0xFFFF6D00),
                                    inactiveThumbColor: Color(0xFFB6A88A),
                                    inactiveTrackColor: const Color(0xFFE5DCC4),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                                    onPressed: () => _showGuisadoDialog(guisado: g),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteGuisado(g['id'] as String),
                                    tooltip: 'Eliminar',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
