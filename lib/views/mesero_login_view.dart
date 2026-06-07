import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';
import '../utils/app_updater.dart';
import 'comandas_view.dart';

/// Llaves de persistencia para auto-login del mesero en este tablet.
const _kRememberedPinKey = 'mesero_remembered_pin';
const _kRememberedBranchKey = 'mesero_remembered_branch';

/// Borra el "auto-login" persistido — se llama desde Cerrar sesión en Comandas.
Future<void> clearRememberedMesero() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kRememberedPinKey);
  await prefs.remove(_kRememberedBranchKey);
}

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
/// URLs soportadas:
///   /#/Maravillas/mesero        → branch "Maravillas" en el path
///   /#/mesero?branch=Sucursal+1 → branch por query param (fallback)
class MeseroLoginView extends StatefulWidget {
  /// Sucursal leída del path de la URL (puede ser null si viene por query param).
  final String? branch;
  const MeseroLoginView({super.key, this.branch});

  @override
  State<MeseroLoginView> createState() => _MeseroLoginViewState();
}

class _MeseroLoginViewState extends State<MeseroLoginView> {
  final _supabase = Supabase.instance.client;
  final _pinController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _rememberMe = true;
  bool _autoLoginAttempted = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _applyBranch();
    await _tryAutoLogin();
  }

  /// Aplica la sucursal: primero del path, luego del query param de la URL.
  Future<void> _applyBranch() async {
    final branch = widget.branch ?? _branchFromUrl();
    if (branch != null && branch.isNotEmpty && branch != Globals.currentBranch) {
      await Globals.setBranch(branch);
      if (mounted) setState(() {});
    }
  }

  /// Si en este tablet se guardó "Recordar mesero", intenta entrar
  /// directo sin pedir PIN. Si las credenciales ya no son válidas, las
  /// borra y deja la pantalla normal.
  Future<void> _tryAutoLogin() async {
    if (_autoLoginAttempted) return;
    _autoLoginAttempted = true;
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_kRememberedPinKey);
    final savedBranch = prefs.getString(_kRememberedBranchKey);
    if (savedPin == null || savedPin.isEmpty) return;
    if (savedBranch != null &&
        savedBranch.isNotEmpty &&
        savedBranch != Globals.currentBranch) {
      // El tablet cambió de sucursal — pierde la sesión recordada.
      await clearRememberedMesero();
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final response = await _supabase
          .from('waiters')
          .select()
          .eq('pin', savedPin)
          .eq('branch_name', Globals.currentBranch)
          .maybeSingle();
      if (!mounted) return;
      if (response != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ComandasView(waiterId: response['id'].toString())),
        );
        return;
      } else {
        // PIN inválido (mesero borrado, PIN cambiado, etc.).
        await clearRememberedMesero();
      }
    } catch (_) {
      // Sin red u otro error — no auto-login, deja al usuario teclear.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// Diálogo para que el dueño/admin elija qué sucursal usa este tablet.
  /// La selección persiste en SharedPreferences (vía Globals.setBranch),
  /// así que solo se hace una vez por tablet.
  Future<void> _showBranchPicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFFFAF1DE),
        title: const Text('Sucursal de este tablet',
            style: TextStyle(color: Color(0xFF3D2E1A))),
        children: [
          for (final b in Globals.branches)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, b),
              child: Row(
                children: [
                  Icon(
                    b == Globals.currentBranch
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: const Color(0xFFFF6D00),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(b,
                      style: const TextStyle(
                          color: Color(0xFF3D2E1A),
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null && selected != Globals.currentBranch) {
      // Cambia la sucursal y borra cualquier mesero "recordado" anterior
      // (sería de la sucursal vieja).
      await Globals.setBranch(selected);
      await clearRememberedMesero();
      if (mounted) setState(() => _error = null);
    }
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
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kRememberedPinKey, pin);
          await prefs.setString(
              _kRememberedBranchKey, Globals.currentBranch);
        } else {
          await clearRememberedMesero();
        }
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
      backgroundColor: const Color(0xFFFAF1DE),
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
                      color: Color(0xFFFF6D00)),
                ),
                const SizedBox(height: 6),
                // Sucursal — tappable para cambiar en este tablet.
                InkWell(
                  onTap: _showBranchPicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.store,
                            color: Color(0xFFFF6D00), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          Globals.currentBranch,
                          style: const TextStyle(
                              color: Color(0xFFA08F70), fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down,
                            color: Color(0xFFA08F70), size: 18),
                      ],
                    ),
                  ),
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
                      fontSize: 30, letterSpacing: 18, color: Color(0xFFFF6D00)),
                  decoration: InputDecoration(
                    hintText: '● ● ● ●',
                    hintStyle:
                        const TextStyle(color: Color(0xFFE5DCC4), fontSize: 22),
                    labelText: 'PIN de Mesero',
                    labelStyle: const TextStyle(color: Color(0xFFA08F70)),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFFAF1DE),
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
                const SizedBox(height: 8),
                // Recordar mesero en este tablet (kiosko)
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? true),
                      activeColor: const Color(0xFFFF6D00),
                      checkColor: const Color(0xFFFAF1DE),
                      side: const BorderSide(
                          color: Color(0xFFA08F70), width: 1.5),
                    ),
                    const Expanded(
                      child: Text(
                        'Recordar este mesero en esta tablet\n(abre directo al prender)',
                        style: TextStyle(
                            color: Color(0xFFA08F70), fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _enter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6D00),
                      foregroundColor: Color(0xFFFAF1DE),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Color(0xFFFAF1DE), strokeWidth: 2.5))
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
