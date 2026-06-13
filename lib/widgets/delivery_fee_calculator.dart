import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../globals.dart';
import '../services/delivery_fee.dart';

/// Widget compacto que calcula la cuota de delivery FLASH a partir de:
///  - km (input)
///  - km de carretera (opcional)
///  - toggles de lluvia / festivo
///
/// Llama [onChanged] cada vez que cambia el desglose, para que el
/// formulario padre sume la cuota al total de la orden.
class DeliveryFeeCalculator extends StatefulWidget {
  final String? destinationAddress;
  final ValueChanged<DeliveryFeeBreakdown> onChanged;

  /// Valores iniciales (al editar una orden ya creada).
  final double initialKm;
  final double initialKmCarretera;
  final bool initialRain;
  final bool initialHoliday;

  const DeliveryFeeCalculator({
    super.key,
    required this.onChanged,
    this.destinationAddress,
    this.initialKm = 0,
    this.initialKmCarretera = 0,
    this.initialRain = false,
    this.initialHoliday = false,
  });

  @override
  State<DeliveryFeeCalculator> createState() => _DeliveryFeeCalculatorState();
}

class _DeliveryFeeCalculatorState extends State<DeliveryFeeCalculator> {
  late final TextEditingController _kmCtrl;
  late final TextEditingController _kmCarrCtrl;
  bool _rain = false;
  bool _holiday = false;

  @override
  void initState() {
    super.initState();
    _kmCtrl = TextEditingController(
        text: widget.initialKm > 0 ? widget.initialKm.toString() : '');
    _kmCarrCtrl = TextEditingController(
        text: widget.initialKmCarretera > 0
            ? widget.initialKmCarretera.toString()
            : '');
    _rain = widget.initialRain;
    _holiday = widget.initialHoliday;
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    _kmCarrCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final km = double.tryParse(_kmCtrl.text.replaceAll(',', '.')) ?? 0;
    final kmCarr =
        double.tryParse(_kmCarrCtrl.text.replaceAll(',', '.')) ?? 0;
    widget.onChanged(calculateDeliveryFee(
      km: km,
      kmCarretera: kmCarr,
      rain: _rain,
      holiday: _holiday,
    ));
  }

  Future<void> _openMaps() async {
    final url = Uri.parse(buildMapsRouteUrl(
      branchName: Globals.currentBranch,
      destinationAddress: widget.destinationAddress,
    ));
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final km = double.tryParse(_kmCtrl.text.replaceAll(',', '.')) ?? 0;
    final kmCarr =
        double.tryParse(_kmCarrCtrl.text.replaceAll(',', '.')) ?? 0;
    final fee = calculateDeliveryFee(
      km: km,
      kmCarretera: kmCarr,
      rain: _rain,
      holiday: _holiday,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6D00).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFF6D00).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining,
                  color: Color(0xFFFF6D00), size: 20),
              const SizedBox(width: 6),
              const Text(
                'Cuota de Envío FLASH',
                style: TextStyle(
                  color: Color(0xFFFF6D00),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _openMaps,
                icon: const Icon(Icons.map, size: 16),
                label: const Text('Ver ruta'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6D00),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kmCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => setState(_emit),
                  style: const TextStyle(color: Color(0xFF3D2E1A)),
                  decoration: const InputDecoration(
                    labelText: 'Km totales',
                    labelStyle: TextStyle(color: Color(0xFFA08F70)),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _kmCarrCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => setState(_emit),
                  style: const TextStyle(color: Color(0xFF3D2E1A)),
                  decoration: const InputDecoration(
                    labelText: 'Km de carretera',
                    labelStyle: TextStyle(color: Color(0xFFA08F70)),
                    isDense: true,
                    helperText: '+\$10 c/km',
                    helperStyle: TextStyle(
                        color: Color(0xFFA08F70), fontSize: 10),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('🌧️ Lluvia (+\$20)'),
                selected: _rain,
                onSelected: (v) => setState(() {
                  _rain = v;
                  _emit();
                }),
                selectedColor:
                    const Color(0xFFFF6D00).withValues(alpha: 0.25),
                checkmarkColor: const Color(0xFFFF6D00),
                labelStyle: const TextStyle(color: Color(0xFF3D2E1A)),
              ),
              FilterChip(
                label: const Text('🎉 Festivo (+\$20)'),
                selected: _holiday,
                onSelected: (v) => setState(() {
                  _holiday = v;
                  _emit();
                }),
                selectedColor:
                    const Color(0xFFFF6D00).withValues(alpha: 0.25),
                checkmarkColor: const Color(0xFFFF6D00),
                labelStyle: const TextStyle(color: Color(0xFF3D2E1A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE5DCC4)),
          const SizedBox(height: 8),
          if (fee.base > 0) ...[
            _line('Base por zona', fee.base),
            if (fee.extraKm > 0) _line('Km extra (>10)', fee.extraKm),
            if (fee.carretera > 0) _line('Carretera', fee.carretera),
            if (fee.rain > 0) _line('Lluvia', fee.rain),
            if (fee.holiday > 0) _line('Festivo', fee.holiday),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL ENVÍO',
                    style: TextStyle(
                      color: Color(0xFF3D2E1A),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    )),
                Text('\$${fee.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFFF6D00),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    )),
              ],
            ),
          ] else
            const Text(
              'Teclea los km para calcular el envío.',
              style: TextStyle(
                  color: Color(0xFFA08F70),
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _line(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF7A6E5A), fontSize: 12)),
          Text('+\$${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Color(0xFF7A6E5A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
