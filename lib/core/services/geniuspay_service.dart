import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const String _paymentStatusProxyUrl =
    'https://wtfygkiuzjmndnirtevy.supabase.co/functions/v1/payment-status';

class GeniusPayResult {
  final String checkoutUrl;
  final String reference;
  final String? paymentId;
  final int amount;
  final String provider;

  GeniusPayResult({
    required this.checkoutUrl,
    required this.reference,
    this.paymentId,
    required this.amount,
    required this.provider,
  });

  factory GeniusPayResult.fromJson(Map<String, dynamic> json) {
    final checkoutUrl =
        (json['checkout_url'] ?? json['payment_url'])?.toString();
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception('URL de paiement introuvable.');
    }

    return GeniusPayResult(
      checkoutUrl: checkoutUrl,
      reference: json['reference'] as String,
      paymentId: json['payment_id'] as String?,
      amount: (json['amount'] as num).toInt(),
      provider: json['provider'] as String,
    );
  }
}

class GeniusPayService {
  final SupabaseClient _supabase;

  GeniusPayService(this._supabase);

  Future<GeniusPayResult> createPayment({
    required String orderId,
    required String provider,
    required String customerPhone,
    String? customerName,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-geniuspay-payment',
        body: {
          'order_id': orderId,
          'provider': provider,
          'customer_phone': customerPhone,
          'customer_name': customerName,
        },
      );

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null || data['success'] == false) {
        // Log technique uniquement — jamais affiché à l'utilisateur
        debugPrint(
          '❌ GeniusPay error: ${data['error']} '
          '| genius_status: ${data['genius_status']} '
          '| details: ${data['details'] ?? data['message']}',
        );
        throw Exception(
          _resolveFriendlyMessage(null, data['genius_status'] as int?),
        );
      }

      if (data['warning'] != null) {
        debugPrint('⚠️ GeniusPay warning: ${data['warning']}');
      }

      return GeniusPayResult.fromJson(data);
    } on FunctionException catch (e) {
      // Log complet réservé au debug — ne jamais remonter e.toString() à l'UI
      debugPrint(
        '❌ FunctionException | status: ${e.status} '
        '| details: ${e.details} '
        '| reason: ${e.reasonPhrase}',
      );

      int? geniusStatus;
      final details = e.details;
      if (details is Map) {
        geniusStatus = details['genius_status'] as int?;
      }

      throw Exception(_resolveFriendlyMessage(e.status, geniusStatus));
    } on PostgrestException catch (e) {
      debugPrint('❌ PostgrestException: ${e.message}');
      throw Exception('Erreur de base de données. Veuillez réessayer.');
    } on AuthException catch (e) {
      debugPrint('❌ AuthException: ${e.message}');
      throw Exception('Session expirée. Veuillez vous reconnecter.');
    } catch (e) {
      debugPrint('❌ Erreur inattendue: $e');
      // Si c'est déjà une Exception avec un message friendly (relancée plus haut),
      // on la propage telle quelle.
      if (e is Exception) rethrow;
      throw Exception('Erreur inattendue. Veuillez réessayer.');
    }
  }

  /// Retourne un message lisible selon les codes HTTP/GeniusPay.
  /// Ne jamais exposer de détails techniques dans la valeur retournée.
  String _resolveFriendlyMessage(int? httpStatus, int? geniusStatus) {
    // Service GeniusPay indisponible (cas actuel : 502 / 503)
    if (httpStatus == 502 || geniusStatus == 503) {
      return 'Le service de paiement est temporairement indisponible. '
          'Veuillez réessayer dans quelques instants.';
    }

    // Paiement refusé / solde insuffisant
    if (geniusStatus == 402 || geniusStatus == 403) {
      return 'Paiement refusé. Vérifiez votre solde ou votre numéro.';
    }

    // Timeout
    if (geniusStatus == 408 || httpStatus == 504) {
      return 'Le paiement a expiré. Veuillez réessayer.';
    }

    // Numéro invalide / paramètres incorrects
    if (geniusStatus == 422) {
      return 'Numéro de téléphone invalide pour ce mode de paiement.';
    }

    // Non autorisé (clé API, token expiré côté Edge Function)
    if (httpStatus == 401 || geniusStatus == 401) {
      return 'Autorisation refusée. Contactez le support si cela persiste.';
    }

    // Fallback générique — aucun détail technique
    return 'Échec du paiement. Réessayez ou choisissez '
        'un autre moyen de paiement.';
  }

  /// Vérifie le statut d'un paiement par référence (polling de secours).
  Future<String?> checkPaymentStatus(String reference) async {
    try {
      final result = await _supabase
          .from('payments')
          .select('status')
          .eq('reference', reference)
          .maybeSingle();
      final localStatus = (result?['status'] as String?)?.toLowerCase();
      if (_isFinalStatus(localStatus)) return localStatus;

      final session = _supabase.auth.currentSession;
      final response = await http.get(
        Uri.parse('$_paymentStatusProxyUrl/$reference'),
        headers: {
          'Content-Type': 'application/json',
          if (session?.accessToken != null)
            'Authorization': 'Bearer ${session!.accessToken}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return localStatus;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['status'] as String?)?.toLowerCase() ?? localStatus;
    } on PostgrestException catch (e) {
      debugPrint('❌ Erreur vérification statut: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Erreur inattendue: $e');
      return null;
    }
  }

  bool _isFinalStatus(String? status) {
    return status == 'completed' ||
        status == 'success' ||
        status == 'paid' ||
        status == 'failed' ||
        status == 'cancelled' ||
        status == 'refunded';
  }
}
