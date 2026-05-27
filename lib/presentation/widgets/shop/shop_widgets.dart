import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../screens/shop/shop_data.dart';

class ShopScaffold extends StatelessWidget {
  const ShopScaffold({
    super.key,
    required this.currentIndex,
    required this.title,
    required this.child,
    this.actions,
    this.showBackButton = false,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  final int currentIndex;
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBackButton;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: DjassaTheme.backgroundSecondary,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              )
            : null,
        title: Text(title),
        actions: actions ??
            [
              IconButton(
                tooltip: 'Recherche',
                icon: const Icon(Icons.search_rounded),
                onPressed: () => context.go('/search'),
              ),
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => context.go('/notifications'),
              ),
              const SizedBox(width: 4),
            ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: padding,
          child: child,
        ),
      ),
      bottomNavigationBar: _ShopBottomNavigation(currentIndex: currentIndex),
    );
  }
}

class _ShopBottomNavigation extends StatelessWidget {
  const _ShopBottomNavigation({required this.currentIndex});

  final int currentIndex;

  static const _routes = [
    '/home',
    '/categories',
    '/cart',
    '/favorites',
    '/profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        boxShadow: DjassaTheme.shadowMedium,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            if (index != currentIndex) {
              context.go(_routes[index]);
            }
          },
          selectedItemColor: DjassaTheme.accentOrange,
          unselectedItemColor: DjassaTheme.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Rayons',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag_rounded),
              label: 'Panier',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border_rounded),
              activeIcon: Icon(Icons.favorite_rounded),
              label: 'Favoris',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
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
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
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
        borderRadius: BorderRadius.circular(28),
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
                    borderRadius: BorderRadius.circular(16),
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
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DjassaTheme.borderMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundIcon(icon: category.icon),
            const Spacer(),
            Text(
              category.name,
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
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.go('/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(24),
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
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DjassaTheme.backgroundSecondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          product.icon,
                          size: compact ? 42 : 56,
                          color:
                              DjassaTheme.primaryBlack.withValues(alpha: .72),
                        ),
                      ),
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
                            borderRadius: BorderRadius.circular(999),
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
                          onPressed: () => context.go('/favorites'),
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
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: DjassaTheme.accentOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        '${product.stock} en stock',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
      borderRadius: BorderRadius.circular(22),
      onTap: onTap ?? () => context.go('/product/${product.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: DjassaTheme.borderMedium),
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: DjassaTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(product.icon, color: DjassaTheme.primaryBlack),
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
                  Text(product.compatibility),
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
        borderRadius: BorderRadius.circular(28),
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

