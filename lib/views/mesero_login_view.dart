import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';
import 'comandas_view.dart';

/// Vista de acceso directo para meseros.
/// Se usa instalando la PWA con la ruta /#/mesero.
/// Muestra selector de sucursal (si hace falta) y PIN de mesero.
class MeseroLoginView extends StatefulWidget {
  const MeseroLoginView({super.key});

  @override
  State<MeseroLoginView> createState() => _MeseroLoginViewState();
}

class _MeseroLoginViewState extends State<MeseroLoginView> {
  final _supabase = Supabase.instance.client;
  final _pinController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _branchReady = false;

  @override
  void initState() {
    super.initState();
    // Si ya hay sucursal guardada, no hace falta seleccionar
    _branchReady = Globals.currentBranch.isNotEmpty;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final response = await _supabase
          .from('waiters')
          .select()
          .eq('pin', pin)
          .eq('branch_name', Globals.currentBranch)
          .maybeSingle();
      if (!mounted) return;
      if (response != null) {
        final waiterId = response['id'].toString();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ComandasView(waiterId: waiterId)),
        );
      } else {
        setState(() => _error = 'PIN incorrecto para esta sucursal');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Image.asset('assets/images/logo.png',
                    height: isMobile ? 100 : 130,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.restaurant, size: 80, color: Color(0xFFFF6D00))),
                const SizedBox(height: 20),
                const Text(
                  'Modo Mesero',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Acceso rápido para tomar comandas',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // ── Selector de sucursal ──
                if (!_branchReady) ...[
                  const Text('Selecciona tu sucursal:',
                      style:
                          TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF334155), width: 1.5),
                    ),
                    child: Row(
                      children: Globals.branches.asMap().entries.map((e) {
                        final i = e.key;
                        final branch = e.value;
                        final selected = Globals.currentBranch == branch;
                        return Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.only(left: i > 0 ? 6 : 0),
                            child: GestureDetector(
                              onTap: () async {
                                await Globals.setBranch(branch);
                                setState(() => _branchReady = true);
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFFF6D00)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  branch,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Sucursal activa
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store,
                          color: Color(0xFFFF6D00), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        Globals.currentBranch,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () =>
                            setState(() => _branchReady = false),
                        child: const Text('Cambiar',
                            style: TextStyle(
                                color: Color(0xFFFF6D00), fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // ── PIN ──
                if (_branchReady) ...[
                  TextField(
                    controller: _pinController,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 16,
                        color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '● ● ● ●',
                      hintStyle: const TextStyle(
                          color: Color(0xFF334155), fontSize: 22),
                      labelText: 'PIN de Mesero',
                      labelStyle:
                          const TextStyle(color: Color(0xFF94A3B8)),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFFFF6D00), width: 2),
                      ),
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _enter(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _enter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6D00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('Entrar',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
