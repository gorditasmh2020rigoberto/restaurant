import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';
import '../utils/app_updater.dart';
import 'comandas_view.dart';

/// Lee el parámetro ?branch= del fragmento de la URL (hash routing).
/// Ejemplo: /#/mesero?branch=Sucursal+1  →  "Sucursal 1"
String? _branchFromUrl() {
  if (!kIsWeb) return null;
  try {
    final fragment = Uri.base.fragment; // e.g. "/mesero?branch=Sucursal+1"
    final qIdx = fragment.indexOf('?');
    if (qIdx == -1) return null;
    final params = Uri.splitQueryString(fragment.substring(qIdx + 1));
    return params['branch'];
  } catch (_) {
    return null;
  }
}

/// Vista de acceso directo para meseros.
/// Se usa instalando la PWA con la ruta /#/mesero?branch=Sucursal+1 en la tablet.
/// La sucursal se lee de la URL — no hay que configurar nada manualmente.
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

  @override
  void initState() {
    super.initState();
    _applyBranchFromUrl();
  }

  /// Si la URL trae ?branch=..., actualiza Globals y SharedPreferences.
  Future<void> _applyBranchFromUrl() async {
    final branch = _branchFromUrl();
    if (branch != null && branch.isNotEmpty && branch != Globals.currentBranch) {
      await Globals.setBranch(branch);
      if (mounted) setState(() {});
    }
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
          .maybeSingle();
      if (!mounted) return;
      if (response != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ComandasView(waiterId: response['id'].toString())),
        );
      } else {
        setState(() {
          _error = 'PIN incorrecto';
          _pinController.clear();
        });
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
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo.png',
                  height: isMobile ? 100 : 130,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.restaurant, size: 80, color: Color(0xFFFF6D00)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mesero',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                // Sucursal leída de la URL (o del dispositivo)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.store, color: Color(0xFFFF6D00), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      Globals.currentBranch,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // PIN
                TextField(
                  controller: _pinController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 30, letterSpacing: 18, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '● ● ● ●',
                    hintStyle:
                        const TextStyle(color: Color(0xFF334155), fontSize: 22),
                    labelText: 'PIN de Mesero',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Color(0xFFFF6D00), width: 2),
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
                                fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                const UpdateAppButton(compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
