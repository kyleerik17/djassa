import 'package:djassa/core/services/geniuspay_service.dart';
import 'package:djassa/presentation/screens/shop/shop_data.dart';
import 'package:djassa/presentation/widgets/shop/payment_webview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';

/// Opérateurs Mobile Money disponibles
const List<Map<String, String>> _providers = [
  {'label': 'Wave',         'value': 'wave',         'icon': '🌊'},
  {'label': 'Orange Money', 'value': 'orange_money',  'icon': '🟠'},
  {'label': 'MTN Money',    'value': 'mtn_money',     'icon': '🟡'},
  {'label': 'Moov Money',   'value': 'moov_money',    'icon': '🔵'},
];

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    this.orderNumber,
  });

  final String orderId;
  final int amount;
  final String? orderNumber;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isLoading = false;

  /// Dialog pour choisir l'opérateur et saisir le numéro Mobile Money.
  /// Retourne {'phone': ..., 'provider': ...} ou null si annulé.
  Future<Map<String, String>?> _askPaymentInfo(String? prefilled) async {
    final controller = TextEditingController(text: prefilled ?? '');
    String selectedProvider = 'wave';

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    DjassaTheme.accentOrange.withValues(alpha: .12),
                child: const Icon(
                  Icons.phone_rounded,
                  color: DjassaTheme.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Paiement Mobile Money')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisissez votre opérateur et entrez le numéro à débiter.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Sélection de l'opérateur
              const Text(
                'Opérateur',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _providers.map((p) {
                  final isSelected = selectedProvider == p['value'];
                  return GestureDetector(
                    onTap: () => setStateDialog(
                        () => selectedProvider = p['value']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DjassaTheme.accentOrange.withValues(alpha: .12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? DjassaTheme.accentOrange
                              : Colors.grey.shade300,
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
                              : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Numéro de téléphone
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
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
                  'phone':    phone,
                  'provider': selectedProvider,
                });
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCheckout() async {
  final user = ref.read(authNotifierProvider).user;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez vous connecter')),
    );
    return;
  }

  final paymentInfo = await _askPaymentInfo(user.phone);
  if (paymentInfo == null || !mounted) return;

  final phone = paymentInfo['phone']!;
  final provider = paymentInfo['provider']!;

  setState(() => _isLoading = true);
  
  try {
    final geniusPayService = GeniusPayService(Supabase.instance.client);
    
    final result = await geniusPayService.createPayment(
      orderId: widget.orderId,
      provider: provider,
      customerPhone: phone,
      customerName: user.fullName,
    );

    if (!mounted) return;

    final paymentSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWebView(
          paymentUrl: result.checkoutUrl,
          reference: result.reference,
          onPaymentSuccess: () {
            // ✅ Rafraîchir uniquement ordersProvider (le seul qui existe)
            ref.invalidate(ordersProvider);
          },
        ),
      ),
    );

    if (!mounted) return;

    if (paymentSuccess == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Paiement confirmé !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      context.go('/orders');
    } else if (paymentSuccess == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paiement annulé ou échoué'),
          backgroundColor: Colors.orange,
        ),
      );
    }

  } catch (e) {
    if (!mounted) return;
    
    String message = 'Erreur : $e';
    if (e.toString().contains('Session invalide')) {
      message = 'Session expirée, veuillez vous reconnecter';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
  @override
  Widget build(BuildContext context) {
    return ShopScaffold(
      currentIndex: 2,
      title: 'Paiement',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: DjassaTheme.primaryBlack,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.orderNumber == null
                      ? 'Commande confirmée'
                      : 'Commande ${widget.orderNumber}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DjassaTheme.primaryWhite,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vous allez être redirigé vers la page de paiement sécurisée GeniusPay.',
                  style: TextStyle(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .72),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  formatPrice(widget.amount),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: DjassaTheme.accentOrange,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DjassaTheme.primaryWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DjassaTheme.borderMedium),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      DjassaTheme.accentOrange.withValues(alpha: .12),
                  child: const Icon(
                    Icons.security_rounded,
                    color: DjassaTheme.accentOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paiement sécurisé',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Wave · Orange Money · MTN · Moov · Carte bancaire',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: DjassaTheme.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isLoading ? null : _openCheckout,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.open_in_browser_rounded),
              label: Text(
                _isLoading ? 'Ouverture...' : 'Payer maintenant',
              ),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}