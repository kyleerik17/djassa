import 'dart:convert';
import 'package:djassa/presentation/widgets/shop/payment_webview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Endpoint de votre Edge Function pour le polling sécurisé
const String kPaymentStatusProxyUrl =
    'https://wtfygkiuzjmndnirtevy.supabase.co/functions/v1/payment-status';

/// Vérifie le statut via votre Edge Function
/// Retourne : 'completed' | 'failed' | 'cancelled' | 'expired' | 'pending' | 'processing' | null
Future<String?> geniusPayStatusChecker(String reference) async {
  try {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    final uri = Uri.parse('$kPaymentStatusProxyUrl/$reference');
    final headers = {
      'Content-Type': 'application/json',
      if (session?.accessToken != null)
        'Authorization': 'Bearer ${session!.accessToken}',
    };

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Log utile pour voir ce que l'Edge Function renvoie vraiment
      debugPrint('✅ STATUS REÇU pour $reference: ${body['status']} (source: ${body['source'] ?? 'edge'})');
      
      return (body['status'] as String?)?.toLowerCase();
    }

    debugPrint('⚠️ Payment status: HTTP ${response.statusCode} pour $reference');
    return null;
  } catch (e) {
    debugPrint('❌ Payment status: erreur réseau pour $reference → $e');
    return null;
  }
}

class PaymentLauncher {
  const PaymentLauncher._();

  static Future<bool?> open(
    BuildContext context, {
    required String paymentUrl,
    required String reference,
    VoidCallback? onPaymentComplete,
    VoidCallback? onPaymentSuccess,
    VoidCallback? onPaymentFailed,
  }) async {
    if (!paymentUrl.startsWith('http')) {
      debugPrint('❌ PaymentLauncher: URL invalide → $paymentUrl');
      return null;
    }

    // ─── FLUTTER WEB ───
    if (kIsWeb) {
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      }

      // BOUCLE SÉCURISÉE AVEC TIMEOUT POUR LE WEB
      const int maxAttempts = 40; // 40 * 5 secondes = 200 secondes (3 min 20)
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 5));
        
        final status = (await geniusPayStatusChecker(reference))?.toLowerCase();
        
        switch (status) {
          case 'completed':
          case 'success':
          case 'paid':
            debugPrint('🎉 Paiement réussi (Web)');
            onPaymentSuccess?.call();
            onPaymentComplete?.call();
            return true;
            
          case 'failed':
          case 'error':
          case 'cancelled':
          case 'expired':
            debugPrint('🚫 Paiement échoué ou annulé (Web)');
            onPaymentFailed?.call();
            onPaymentComplete?.call();
            return false;
            
          case 'pending':
          case 'processing':
            debugPrint('⏳ Paiement en cours... (tentative ${attempt + 1}/$maxAttempts)');
            continue; // Continue la boucle d'attente
            
          default:
            debugPrint('⚠️ Statut inconnu ou null, on continue d\'attendre...');
            continue;
        }
      }
      
      debugPrint('⏰ Délai d\'attente dépassé pour le polling Web.');
      return null;
    }

    // ─── ANDROID / iOS (MOBILE) ───
    if (!context.mounted) return null;

    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentWebView(
          paymentUrl: paymentUrl,
          reference: reference,
          checkStatus: (ref) => geniusPayStatusChecker(ref),
          onPaymentComplete: onPaymentComplete,
          onPaymentSuccess: onPaymentSuccess,
          onPaymentFailed: onPaymentFailed,
        ),
      ),
    );
  }
}