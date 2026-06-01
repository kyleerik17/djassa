import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/payment_ui.dart';
import '../../widgets/shop/shop_widgets.dart';
import 'shop_data.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const <OrderPreview>[],
        );

    return ShopScaffold(
      currentIndex: 4,
      title: 'Commandes',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Historique'),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              final pending = order.needsPayment && order.orderUuid.isNotEmpty;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DjassaTheme.primaryWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: DjassaTheme.borderMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.id,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 17,
                                  ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: pending
                                ? Colors.orange.withValues(alpha: .14)
                                : DjassaTheme.accentOrange
                                    .withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            order.status,
                            style: TextStyle(
                              color: pending
                                  ? Colors.orange.shade900
                                  : DjassaTheme.accentOrange,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('${order.items} article(s) • ${order.date}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          formatPrice(order.total),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: DjassaTheme.accentOrange,
                                  ),
                        ),
                        const Spacer(),
                        if (order.orderUuid.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => context.go(
                              '/order-chat/${order.orderUuid}?number=${Uri.encodeComponent(order.id)}',
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: const Text('Discuter'),
                          ),
                        if (!pending)
                          TextButton.icon(
                            onPressed: () => context.go('/support'),
                            icon: const Icon(Icons.help_outline_rounded),
                            label: const Text('Aide'),
                          ),
                      ],
                    ),
                    if (pending) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: DjassaTheme.accentOrange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => _handlePaymentPress(
                            context,
                            ref,
                            order,
                          ),
                          icon: const Icon(Icons.lock_rounded, size: 20),
                          label: const Text('Payer maintenant'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          PromoCard(
            title: "Besoin d'un nouvel article ?",
            subtitle: 'Relancez une commande en quelques secondes.',
            buttonLabel: 'Chercher un article',
            icon: Icons.repeat_rounded,
            onPressed: () => context.go('/search'),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  /// 🔄 Gère le clic sur "Payer maintenant"
  Future<void> _handlePaymentPress(
    BuildContext context,
    WidgetRef ref,
    OrderPreview order,
  ) async {
    // Option A : URL déjà présente (backend enrichi)
    if (order.checkoutUrl != null &&
        order.checkoutUrl!.isNotEmpty &&
        order.reference != null) {
      await _openPaymentWebView(
        context,
        ref,
        checkoutUrl: order.checkoutUrl!,
        reference: order.reference!,
      );
      return;
    }

    // Option B : Créer le paiement via Edge Function (recommandé)
    try {
      if (!context.mounted) return;

      // Loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: DjassaTheme.accentOrange),
        ),
      );

      // Appel à votre Edge Function qui crée le paiement GeniusPay
      // Cette fonction NE doit PAS exposer les clés API côté client
      final user = ref.read(authNotifierProvider).user;
      final savedPayment = ref.read(savedPaymentMethodProvider);
      final customerPhone = (savedPayment?.phone.isNotEmpty == true
              ? savedPayment!.phone
              : user?.phone ?? '')
          .trim();

      if (customerPhone.isEmpty) {
        if (context.mounted) Navigator.of(context).pop();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ajoutez un numéro de téléphone avant de payer.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final payment = await ref.read(shopServiceProvider).createPayment(
            orderId: order.orderUuid.isNotEmpty ? order.orderUuid : order.id,
            amount: order.total,
            provider:
                'checkout', // Sans payment_method → page checkout GeniusPay
            customerPhone: customerPhone,
            customerName: user?.fullName.trim().isEmpty == false
                ? user!.fullName.trim()
                : 'Client Djassa',
          );

      if (context.mounted) Navigator.of(context).pop();

      final checkoutUrl = payment['checkout_url'] as String?;
      final reference = payment['reference'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty || reference == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de générer le lien de paiement.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _openPaymentWebView(
        context,
        ref,
        checkoutUrl: checkoutUrl,
        reference: reference,
      );
    } catch (e) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 🌐 Ouvre la WebView de paiement GeniusPay
  Future<void> _openPaymentWebView(
    BuildContext context,
    WidgetRef ref, {
    required String checkoutUrl,
    required String reference,
  }) async {
    await openOrderPayment(
      context,
      checkoutUrl: checkoutUrl,
      reference: reference,
      // ✅ Pas de apiKey/apiSecret : polling géré via Edge Function
      onPaymentSuccess: () {
        ref.invalidate(ordersProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Paiement réussi !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onPaymentFailed: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Paiement échoué ou annulé.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
  }
}
