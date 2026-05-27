import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';
import 'shop_data.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).maybeWhen(
          data: (value) => value,
          orElse: () => orderPreviews,
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
                            color:
                                DjassaTheme.accentOrange.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            order.status,
                            style: const TextStyle(
                              color: DjassaTheme.accentOrange,
                              fontWeight: FontWeight.w800,
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
                        TextButton.icon(
                          onPressed: () => context.go('/support'),
                          icon: const Icon(Icons.help_outline_rounded),
                          label: const Text('Aide'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          PromoCard(
            title: 'Besoin d’un nouvel article ?',
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
}
