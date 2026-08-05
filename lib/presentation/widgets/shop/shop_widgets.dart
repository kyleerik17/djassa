import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_navigation.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../screens/shop/shop_data.dart';
import '../vendor/client_shop_gate.dart';

class ShopScaffold extends StatelessWidget {
  const ShopScaffold({
    super.key,
    required this.currentIndex,
    required this.title,
    required this.child,
    this.actions,
    this.showBackButton = false,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
    this.darkHeader = false,
    this.showSellButton = true,
    this.onRefresh,
    this.unreadNotificationsCount,
  });

  final int currentIndex;
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBackButton;
  final EdgeInsets padding;
  final bool darkHeader;
  final bool showSellButton;

  /// Si fourni, active le pull-to-refresh sur le contenu de l'écran.
  /// Le SingleChildScrollView interne est déjà géré par ShopScaffold, donc
  /// c'est ICI qu'il faut brancher le RefreshIndicator — pas dans l'écran
  /// appelant (sinon ça crée un scrollable imbriqué avec hauteur infinie).
  final Future<void> Function()? onRefresh;

  /// Nombre de notifications non lues. Si null ou 0, aucun badge affiché.
  /// L'écran appelant doit le fournir en lisant son propre provider de
  /// notifications (ex: `ref.watch(unreadNotificationsCountProvider)`).
  final int? unreadNotificationsCount;

