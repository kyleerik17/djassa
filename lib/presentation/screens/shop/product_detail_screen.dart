import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';
import 'shop_data.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  final String? productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    if (productsAsync.isLoading) {
      return const ShopScaffold(
        currentIndex: 1,
        title: 'Détail article',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (productsAsync.hasError) {
      return ShopScaffold(
        currentIndex: 1,
        title: 'Détail article',
        showBackButton: true,
        child: EmptyStateCard(
          icon: Icons.cloud_off_rounded,
          title: 'Article indisponible',
          message: 'Impossible de charger les articles du serveur.',
          buttonLabel: 'Réessayer',
          onPressed: () => ref.invalidate(productsProvider),
        ),
      );
    }

    final products = productsAsync.valueOrNull ?? [];
    ShopProduct? matchedProduct;
    for (final item in products) {
      if (item.id == widget.productId) {
        matchedProduct = item;
        break;
      }
    }

    if (matchedProduct == null) {
      return ShopScaffold(
        currentIndex: 1,
        title: 'Détail article',
        showBackButton: true,
        child: EmptyStateCard(
          icon: Icons.inventory_2_outlined,
          title: 'Article introuvable',
          message: 'Cet article n’est plus disponible dans le catalogue.',
          buttonLabel: 'Retour recherche',
          onPressed: () => context.go('/search'),
        ),
      );
    }

    final product = matchedProduct;
    final maxQuantity = product.stock <= 0 ? 99 : product.stock;

    return ShopScaffold(
      currentIndex: 1,
      title: 'Détail article',
      showBackButton: true,
      actions: [
        IconButton(
          onPressed: () => context.go('/favorites'),
          icon: const Icon(Icons.favorite_border_rounded),
        ),
        const SizedBox(width: 8),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'product-${product.id}',
            child: Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                color: DjassaTheme.primaryWhite,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: DjassaTheme.borderMedium),
                boxShadow: DjassaTheme.shadowLight,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      product.icon,
                      size: 118,
                      color: DjassaTheme.primaryBlack.withValues(alpha: .82),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: DjassaTheme.accentOrange,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        product.badge,
                        style: const TextStyle(
                          color: DjassaTheme.primaryWhite,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            product.category,
            style: const TextStyle(
              color: DjassaTheme.accentOrange,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(product.name, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: DjassaTheme.accentOrange),
              const SizedBox(width: 4),
              Text('${product.rating} • ${product.stock} en stock'),
              const Spacer(),
              if (product.compatibility.trim().isNotEmpty)
                Flexible(
                  child: Text(
                    product.compatibility,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoCard(product: product),
          const SizedBox(height: 18),
          _QuantitySelector(
            quantity: _quantity,
            maxQuantity: maxQuantity,
            onMinus: _quantity <= 1 ? null : () => setState(() => _quantity--),
            onPlus: _quantity >= maxQuantity
                ? null
                : () => setState(() => _quantity++),
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Articles similaires'),
          const SizedBox(height: 12),
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products
                  .where((item) => item.id != product.id)
                  .take(4)
                  .length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final related = products
                    .where((item) => item.id != product.id)
                    .take(4)
                    .toList()[index];
                return SizedBox(
                  width: 172,
                  child: ProductCard(product: related, compact: true),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => context.go('/favorites'),
                  icon: const Icon(Icons.favorite_border_rounded),
                  label: const Text('Favori'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: DjassaTheme.accentOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: product.stock == 0
                      ? null
                      : () {
                          ref
                              .read(cartProvider.notifier)
                              .add(product, quantity: _quantity);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$_quantity article(s) ajouté(s) au panier',
                              ),
                              action: SnackBarAction(
                                label: 'Voir',
                                onPressed: () => context.go('/cart'),
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.shopping_bag_rounded),
                  label: const Text('Ajouter'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.maxQuantity,
    required this.onMinus,
    required this.onPlus,
  });

  final int quantity;
  final int maxQuantity;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantité',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text('Maximum disponible : $maxQuantity'),
              ],
            ),
          ),
          _RoundQtyButton(icon: Icons.remove_rounded, onPressed: onMinus),
          Container(
            width: 48,
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          _RoundQtyButton(icon: Icons.add_rounded, onPressed: onPlus),
        ],
      ),
    );
  }
}

class _RoundQtyButton extends StatelessWidget {
  const _RoundQtyButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: DjassaTheme.backgroundSecondary,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.product});

  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Prix', value: formatPrice(product.price)),
          if (product.oldPrice > 0) ...[
            const Divider(height: 24),
            _InfoRow(
                label: 'Ancien prix', value: formatPrice(product.oldPrice)),
          ],
          const Divider(height: 24),
          const _InfoRow(label: 'Livraison', value: '24h - 48h à Abidjan'),
          const Divider(height: 24),
          const _InfoRow(label: 'Garantie', value: 'Article vérifié'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
