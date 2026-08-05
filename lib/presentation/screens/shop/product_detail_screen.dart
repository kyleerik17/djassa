import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
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
        showSellButton: false,
        currentIndex: 1,
        title: 'DÃ©tail article',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (productsAsync.hasError) {
      return ShopScaffold(
        currentIndex: 1,
        title: 'DÃ©tail article',
        showBackButton: true,
        child: EmptyStateCard(
          icon: Icons.cloud_off_rounded,
          title: 'Article indisponible',
          message: 'Impossible de charger les articles du serveur.',
          buttonLabel: 'RÃ©essayer',
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
        title: 'DÃ©tail article',
        showBackButton: true,
        child: EmptyStateCard(
          icon: Icons.inventory_2_outlined,
          title: 'Article introuvable',
          message: 'Cet article nâ€™est plus disponible dans le catalogue.',
          buttonLabel: 'Retour recherche',
          onPressed: () => context.go(AppConstants.searchRoute),
        ),
      );
    }

    final product = matchedProduct;
    final maxQuantity = product.stock <= 0 ? 1 : product.stock;
    final isFavorite = ref.watch(favoritesProvider).any(
          (favorite) => favorite.id == product.id,
        );

    return ShopScaffold(
      currentIndex: 1,
      title: 'DÃ©tail article',
      showBackButton: true,
      showSellButton: false,
      actions: [
        IconButton(
          tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          ),
          onPressed: () => _toggleFavorite(product),
        ),
        const SizedBox(width: 8),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'product-${product.id}',
            child: Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: DjassaTheme.primaryWhite,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: DjassaTheme.borderMedium),
                boxShadow: DjassaTheme.shadowLight,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: ProductMedia(
                        product: product,
                        iconSize: 160,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: DjassaTheme.accentOrange,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                  if (product.condition.isNotEmpty &&
                      product.condition != 'Neuf')
                    Positioned(
                      left: 18,
                      bottom: 18,
                      child: _PillTag(
                        label: product.condition,
                        color: product.condition == 'ReconditionnÃ©'
                            ? Colors.blueGrey
                            : Colors.brown,
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
          ProductCreatorLine(product: product),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: DjassaTheme.accentOrange),
              const SizedBox(width: 4),
              Text('${product.rating} â€¢ ${product.stock} en stock'),
              const Spacer(),
              if (product.partPosition.trim().isNotEmpty)
                _PillTag(
                  label: product.partPosition,
                  color: DjassaTheme.accentOrange,
                  outlined: true,
                ),
            ],
          ),
          if (product.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              product.description,
              style: const TextStyle(
                color: DjassaTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _InfoCard(product: product),
          const SizedBox(height: 18),
          _MarketplacePromiseCard(product: product),
          const SizedBox(height: 18),
          _SellerCard(product: product),
          if (_hasAnySpec(product)) ...[
            const SizedBox(height: 18),
            const SectionTitle(title: 'CaractÃ©ristiques techniques'),
            const SizedBox(height: 12),
            _SpecsCard(product: product),
          ],
          if (product.compatibility.trim().isNotEmpty ||
              product.compatibleVehicles.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionTitle(title: 'Détails produit'),
            const SizedBox(height: 12),
            _CompatibilityCard(product: product),
          ],
          const SizedBox(height: 18),
          _QuantitySelector(
            quantity: _quantity,
            maxQuantity: maxQuantity,
            onChanged: (value) => setState(() => _quantity = value),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
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
                                '$_quantity article(s) ajoutÃ©(s) au panier',
                              ),
                              action: SnackBarAction(
                                label: 'Voir',
                                onPressed: () =>
                                    context.go(AppConstants.cartRoute),
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
          const SizedBox(height: 18),
          _ReviewSummaryCard(product: product),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Articles similaires'),
          const SizedBox(height: 12),
          SizedBox(
            height: 252,
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
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  bool _hasAnySpec(ShopProduct product) {
    return product.hasDimensions ||
        product.hasDiameter ||
        product.hasWeight ||
        product.threadSize.trim().isNotEmpty ||
        product.material.trim().isNotEmpty ||
        product.color.trim().isNotEmpty ||
        product.oemReference.trim().isNotEmpty ||
        product.manufacturerReference.trim().isNotEmpty;
  }

  Future<void> _toggleFavorite(ShopProduct product) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      context.go(AppConstants.loginRoute);
      return;
    }

    final favorites = ref.read(favoritesProvider.notifier);
    final wasFavorite = favorites.contains(product.id);

    try {
      if (wasFavorite) {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', uid)
            .eq('product_id', product.id);
        favorites.remove(product);
      } else {
        await Supabase.instance.client.from('favorites').insert({
          'user_id': uid,
          'product_id': product.id,
        });
        favorites.add(product);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Impossible de mettre Ã  jour les favoris.'),
          ),
        );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            wasFavorite
                ? 'Â« ${product.name} Â» retirÃ© des favoris'
                : 'Â« ${product.name} Â» ajoutÃ© aux favoris',
          ),
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () => context.go(AppConstants.favoritesRoute),
          ),
        ),
      );
  }
}

