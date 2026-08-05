import 'package:djassa/presentation/screens/profile/widgets/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';

import '../../../domain/order_progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/payment_ui.dart';
import '../../widgets/shop/shop_widgets.dart';
import 'shop_data.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  // Amélioration #9 : évite le double-tap et affiche un état de chargement
  // sur le bouton concerné plutôt qu'un dialog plein écran bloquant.
  String? _payingOrderId;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return ShopScaffold(
      currentIndex: 4,
      title: 'Commandes',
      showBackButton: true,
      // Amélioration #3 : pull-to-refresh, cohérent avec l'écran Profil.
      onRefresh: () => ref.refresh(ordersProvider.future),
      child: ordersAsync.when(
        // Amélioration #2 : loading / erreur / vide sont maintenant trois
        // états visuellement distincts au lieu d'être tous traités comme
        // "aucune commande".
        loading: () => const _OrdersLoading(),
        error: (error, _) => _OrdersError(
          onRetry: () => ref.invalidate(ordersProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return _OrdersEmpty(
              onBrowse: () => context.go(AppConstants.searchRoute),
            );
          }
          return _OrdersList(
            orders: _sortedOrders(orders),
            payingOrderId: _payingOrderId,
            onPay: (order) => _handlePaymentPress(context, ref, order),
          );
        },
      ),
    );
  }

  /// Amélioration #6 : fait remonter les commandes qui nécessitent une
  /// action (paiement en attente) tout en haut de la liste, pour qu'elles
  /// ne soient pas noyées parmi des commandes déjà livrées.
  List<OrderPreview> _sortedOrders(List<OrderPreview> orders) {
    final sorted = [...orders];
    sorted.sort((a, b) {
      final aPending = a.needsPayment && a.orderUuid.isNotEmpty;
      final bPending = b.needsPayment && b.orderUuid.isNotEmpty;
      if (aPending == bPending) return 0;
      return aPending ? -1 : 1;
    });
    return sorted;
  }

  /// Gère le clic sur "Payer maintenant"
  Future<void> _handlePaymentPress(
    BuildContext context,
    WidgetRef ref,
    OrderPreview order,
  ) async {
    if (_payingOrderId != null) return; // évite le double-tap
    setState(() => _payingOrderId = order.id);

    try {
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

      // Option B : créer le paiement via Edge Function (recommandé)
      final user = ref.read(authNotifierProvider).user;
      final savedPayment = ref.read(savedPaymentMethodProvider);
      final customerPhone = (savedPayment?.phone.isNotEmpty == true
              ? savedPayment!.phone
              : user?.phone ?? '')
          .trim();

      if (customerPhone.isEmpty) {
        if (context.mounted) {
          AppSnackbar.error(
            context,
            'Ajoutez un numéro de téléphone avant de payer.',
          );
        }
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

      final checkoutUrl = payment['checkout_url'] as String?;
      final reference = payment['reference'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty || reference == null) {
        if (context.mounted) {
          AppSnackbar.error(
            context,
            'Impossible de générer le lien de paiement.',
          );
        }
        return;
      }

      if (context.mounted) {
        await _openPaymentWebView(
          context,
          ref,
          checkoutUrl: checkoutUrl,
          reference: reference,
        );
      }
    } catch (_) {
      // Amélioration #4 : message générique, pas l'exception brute
      // (e.toString() peut exposer des détails techniques illisibles /
      // sensibles à l'utilisateur final).
      if (context.mounted) {
        AppSnackbar.error(
          context,
          "Une erreur est survenue pendant le paiement. Réessayez.",
        );
      }
    } finally {
      if (mounted) setState(() => _payingOrderId = null);
    }
  }

  /// Ouvre la WebView de paiement GeniusPay
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
      // Pas de apiKey/apiSecret : polling géré via Edge Function
      onPaymentSuccess: () {
        ref.invalidate(ordersProvider);
        if (context.mounted) {
          AppSnackbar.success(context, 'Paiement réussi !');
        }
      },
      onPaymentFailed: () {
        if (context.mounted) {
          AppSnackbar.error(context, 'Paiement échoué ou annulé.');
        }
      },
    );
  }
}

