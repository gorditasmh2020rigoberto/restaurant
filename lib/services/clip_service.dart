import 'dart:convert';
import 'package:http/http.dart' as http;

/// Servicio para procesar pagos con Clip y enviar tickets por email.
///
/// Usa la edge function `mp-pago` desplegada en el Supabase del proyecto PV,
/// que también maneja Clip via `action='clip'` y emails via `action='ticket'`.
class ClipService {
  static const _pvSupabaseUrl = 'https://oahpmdsmjemyyxeryvyn.supabase.co';
  static const _pvAnonKey =
      'sb_publishable_CiRH0sWx0ScGlN41Vo7EOw_OVsNjbwj';
  static const _fnUrl = '$_pvSupabaseUrl/functions/v1/mp-pago';

  static Future<Map<String, dynamic>> _call(
      Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(_fnUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_pvAnonKey',
      },
      body: jsonEncode(body),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Procesa el pago con Clip y devuelve el resultado.
  static Future<ClipResult> procesarPago({
    required String token,
    required double amount,
    required String email,
    required List<Map<String, dynamic>> items,
    int installments = 1,
  }) async {
    final json = await _call({
      'action': 'clip',
      'token': token,
      'installments': installments,
      'amount': amount,
      'email': email,
      'items': items,
    });

    final status = (json['status']?.toString() ?? 'error').toLowerCase();
    return ClipResult(
      approved: status == 'approved' || json['ok'] == true,
      paymentId: json['payment_id']?.toString(),
      detail: json['status_detail']?.toString() ?? json['detail']?.toString(),
      errorMessage: json['message']?.toString(),
    );
  }

  /// Envía el ticket por email después de un pago exitoso.
  static Future<void> enviarTicket({
    required String email,
    required String paymentId,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    await _call({
      'action': 'ticket',
      'email': email,
      'payment_id': paymentId,
      'total': total,
      'items': items,
    });
  }
}

class ClipResult {
  final bool approved;
  final String? paymentId;
  final String? detail;
  final String? errorMessage;

  const ClipResult({
    required this.approved,
    this.paymentId,
    this.detail,
    this.errorMessage,
  });
}