/// Carte prix / livraison / garantie (utilise maintenant les vraies
/// donnÃ©es de garantie et d'Ã©tat renseignÃ©es sur le produit).
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.product});

  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final warrantyLabel = product.warrantyMonths > 0
        ? (product.warrantyMonths >= 12
            ? '${(product.warrantyMonths / 12).toStringAsFixed(product.warrantyMonths % 12 == 0 ? 0 : 1)} an(s)'
            : '${product.warrantyMonths} mois')
        : 'Article vÃ©rifiÃ©';

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
          const _InfoRow(label: 'Livraison', value: '24h - 48h Ã  Abidjan'),
          const Divider(height: 24),
          _InfoRow(label: 'Garantie', value: warrantyLabel),
          const Divider(height: 24),
          _InfoRow(
            label: 'Ã‰tat',
            value: product.condition.isNotEmpty ? product.condition : 'Neuf',
          ),
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

/// Carte des caractÃ©ristiques techniques : dimensions, poids, matÃ©riau,
/// couleur, filetage, rÃ©fÃ©rences OEM/fabricant. N'affiche que les
/// champs rÃ©ellement renseignÃ©s sur le produit.
class _MarketplacePromiseCard extends StatelessWidget {
  const _MarketplacePromiseCard({required this.product});

  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final deliveryLabel = product.stock > 0
        ? 'Livraison estimee: 24h - 48h'
        : 'Precommande possible selon le vendeur';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        children: [
          _PromiseLine(
            icon: Icons.local_shipping_rounded,
            title: deliveryLabel,
            subtitle: 'Suivi de commande disponible apres paiement.',
          ),
          const Divider(height: 22),
          const _PromiseLine(
            icon: Icons.assignment_return_rounded,
            title: 'Retour simple',
            subtitle: 'Demande de retour possible via le support.',
          ),
          const Divider(height: 22),
          const _PromiseLine(
            icon: Icons.verified_user_rounded,
            title: 'Achat securise',
            subtitle: 'Paiement protege et vendeur identifie.',
          ),
        ],
      ),
    );
  }
}

class _PromiseLine extends StatelessWidget {
  const _PromiseLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: DjassaTheme.clientSoft,
          child: Icon(icon, color: DjassaTheme.clientPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: DjassaTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.product});

  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final sellerName = product.creatorName?.trim();
    final avatarUrl = product.creatorAvatarUrl?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: DjassaTheme.vendorSoft,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? null
                : const Icon(
                    Icons.storefront_rounded,
                    color: DjassaTheme.vendorPrimary,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sellerName == null || sellerName.isEmpty
                      ? 'Vendeur verifie'
                      : sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Boutique partenaire Djassa',
                  style: TextStyle(color: DjassaTheme.textSecondary),
                ),
              ],
            ),
          ),
          const _PillTag(
            label: 'Verifie',
            color: DjassaTheme.vendorPrimary,
            outlined: true,
          ),
        ],
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.maxQuantity,
    required this.onChanged,
  });

  final int quantity;
  final int maxQuantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Quantite',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.filledTonal(
            onPressed: quantity <= 1 ? null : () => onChanged(quantity - 1),
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: DjassaTheme.clientPrimary,
              foregroundColor: DjassaTheme.primaryWhite,
            ),
            onPressed:
                quantity >= maxQuantity ? null : () => onChanged(quantity + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({required this.product});

  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final rating = product.rating <= 0 ? 4.6 : product.rating;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: DjassaTheme.clientPrimary),
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Avis clients bientot disponibles',
              style: TextStyle(color: DjassaTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Voir'),
          ),
        ],
      ),
    );
  }
}

class _SpecsCard extends StatelessWidget {
  const _SpecsCard({required this.product});

  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final rows = <_SpecRow>[
      if (product.dimensionsLabel.isNotEmpty)
        _SpecRow('Dimensions (L Ã— l Ã— H)', product.dimensionsLabel),
      if (product.diameterLabel.isNotEmpty)
        _SpecRow('DiamÃ¨tre', product.diameterLabel),
      if (product.weightLabel.isNotEmpty)
        _SpecRow('Poids', product.weightLabel),
      if (product.threadSize.trim().isNotEmpty)
        _SpecRow('Filetage', product.threadSize),
      if (product.material.trim().isNotEmpty)
        _SpecRow('MatÃ©riau', product.material),
      if (product.color.trim().isNotEmpty) _SpecRow('Couleur', product.color),
      if (product.oemReference.trim().isNotEmpty)
        _SpecRow('RÃ©fÃ©rence OEM', product.oemReference),
      if (product.manufacturerReference.trim().isNotEmpty)
        _SpecRow('RÃ©fÃ©rence fabricant', product.manufacturerReference),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 24),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: DjassaTheme.textSecondary)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Carte de détails produit : rÃ©sumÃ© texte + liste dÃ©taillÃ©e
/// (marque / modÃ¨le / annÃ©es / motorisation) si disponible.
class _CompatibilityCard extends StatelessWidget {
  const _CompatibilityCard({required this.product});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.compatibility.trim().isNotEmpty)
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: DjassaTheme.accentOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.compatibility,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          if (product.compatibleVehicles.isNotEmpty) ...[
            if (product.compatibility.trim().isNotEmpty)
              const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final vehicle in product.compatibleVehicles)
                  _PillTag(
                    label: vehicle,
                    color: DjassaTheme.accentOrange,
                    outlined: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Petite pastille rÃ©utilisable pour Ã©tiqueter Ã©tat / position / vÃ©hicule.
class _PillTag extends StatelessWidget {
  const _PillTag({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: outlined ? color.withValues(alpha: 0.08) : color,
        borderRadius: BorderRadius.circular(999),
        border:
            outlined ? Border.all(color: color.withValues(alpha: 0.4)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: outlined ? color : DjassaTheme.primaryWhite,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
