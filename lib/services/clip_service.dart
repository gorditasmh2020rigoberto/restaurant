import 'dart:convert';
import 'package:http/http.dart' as http;

/// Servicio para procesar pagos con Clip y enviar tickets por email.
///
/// Usa la edge function `clip-pago` desplegada en el Supabase del restaurante.
/// Lee credenciales (clip_secret_key, resend_api_key, etc.) de la tabla
/// `public.app_config`.
class ClipService {
  static const _supabaseUrl = 'https://jcaqolmacqhhgtjdgvaz.supabase.co';
  static const _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjYXFvbG1hY3FoaGd0amRndmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MDExMDIsImV4cCI6MjA4OTI3NzEwMn0.9TS8QZ5ZWG1MOct4nif0yiTW_bq_qbgAGbTjTle1_fk';
  static const _fnUrl = '$_supabaseUrl/functions/v1/clip-pago';

  static Future<Map<String, dynamic>> _call(
      Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(_fnUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_anonKey',
        'apikey': _anonKey,
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