  @override
  Widget build(BuildContext context) {
    final scrollableChild = SingleChildScrollView(
      physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
      padding: padding,
      child: child,
    );

    return ClientShopGate(
      child: Scaffold(
        backgroundColor: DjassaTheme.backgroundSecondary,
        appBar: AppBar(
          backgroundColor: darkHeader
              ? DjassaTheme.primaryBlack
              : DjassaTheme.backgroundSecondary,
          foregroundColor:
              darkHeader ? DjassaTheme.primaryWhite : DjassaTheme.textPrimary,
   leading: showBackButton
    ? IconButton(
        tooltip: 'Retour',
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => context.backOrHome(),
      )
    : null,
          title: Text(
            title,
            style: TextStyle(
              color: darkHeader
                  ? DjassaTheme.primaryWhite
                  : DjassaTheme.textPrimary,
              fontFamily: 'Hemi Head',
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: actions ??
              [
                _NotificationButton(
                  darkHeader: darkHeader,
                  unreadCount: unreadNotificationsCount,
                ),
                const SizedBox(width: 4),
              ],
        ),
        body: SafeArea(
          top: false,
          child: onRefresh != null
              ? RefreshIndicator(
                  color: DjassaTheme.accentOrange,
                  onRefresh: onRefresh!,
                  child: scrollableChild,
                )
              : scrollableChild,
        ),
        bottomNavigationBar: _ShopBottomNavigation(
          currentIndex: currentIndex,
          showSellButton: showSellButton,
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.darkHeader,
    required this.unreadCount,
  });

  final bool darkHeader;
  final int? unreadCount;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        darkHeader ? DjassaTheme.primaryWhite : DjassaTheme.textPrimary;
    final icon = Icon(Icons.notifications_none_rounded, color: iconColor);

    return IconButton(
      tooltip: unreadCount != null && unreadCount! > 0
          ? '$unreadCount notification${unreadCount! > 1 ? 's' : ''} non lue${unreadCount! > 1 ? 's' : ''}'
          : 'Notifications',
      icon: unreadCount != null && unreadCount! > 0
          ? Badge(
              label: Text(unreadCount! > 9 ? '9+' : '$unreadCount'),
              backgroundColor: DjassaTheme.accentOrange,
              textColor: DjassaTheme.primaryWhite,
              child: icon,
            )
          : icon,
      onPressed: () => context.toNotifications(),
    );
  }
}

class _ShopBottomNavigation extends StatelessWidget {
  const _ShopBottomNavigation({
    required this.currentIndex,
    this.showSellButton = true,
  });

  final int currentIndex;
  final bool showSellButton;

  static const _routes = [
    AppConstants.homeRoute,
    AppConstants.searchRoute,
    AppConstants.vendorRoute,
    AppConstants.cartRoute,
    AppConstants.profileRoute,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        boxShadow: DjassaTheme.shadowMedium,
        borderRadius: BorderRadius.circular(26),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Accueil',
                  selected: currentIndex == 0,
                  onTap: () => context.go(_routes[0]),
                ),
                _NavItem(
                  icon: Icons.search_rounded,
                  activeIcon: Icons.search_rounded,
                  label: 'Recherche',
                  selected: currentIndex == 1,
                  onTap: () => context.go(_routes[1]),
                ),
                if (showSellButton)
                  _SellNavButton(
                    selected: currentIndex == 2,
                    onTap: () => context.go(_routes[2]),
                  ),
                _NavItem(
                  icon: Icons
                      .shopping_cart_outlined, // Icône panier vide (normal)
                  activeIcon:
                      Icons.shopping_cart_rounded, // Icône panier plein (actif)
                  label: 'Panier',
                  selected: currentIndex == 3,
                  onTap: () => context.go(_routes[3]),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profil',
                  selected: currentIndex == 4,
                  onTap: () => context.go(_routes[4]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DjassaTheme.accentOrange : DjassaTheme.textPrimary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 23),
              const SizedBox(height: 3),
              FittedBox(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellNavButton extends StatelessWidget {
  const _SellNavButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: DjassaTheme.accentOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: DjassaTheme.primaryWhite,
                  size: 30,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Vendre',
                style: TextStyle(
                  color: selected
                      ? DjassaTheme.accentOrange
                      : DjassaTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Text(''),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

class PromoCard extends StatelessWidget {
  const PromoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(18),
        boxShadow: DjassaTheme.shadowHeavy,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -28,
            child: Icon(
              icon,
              size: 132,
              color: DjassaTheme.primaryWhite.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: DjassaTheme.accentOrange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Offre du jour',
                  style: TextStyle(
                    color: DjassaTheme.primaryWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: DjassaTheme.primaryWhite,
                      height: 1.1,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DjassaTheme.primaryWhite.withValues(alpha: 0.76),
                    ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: DjassaTheme.accentOrange,
                  foregroundColor: DjassaTheme.primaryWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0);
  }
}

class CategoryPill extends StatelessWidget {
  const CategoryPill({
    super.key,
    required this.category,
    this.onTap,
  });

  final ShopCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DjassaTheme.borderMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Icon(category.icon, size: 34)),
            const Spacer(),
            Text(
              category.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${category.itemsCount} articles',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.compact = false,
  });

  final ShopProduct product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.go(AppConstants.productLocation(product.id)),
      child: Container(
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DjassaTheme.borderMedium),
          boxShadow: DjassaTheme.shadowLight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'product-${product.id}',
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: DjassaTheme.backgroundSecondary,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: ProductMedia(product: product)),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: DjassaTheme.accentOrange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.badge,
                            style: const TextStyle(
                              color: DjassaTheme.primaryWhite,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: DjassaTheme.primaryWhite,
                          ),
                          onPressed: () =>
                              context.go(AppConstants.favoritesRoute),
                          icon: const Icon(
                            Icons.favorite_border_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 7),
                  _LocationLine(text: product.compatibility),
                  ProductCreatorLine(product: product, compact: compact),
                  const SizedBox(height: 7),
                  Text(
                    formatPrice(product.price),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: DjassaTheme.accentOrange,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).scale(begin: const Offset(.98, .98));
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    this.trailing,
    this.onTap,
  });

  final ShopProduct product;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap:
          onTap ?? () => context.go(AppConstants.productLocation(product.id)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DjassaTheme.borderMedium),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: DjassaTheme.backgroundSecondary,
                ),
                child: ProductMedia(product: product, iconSize: 32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 5),
                  _LocationLine(text: product.compatibility),
                  ProductCreatorLine(product: product),
                  const SizedBox(height: 6),
                  Text(
                    formatPrice(product.price),
                    style: const TextStyle(
                      color: DjassaTheme.accentOrange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: .04, end: 0);
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        children: [
          _RoundIcon(icon: icon, size: 68),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onPressed,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    this.size = 48,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: DjassaTheme.accentOrange.withValues(alpha: .12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: DjassaTheme.accentOrange,
        size: size * .48,
      ),
    );
  }
}

class ProductMedia extends StatelessWidget {
  const ProductMedia({
    super.key,
    required this.product,
    this.iconSize = 56,
  });

  final ShopProduct product;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final image = imageUrl.startsWith('http')
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FallbackProductIcon(
                icon: product.icon,
                iconSize: iconSize,
              ),
            )
          : Image.asset(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FallbackProductIcon(
                icon: product.icon,
                iconSize: iconSize,
              ),
            );
      return image;
    }
    return _FallbackProductIcon(icon: product.icon, iconSize: iconSize);
  }
}

class _FallbackProductIcon extends StatelessWidget {
  const _FallbackProductIcon({required this.icon, required this.iconSize});

  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        icon,
        size: iconSize,
        color: DjassaTheme.primaryBlack.withValues(alpha: .72),
      ),
    );
  }
}

class ProductCreatorLine extends StatelessWidget {
  const ProductCreatorLine({
    super.key,
    required this.product,
    this.compact = false,
  });

  final ShopProduct product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!product.hasCreator) return const SizedBox.shrink();

    final avatarUrl = product.creatorAvatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final radius = compact ? 9.0 : 10.0;

    return Padding(
      padding: EdgeInsets.only(top: compact ? 4 : 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .12),
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
            child: hasAvatar
                ? null
                : Icon(
                    Icons.person_rounded,
                    size: compact ? 11 : 12,
                    color: DjassaTheme.accentOrange,
                  ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Par ${product.creatorName!.trim()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DjassaTheme.textSecondary,
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationLine extends StatelessWidget {
  const _LocationLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 15,
          color: DjassaTheme.textSecondary,
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
