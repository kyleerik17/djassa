import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return GeniusPayResult(
      checkoutUrl: json['checkout_url'] as String,
      reference: json['reference'] as String,
      paymentId: json['payment_id'] as String?,
      amount: json['amount'] as int,
      provider: json['provider'] as String,
    );
  }
}

/// 🔑 Helper universel : extrait un message d'erreur depuis N'IMPORTE QUELLE exception
String getErrorMessage(dynamic error) {
  // ✅ FonctionException : pas de propriétés garanties → utiliser toString()
  if (error is FunctionException) {
    return error.toString().replaceAll('FunctionException: ', '');
  }
  
  // ✅ PostgrestException, AuthException, StorageException ont .message
  if (error is PostgrestException || 
      error is AuthException || 
      error is StorageException) {
    final msg = (error as dynamic).message as String?;
    if (msg != null && msg.isNotEmpty) return msg;
  }
  
  // ✅ Fallback générique
  if (error is Exception) return error.toString();
  return 'Erreur inconnue: $error';
}

class GeniusPayService {
  final SupabaseClient _supabase;

  GeniusPayService(this._supabase);

  /// Crée un paiement via l'Edge Function Supabase
  /// ✅ Compatible supabase_flutter ^1.0.0 à ^2.5.0+
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

      // ✅ Parsing sécurisé
      final Map<String, dynamic> data;
      if (response is Map<String, dynamic>) {
        data = response as Map<String, dynamic>;
      } else if (response != null) {
        data = jsonDecode(jsonEncode(response)) as Map<String, dynamic>;
      } else {
        throw Exception('Réponse vide du serveur');
      }

      // ✅ Erreur métier dans le corps de la réponse
      if (data['error'] != null) {
        final errorMessage = data['error'] as String;
        final details = data['details'] ?? data['message'] ?? '';
        throw Exception('Erreur GeniusPay: $errorMessage${details.isNotEmpty ? ' - $details' : ''}');
      }

      // ✅ Warnings informatifs
      if (data['warning'] != null) {
        debugPrint('⚠️ ${data['warning']}');
      }

      return GeniusPayResult.fromJson(data);

    } on FunctionException catch (e) {
      // ✅ FunctionException : utiliser toString() car pas de propriétés garanties
      final errorMsg = getErrorMessage(e);
      debugPrint('❌ FunctionException: $errorMsg');
      throw Exception('Erreur serveur: $errorMsg');
      
    } on PostgrestException catch (e) {
      debugPrint('❌ PostgrestException: ${e.message}');
      throw Exception('Erreur base de données: ${e.message}');
      
    } on AuthException catch (e) {
      debugPrint('❌ AuthException: ${e.message}');
      throw Exception('Erreur authentification: ${e.message}');
      
    } catch (e) {
      debugPrint('❌ Erreur inattendue: $e');
      if (e is Exception) rethrow;
      throw Exception('Erreur inattendue: $e');
    }
  }

  /// Vérifie le statut d'un paiement par référence (polling de secours)
  Future<String?> checkPaymentStatus(String reference) async {
    try {
      final result = await _supabase
          .from('payments')
          .select('status')
          .eq('reference', reference)
          .maybeSingle();
      return result?['status'] as String?;
    } on PostgrestException catch (e) {
      debugPrint('❌ Erreur vérification statut: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Erreur inattendue: $e');
      return null;
    }
  }
}