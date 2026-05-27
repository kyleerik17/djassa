import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/delivery_tracking_widgets.dart';
import '../../widgets/shop/shop_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _announceStageIfNeeded(
    DeliveryTracking tracking,
    DeliveryTrackingStage stage,
  ) {
    final notifier = ref.read(deliveryTrackingProvider.notifier);
    if (notifier.wasStageAnnounced(tracking.orderId, stage)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await notifier.markStageAnnounced(tracking.orderId, stage);
      if (!mounted) return;
      await showDeliveryStageDialog(
        context,
        tracking: tracking,
        stage: stage,
      );
      if (stage == DeliveryTrackingStage.delivered) {
        await notifier.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider);
    final tracking = ref.watch(deliveryTrackingProvider);
    final now = ref.watch(deliveryTrackingClockProvider).maybeWhen(
          data: (value) => value,
          orElse: DateTime.now,
        );
    final trackingStage = tracking?.stageAt(now);
    final liveSnapshot = tracking == null
        ? null
        : ref.watch(liveDeliveryTrackingProvider(tracking)).maybeWhen(
              data: (value) => value,
              orElse: () => null,
            );
    final clientGpsStatus = tracking == null
        ? null
        : ref.watch(clientLocationPublisherProvider(tracking)).maybeWhen(
              data: (value) => value,
              orElse: () => null,
            );

    if (tracking != null && trackingStage != null) {
      _announceStageIfNeeded(tracking, trackingStage);
      if (trackingStage == DeliveryTrackingStage.delivered) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(deliveryTrackingProvider.notifier).clearIfDelivered();
        });
      }
    }

    return ShopScaffold(
      currentIndex: 0,
      title: 'Djassa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour ${user?.fullName ?? 'à vous'} 👋',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Articles fiables, livraison rapide.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.go('/profile'),
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor:
                      DjassaTheme.accentOrange.withValues(alpha: .13),
                  child: const Icon(
                    Icons.person_rounded,
                    color: DjassaTheme.accentOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (tracking != null &&
              trackingStage != null &&
              trackingStage != DeliveryTrackingStage.delivered) ...[
            DeliveryTrackingCard(
              tracking: tracking,
              stage: trackingStage,
              now: now,
              snapshot: liveSnapshot,
              clientGpsStatus: clientGpsStatus,
              onTap: () => showDeliveryStageDialog(
                context,
                tracking: tracking,
                stage: trackingStage,
              ),
            ),
            const SizedBox(height: 18),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => context.go('/search'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: DjassaTheme.primaryWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: DjassaTheme.borderMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rechercher un article, une marque...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const Icon(
                    Icons.tune_rounded,
                    color: DjassaTheme.accentOrange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          PromoCard(
            title: 'Promos du moment',
            subtitle:
                'Découvrez les meilleures offres sélectionnées pour vous.',
            buttonLabel: 'Voir les promos',
            icon: Icons.local_offer_rounded,
            onPressed: () => context.go('/categories'),
          ),
          const SizedBox(height: 24),
          SectionTitle(
            title: 'Rayons populaires',
            actionLabel: 'Tout voir',
            onAction: () => context.go('/categories'),
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            loading: () => const SizedBox(
              height: 154,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 154,
              child: Center(
                child: Text(
                  'Impossible de charger les catégories.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            data: (categories) => categories.isEmpty
                ? const SizedBox(
                    height: 154,
                    child: Center(child: Text('Aucune catégorie disponible.')),
                  )
                : SizedBox(
                    height: 154,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return CategoryPill(
                          category: category,
                          onTap: () => context.go(
                            '/search?category=${category.name}',
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          SectionTitle(
            title: 'Meilleures ventes',
            actionLabel: 'Recherche',
            onAction: () => context.go('/search'),
          ),
          const SizedBox(height: 12),
          productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Impossible de charger les produits.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            data: (products) => products.isEmpty
                ? const Center(child: Text('Aucun produit disponible.'))
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: .67,
                    ),
                    itemBuilder: (context, index) {
                      return ProductCard(product: products[index]);
                    },
                  ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}