// ── États : loading / erreur / vide ─────────────────────────────────────────

class _OrdersLoading extends StatelessWidget {
  const _OrdersLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Historique'),
        const SizedBox(height: 12),
        for (var i = 0; i < 3; i++) ...[
          const _OrderCardSkeleton(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _OrderCardSkeleton extends StatefulWidget {
  const _OrderCardSkeleton();

  @override
  State<_OrderCardSkeleton> createState() => _OrderCardSkeletonState();
}

class _OrderCardSkeletonState extends State<_OrderCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(begin: .35, end: .7)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: DjassaTheme.borderMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: DjassaTheme.borderMedium,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 180,
              height: 12,
              decoration: BoxDecoration(
                color: DjassaTheme.borderMedium,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 90,
              height: 16,
              decoration: BoxDecoration(
                color: DjassaTheme.borderMedium,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Historique'),
        const SizedBox(height: 12),
        EmptyStateCard(
          icon: Icons.wifi_off_rounded,
          title: 'Impossible de charger vos commandes',
          message:
              'Vérifiez votre connexion internet et réessayez.',
          buttonLabel: 'Réessayer',
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Historique'),
        const SizedBox(height: 12),
        EmptyStateCard(
          icon: Icons.receipt_long_rounded,
          title: 'Aucune commande pour le moment',
          message: 'Vos commandes apparaîtront ici une fois passées.',
          buttonLabel: 'Chercher un article',
          onPressed: onBrowse,
        ),
      ],
    );
  }
}

// ── Liste ────────────────────────────────────────────────────────────────

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.payingOrderId,
    required this.onPay,
  });

  final List<OrderPreview> orders;
  final String? payingOrderId;
  final void Function(OrderPreview order) onPay;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            return _OrderCard(
              order: order,
              isPaying: payingOrderId == order.id,
              onPay: () => onPay(order),
            );
          },
        ),
        const SizedBox(height: 24),
        PromoCard(
          title: "Besoin d'un nouvel article ?",
          subtitle: 'Relancez une commande en quelques secondes.',
          buttonLabel: 'Chercher un article',
          icon: Icons.repeat_rounded,
          onPressed: () => context.go(AppConstants.searchRoute),
        ),
        const SizedBox(height: 88),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isPaying,
    required this.onPay,
  });

  final OrderPreview order;
  final bool isPaying;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final pending = order.needsPayment && order.orderUuid.isNotEmpty;

    // Amélioration #5 : réutilise les couleurs/étapes de OrderProgressInfo
    // (déjà utilisées dans le profil) pour que "Confirmée", "En livraison"
    // et "Livrée" soient visuellement distinctes au lieu d'être toutes
    // orange.
    final step = OrderProgressInfo.stepFromStatus(order.status);
    final stepInfo = OrderProgressInfo.forStep(step);
    final badgeColor = pending ? Colors.orange : stepInfo.color;
    final badgeLabel = pending ? order.status : stepInfo.title;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: pending
              ? Colors.orange.withValues(alpha: .4)
              : DjassaTheme.borderMedium,
          width: pending ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order.id,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                  color: badgeColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: DjassaTheme.accentOrange,
                    ),
              ),
              const Spacer(),
              if (order.orderUuid.isNotEmpty)
                TextButton.icon(
                  onPressed: () => context.go(
                    AppConstants.orderChatLocation(
                      order.orderUuid,
                      orderNumber: order.id,
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Discuter'),
                ),
              if (!pending)
                TextButton.icon(
                  onPressed: () => context.go(AppConstants.supportRoute),
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
                // Amélioration #9 : bouton désactivé + spinner pendant le
                // paiement, plus de dialog plein écran bloquant.
                onPressed: isPaying ? null : onPay,
                icon: isPaying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DjassaTheme.primaryWhite,
                        ),
                      )
                    : const Icon(Icons.lock_rounded, size: 20),
                label: Text(isPaying ? 'Ouverture...' : 'Payer maintenant'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}