import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';

/// Convierte el nombre de sucursal en slug URL.
/// "Sucursal Maravillas" → "Maravillas"
/// "Sucursal Pocitos"   → "Pocitos"
String _branchSlug(String branch) {
  const prefix = 'Sucursal ';
  if (branch.startsWith(prefix)) return branch.substring(prefix.length);
  return branch;
}

const _baseUrl = 'https://restaurant-pwa.c4o2yg.easypanel.host';

class WaiterManagementView extends StatefulWidget {
  const WaiterManagementView({super.key});

  @override
  State<WaiterManagementView> createState() => _WaiterManagementViewState();
}

class _WaiterManagementViewState extends State<WaiterManagementView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _waiters = [];

  String get _meseroUrl {
    final slug = Uri.encodeComponent(_branchSlug(Globals.currentBranch));
    return '$_baseUrl/#/$slug/mesero';
  }

  // ── QR grande en diálogo ─────────────────────────────────────────────────
  void _showQrDialog() {
    final url = _meseroUrl;
    final slug = _branchSlug(Globals.currentBranch);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'QR Meseros · $slug',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              url,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta compacta con QR pequeño + botones ────────────────────────────
  Widget _buildLinkCard() {
    final url = _meseroUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6D00).withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // QR pequeño
          GestureDetector(
            onTap: _showQrDialog,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 88,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Etiqueta
                Row(children: [
                  const Icon(Icons.qr_code_2, color: Color(0xFFFF6D00), size: 15),
                  const SizedBox(width: 5),
                  const Text(
                    'Enlace para meseros',
                    style: TextStyle(
                        color: Color(0xFFFF6D00),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ]),
                const SizedBox(height: 5),
                // URL
                Text(
                  url,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Botones
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _LinkBtn(
                      icon: Icons.copy,
                      label: 'Copiar enlace',
                      color: Colors.white,
                      borderColor: const Color(0xFF475569),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enlace copiado al portapapeles'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _LinkBtn(
                      icon: Icons.qr_code,
                      label: 'Ver QR',
                      color: const Color(0xFFFF6D00),
                      borderColor: const Color(0xFFFF6D00),
                      onTap: _showQrDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Diálogo nuevo/editar mesero ──────────────────────────────────────────
  Future<void> _showWaiterDialog([Map<String, dynamic>? waiter]) async {
    final nameController = TextEditingController(text: waiter?['name'] ?? '');
    final pinController =
        TextEditingController(text: waiter?['pin']?.toString() ?? '');
    final isEditing = waiter != null;

    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(isEditing ? 'Editar Mesero' : 'Nuevo Mesero',
              style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre Completo',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña / PIN (Ej. 1234)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final pin = pinController.text.trim();
                if (name.isEmpty) return;

                // Validar PIN: exactamente 4 dígitos
                if (pin.length != 4 || int.tryParse(pin) == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El PIN debe ser de exactamente 4 dígitos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validar PIN único (no lo tenga otro mesero)
                try {
                  var query =
                      _supabase.from('waiters').select('id').eq('pin', pin);
                  if (isEditing) query = query.neq('id', waiter['id']);
                  final existing = await query;
                  if ((existing as List).isNotEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Ese PIN ya lo usa otro mesero, elige uno diferente'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  if (isEditing) {
                    await _supabase.from('waiters').update({
                      'name': name,
                      'pin': pin,
                      'branch_name': Globals.currentBranch,
                    }).eq('id', waiter['id']);
                  } else {
                    await _supabase.from('waiters').insert({
                      'name': name,
                      'pin': pin,
                      'branch_name': Globals.currentBranch,
                    });
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6D00)),
              child: const Text('Guardar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ── Eliminar mesero ──────────────────────────────────────────────────────
  Future<void> _deleteWaiter(String id) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Eliminar Mesero?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción no se puede deshacer.',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, false);
              try {
                await _supabase
                    .from('orders')
                    .update({'waiter_id': null}).eq('waiter_id', id);
                await _supabase.from('waiters').delete().eq('id', id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Mesero eliminado'),
                    duration: Duration(seconds: 2),
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error al eliminar: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ));
                }
              }
            },
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final crossAxisCount =
        width < 600 ? 1 : width < 1000 ? 2 : width < 1400 ? 3 : 4;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('waiters')
          .stream(primaryKey: ['id'])
          .eq('branch_name', Globals.currentBranch)
          .order('name'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        _waiters = snapshot.data!;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado ──────────────────────────────────────────────
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: isMobile
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gestión de Meseros',
                    style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  if (isMobile) const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showWaiterDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo Mesero'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6D00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Tarjeta enlace / QR ──────────────────────────────────────
              _buildLinkCard(),

              // ── Grid de meseros ──────────────────────────────────────────
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: isMobile ? 3.0 : 2.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _waiters.length,
                  itemBuilder: (context, index) {
                    final waiter = _waiters[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFFF6D00)
                                .withValues(alpha: 0.2),
                            child: Text(
                              waiter['name']
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFFFF6D00),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              waiter['name'],
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showWaiterDialog(waiter),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _deleteWaiter(waiter['id'].toString()),
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Botón pequeño para la tarjeta de enlace ──────────────────────────────────
class _LinkBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;

  const _LinkBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
