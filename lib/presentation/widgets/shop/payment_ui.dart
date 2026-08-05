import 'package:flutter/material.dart';

import '../../../core/theme/djassa_theme.dart';
import 'payment_launcher.dart';

const List<Map<String, String>> kMobileMoneyProviders = [
  {'label': 'Wave',         'value': 'wave',        'icon': 'assets/icons/wave.jpg'},
  {'label': 'Orange Money', 'value': 'orange_money', 'icon': 'assets/icons/orange_money.png'},
  {'label': 'MTN Money',    'value': 'mtn_money',    'icon': 'assets/icons/mtn_money.png'},
  {'label': 'Moov Money',   'value': 'moov_money',   'icon': 'assets/icons/moov_money.png'},
];

/// Couleur de marque associée à chaque opérateur, utilisée pour le badge de
/// secours (tant que le vrai logo n'est pas encore dans assets/icons/) et
/// pour teinter légèrement la carte sélectionnée.
const Map<String, Color> kMobileMoneyBrandColors = {
  'wave': Color(0xFF1DC2E8),
  'orange_money': Color(0xFFFF7900),
  'mtn_money': Color(0xFFFFCC00),
  'moov_money': Color(0xFF003DA5),
};

String paymentProviderLabel(String value) {
  for (final p in kMobileMoneyProviders) {
    if (p['value'] == value) return p['label'] ?? value;
  }
  return value;
}

Color paymentProviderColor(String value) {
  return kMobileMoneyBrandColors[value] ?? DjassaTheme.accentOrange;
}

/// Logo de l'opérateur avec repli propre si l'asset n'existe pas encore
/// (le fichier doit être ajouté dans assets/icons/ et déclaré dans
/// pubspec.yaml sous flutter/assets).
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({
    super.key,
    required this.provider,
    this.size = 28,
  });

  final String provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconPath = kMobileMoneyProviders.firstWhere(
      (p) => p['value'] == provider,
      orElse: () => const {},
    )['icon'];
    final color = paymentProviderColor(provider);
    final initial = paymentProviderLabel(provider).isNotEmpty
        ? paymentProviderLabel(provider)[0]
        : '?';

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: color.withValues(alpha: .12),
        child: iconPath == null
            ? Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: size * .45,
                  ),
                ),
              )
            : Image.asset(
                iconPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: size * .45,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
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
                  final value = p['value']!;
                  final isSelected = selectedProvider == value;
                  final brandColor = paymentProviderColor(value);
                  return GestureDetector(
                    onTap: () =>
                        setStateDialog(() => selectedProvider = value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? brandColor.withValues(alpha: .12)
                            : DjassaTheme.secondaryWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? brandColor
                              : DjassaTheme.borderMedium,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProviderLogo(provider: value, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            p['label']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isSelected
                                  ? brandColor
                                  : DjassaTheme.textPrimary,
                            ),
                          ),
                        ],
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