import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/payment_ui.dart';
import '../../widgets/shop/payment_webview.dart';
import '../../widgets/shop/shop_widgets.dart';
import 'shop_data.dart';

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

  String _friendlyMessage(Object e) {
    final raw = e is Exception
        ? e.toString().replaceFirst('Exception: ', '')
        : 'Erreur inattendue. Veuillez réessayer.';

    // 🎯 Message spécifique pour GeniusPay down
    if (raw.contains('503') || raw.contains('Service Unavailable')) {
      return 'Le service de paiement est temporairement indisponible. Veuillez réessayer dans quelques minutes.';
    }

    final isTechnical = raw.contains('FunctionException') ||
        raw.contains('PostgrestException') ||
        raw.contains('status:');
    if (isTechnical) {
      return 'Échec du paiement. Réessayez ou choisissez un autre moyen.';
    }
    return raw;
  }

  Future<void> _pay() async {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) {
      context.go('/login');
      return;
    }

    final saved = ref.read(savedPaymentMethodProvider);
    final paymentInfo = await showMobileMoneyPaymentDialog(
      context,
      prefilledPhone: saved?.phone ?? user.phone,
      initialProvider: saved?.provider ?? 'wave',
    );
    if (paymentInfo == null || !mounted) return;

    final phone = paymentInfo['phone']!;
    final provider = paymentInfo['provider']!;

    setState(() => _isLoading = true);
    try {
      await ref.read(savedPaymentMethodProvider.notifier).save(
            provider: provider,
            phone: phone,
          );

      final payment = await ref.read(shopServiceProvider).createPayment(
            orderId: widget.orderId,
            amount: widget.amount,
            provider: provider,
            customerPhone: phone,
            customerName:
                user.fullName.trim().isEmpty ? null : user.fullName.trim(),
          );

      final checkoutUrl = payment['checkout_url'] as String?;
      final reference = payment['reference']?.toString() ?? '';
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('URL de paiement introuvable.');
      }

      if (!mounted) return;

      final geniusPay = ref.read(geniusPayServiceProvider);
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentWebView(
            paymentUrl: checkoutUrl,
            reference: reference,
            checkStatus: geniusPay.checkPaymentStatus,
            onPaymentSuccess: () => ref.invalidate(ordersProvider),
          ),
        ),
      );

      if (!mounted) return;

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Paiement confirmé. Merci !'),
            backgroundColor: DjassaTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
        context.go('/orders');
      } else if (success == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Paiement annulé ou non confirmé.'),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyMessage(e)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedPaymentMethodProvider);

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
                  widget.orderNumber != null
                      ? 'Commande ${widget.orderNumber}'
                      : 'Finaliser la commande',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DjassaTheme.primaryWhite,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paiement sécurisé via GeniusPay',
                  style: TextStyle(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .72),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  formatPrice(widget.amount),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: DjassaTheme.accentOrange,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (saved != null && saved.isConfigured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
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
                      Icons.account_balance_wallet_outlined,
                      color: DjassaTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paymentProviderLabel(saved.provider),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        Text(saved.phone),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _pay,
                    child: const Text('Modifier'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
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
                        'Moyens acceptés',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Wave · Orange Money · MTN · Moov',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ CORRECTION : Spacer() remplacé par SizedBox fixe
          // Dans un SingleChildScrollView/Viewport, la hauteur est infinie.
          // Spacer() ne peut pas calculer sa taille dans un espace infini → CRASH
          const SizedBox(height: 40),

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
              onPressed: _isLoading ? null : _pay,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_rounded),
              label: Text(
                _isLoading ? 'Ouverture…' : 'Payer maintenant',
              ),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}
