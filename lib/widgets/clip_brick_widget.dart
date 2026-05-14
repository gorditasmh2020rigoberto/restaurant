// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

const _clipApiKey = 'test_eb8dc81f-26fc-482a-9a86-eb0c91dcfecc';

class ClipBrickWidget extends StatefulWidget {
  final double amount;
  final void Function(Map<String, dynamic> data) onSubmit;
  final void Function(String error)? onError;
  final void Function()? onReady;

  const ClipBrickWidget({
    super.key,
    required this.amount,
    required this.onSubmit,
    this.onError,
    this.onReady,
  });

  @override
  State<ClipBrickWidget> createState() => _ClipBrickWidgetState();
}

class _ClipBrickWidgetState extends State<ClipBrickWidget> {
  late final String _viewId;
  late final String _containerId;
  bool _listo = false;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _viewId = 'clip-brick-$ts';
    _containerId = 'clip-container-$ts';

    ui.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      final div = html.DivElement()
        ..id = _containerId
        ..style.width = '100%'
        ..style.minHeight = '320px';
      return div;
    });

    js.context['_clipOnReady'] = () {
      if (mounted) setState(() => _listo = true);
      widget.onReady?.call();
    };

    js.context['_clipOnSubmit'] = (String rawData) {
      if (mounted) setState(() => _procesando = false);
      final data = jsonDecode(rawData) as Map<String, dynamic>;
      widget.onSubmit(data);
    };

    js.context['_clipOnError'] = (String rawError) {
      if (mounted) setState(() => _procesando = false);
      widget.onError?.call(rawError);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      js.context.callMethod('clipInitBrick', [
        _containerId,
        _clipApiKey,
        widget.amount.toString(),
      ]);
    });
  }

  @override
  void dispose() {
    js.context.callMethod('clipUnmount', []);
    super.dispose();
  }

  void _pagar() {
    setState(() => _procesando = true);
    js.context.callMethod('clipSubmitPago', []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 360,
          child: HtmlElementView(viewType: _viewId),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_listo && !_procesando) ? _pagar : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFC4C02),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _procesando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Pagar con Clip',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
