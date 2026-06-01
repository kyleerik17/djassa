import 'package:flutter/material.dart';

import '../../../core/theme/djassa_theme.dart';
import 'payment_launcher.dart';

const List<Map<String, String>> kMobileMoneyProviders = [
  {'label': 'Wave',         'value': 'wave',        'icon': '🌊'},
  {'label': 'Orange Money', 'value': 'orange_money', 'icon': '🟠'},
  {'label': 'MTN Money',    'value': 'mtn_money',    'icon': '🟡'},
  {'label': 'Moov Money',   'value': 'moov_money',   'icon': '🔵'},
];

String paymentProviderLabel(String value) {
  for (final p in kMobileMoneyProviders) {
    if (p['value'] == value) return p['label'] ?? value;
  }
  return value;
}

/// Ouvre le paiement GeniusPay via WebView.
///
/// 🔐 Sécurité : Les clés API (apiKey/apiSecret) ne doivent JAMAIS
/// être exposées côté client. Le polling du statut doit passer par
/// votre Edge Function/backend qui détient les clés secrètes.
///
/// [checkoutUrl] → URL retournee par POST /payments (sans payment_method)
/// [reference]   → Référence GeniusPay (format: MTX-XXXXXXXXXX)
Future<bool?> openOrderPayment(
  BuildContext context, {
  required String checkoutUrl,
  required String reference,
  // apiKey/apiSecret retirés : gestion sécurisée via backend uniquement
  VoidCallback? onPaymentSuccess,
  VoidCallback? onPaymentFailed,
  VoidCallback? onPaymentComplete,
}) async {
  return PaymentLauncher.open(
    context,
    paymentUrl: checkoutUrl,
    reference: reference,
    // Pas de clés API exposées côté client
    onPaymentSuccess: onPaymentSuccess,
    onPaymentFailed: onPaymentFailed,
    onPaymentComplete: onPaymentComplete,
  );
}

/// Dialogue de sélection opérateur + numéro Mobile Money.
Future<Map<String, String>?> showMobileMoneyPaymentDialog(
  BuildContext context, {
  String? prefilledPhone,
  String initialProvider = 'wave',
}) async {
  final controller = TextEditingController(text: prefilledPhone ?? '');
  var selectedProvider = initialProvider;
  if (!kMobileMoneyProviders.any((p) => p['value'] == selectedProvider)) {
    selectedProvider = 'wave';
  }

  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .12),
              child: const Icon(
                Icons.payments_rounded,
                color: DjassaTheme.accentOrange,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Mobile Money')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choisissez votre opérateur et le numéro à débiter.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Opérateur',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kMobileMoneyProviders.map((p) {
                  final isSelected = selectedProvider == p['value'];
                  return GestureDetector(
                    onTap: () =>
                        setStateDialog(() => selectedProvider = p['value']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DjassaTheme.accentOrange.withValues(alpha: .12)
                            : DjassaTheme.secondaryWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? DjassaTheme.accentOrange
                              : DjassaTheme.borderMedium,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '${p['icon']}  ${p['label']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isSelected
                              ? DjassaTheme.accentOrange
                              : DjassaTheme.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  hintText: 'Ex: 07 00 00 00 00',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DjassaTheme.accentOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final phone = controller.text.trim();
              if (phone.length < 8) return;
              Navigator.of(ctx).pop({
                'phone': phone,
                'provider': selectedProvider,
              });
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    ),
  );
}