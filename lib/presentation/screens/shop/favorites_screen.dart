import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';
import 'shop_data.dart';

// ── Favorites provider ────────────────────────────────────────────────────────

class FavoritesNotifier extends StateNotifier<List<ShopProduct>> {
  FavoritesNotifier(super.initial);

  void remove(ShopProduct product) {
    state = state.where((p) => p.id != product.id).toList();
  }

  void add(ShopProduct product) {
    if (!state.any((p) => p.id == product.id)) {
      state = [...state, product];
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<ShopProduct>>((ref) {
  final products = ref.watch(productsProvider).maybeWhen(
        data: (value) => value,
        orElse: () => shopProducts,
      );
  return FavoritesNotifier(products.take(3).toList());
});

// ── Screen ────────────────────────────────────────────────────────────────────

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteProducts = ref.watch(favoritesProvider);

    return ShopScaffold(
      currentIndex: 3,
      title: 'Favoris',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'Vos articles sauvegardés',
            actionLabel: '${favoriteProducts.length}',
          ),
          const SizedBox(height: 12),
          if (favoriteProducts.isEmpty)
            EmptyStateCard(
              icon: Icons.favorite_border_rounded,
              title: 'Aucun favori',
              message: 'Gardez vos articles importants sous la main.',
              buttonLabel: 'Explorer',
              onPressed: () => context.go('/search'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: favoriteProducts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = favoriteProducts[index];
                return Dismissible(
                  key: ValueKey(product.id),
                  direction: DismissDirection.endToStart,
                  background: const _SwipeDeleteBackground(),
                  onDismissed: (_) {
                    ref.read(favoritesProvider.notifier).remove(product);
                    _showUndoSnackbar(context, ref, product);
                  },
                  child: ProductTile(
                    product: product,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bouton retirer des favoris
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: .12),
                            foregroundColor: Colors.red,
                          ),
                          tooltip: 'Retirer des favoris',
                          onPressed: () {
                            ref
                                .read(favoritesProvider.notifier)
                                .remove(product);
                            _showUndoSnackbar(context, ref, product);
                          },
                          icon: const Icon(Icons.favorite_rounded),
                        ),
                        const SizedBox(width: 6),
                        // Bouton ajouter au panier
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: DjassaTheme.accentOrange
                                .withValues(alpha: .14),
                            foregroundColor: DjassaTheme.accentOrange,
                          ),
                          tooltip: 'Ajouter au panier',
                          onPressed: () {
                            ref.read(cartProvider.notifier).add(product);
                            context.go('/cart');
                          },
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          PromoCard(
            title: 'Vos favoris peuvent partir vite',
            subtitle: 'Réservez maintenant les articles avec peu de stock.',
            buttonLabel: 'Voir le panier',
            icon: Icons.favorite_rounded,
            onPressed: () => context.go('/cart'),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  void _showUndoSnackbar(
      BuildContext context, WidgetRef ref, ShopProduct product) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('« ${product.name} » retiré des favoris'),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () => ref.read(favoritesProvider.notifier).add(product),
          ),
        ),
      );
  }
}

// ── Fond swipe ────────────────────────────────────────────────────────────────

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_rounded, color: Colors.red),
          SizedBox(height: 4),
          Text(
            'Retirer',
            style: TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}