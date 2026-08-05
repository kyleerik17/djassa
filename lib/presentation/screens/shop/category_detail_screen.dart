// lib/presentation/screens/shop/category_detail_screen.dart

import 'package:djassa/core/router/app_navigation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';

class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
  });

  final String categoryName;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  String _sort = 'pertinence'; // pertinence | prix_asc | prix_desc | note

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    final products = productsAsync.valueOrNull
            ?.where((p) => p.category == widget.categoryName)
            .toList() ??
        [];

    final sorted = [...products];
    switch (_sort) {
      case 'prix_asc':
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'prix_desc':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'note':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        break;
    }

    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar hero ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 22.h,
            pinned: true,
            backgroundColor: DjassaTheme.primaryBlack,
            foregroundColor: DjassaTheme.primaryWhite,
           leading: IconButton(
  tooltip: 'Retour',
  icon: const Icon(Icons.arrow_back_ios_new_rounded),
  onPressed: () => context.backOrHome(),
),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => context.go(
                  AppConstants.searchLocation(category: widget.categoryName),
                ),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.8.h),
              title: Text(
                widget.categoryName,
                style: TextStyle(
                  color: DjassaTheme.primaryWhite,
                  fontFamily: 'Hemi Head',
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
              background: _CategoryHeroBg(
                categoryName: widget.categoryName,
                count: products.length,
              ),
            ),
          ),

          // ── Barre tri ──────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _SortBarDelegate(
              sort: _sort,
              onChanged: (v) => setState(() => _sort = v),
            ),
          ),

          // ── Contenu ────────────────────────────────────────────
          productsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (_, __) => SliverFillRemaining(
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: EmptyStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Catalogue indisponible',
                  message: 'Impossible de charger les articles.',
                  buttonLabel: 'Réessayer',
                  onPressed: () => ref.invalidate(productsProvider),
                ),
              ),
            ),
            data: (_) => sorted.isEmpty
                ? SliverFillRemaining(
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: EmptyStateCard(
                        icon: Icons.inventory_2_outlined,
                        title: 'Rayon vide',
                        message:
                            'Aucun article dans "${widget.categoryName}" pour l\'instant.',
                        buttonLabel: 'Voir tout le catalogue',
                        onPressed: () => context.go(AppConstants.searchRoute),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 12.h),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ProductCard(
                          product: sorted[index],
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: 40 * (index % 10)),
                              duration: 260.ms,
                            ),
                        childCount: sorted.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 1.8.h,
                        crossAxisSpacing: 3.5.w,
                        childAspectRatio: .61,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Hero background ───────────────────────────────────────────────────────────

class _CategoryHeroBg extends StatelessWidget {
  const _CategoryHeroBg({
    required this.categoryName,
    required this.count,
  });

  final String categoryName;
  final int count;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForCategory(categoryName);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0A0A),
            Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Icône déco en fond
          Positioned(
            right: -2.w,
            bottom: -1.h,
            child: Icon(
              icon,
              size: 18.h,
              color: DjassaTheme.accentOrange.withValues(alpha: .07),
            ),
          ),
          // Badge count + label
          Positioned(
            left: 4.w,
            bottom: 6.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
                  decoration: BoxDecoration(
                    color: DjassaTheme.accentOrange,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count article${count > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: DjassaTheme.primaryWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 9.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('téléphone') ||
        lower.contains('telephone') ||
        lower.contains('phone')) {
      return Icons.phone_iphone_outlined;
    }
    if (lower.contains('mode') ||
        lower.contains('vêtement') ||
        lower.contains('vetement') ||
        lower.contains('chauss')) {
      return Icons.checkroom_outlined;
    }
    if (lower.contains('maison') ||
        lower.contains('meuble') ||
        lower.contains('déco') ||
        lower.contains('deco')) {
      return Icons.chair_outlined;
    }
    if (lower.contains('beaut') ||
        lower.contains('parfum') ||
        lower.contains('soin')) {
      return Icons.spa_outlined;
    }
    if (lower.contains('super') ||
        lower.contains('course') ||
        lower.contains('aliment')) {
      return Icons.local_grocery_store_outlined;
    }
    if (lower.contains('bébé') || lower.contains('bebe')) {
      return Icons.child_care_outlined;
    }
    if (lower.contains('sport')) {
      return Icons.sports_soccer_outlined;
    }
    if (lower.contains('moteur') || lower.contains('motor')) {
      return Icons.settings_outlined;
    }
    if (lower.contains('frein') || lower.contains('brake')) {
      return Icons.compress_rounded;
    }
    if (lower.contains('électr') || lower.contains('electr')) {
      return Icons.bolt_outlined;
    }
    if (lower.contains('filtre') || lower.contains('filter')) {
      return Icons.filter_alt_outlined;
    }
    if (lower.contains('carross') || lower.contains('body')) {
      return Icons.directions_car_outlined;
    }
    if (lower.contains('pneu') ||
        lower.contains('roue') ||
        lower.contains('tire') ||
        lower.contains('wheel')) {
      return Icons.tire_repair_outlined;
    }
    if (lower.contains('huile') || lower.contains('lubri')) {
      return Icons.opacity_outlined;
    }
    if (lower.contains('éclairage') ||
        lower.contains('light') ||
        lower.contains('lampe')) {
      return Icons.light_mode_outlined;
    }
    return Icons.category_outlined;
  }
}

// ── Barre de tri persistante ──────────────────────────────────────────────────

class _SortBarDelegate extends SliverPersistentHeaderDelegate {
  const _SortBarDelegate({
    required this.sort,
    required this.onChanged,
  });

  final String sort;
  final ValueChanged<String> onChanged;

  static const _height = 56.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_SortBarDelegate old) => old.sort != sort;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _height,
      color: DjassaTheme.backgroundSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SortChip(
            label: 'Pertinence',
            selected: sort == 'pertinence',
            onTap: () => onChanged('pertinence'),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Prix ↑',
            selected: sort == 'prix_asc',
            onTap: () => onChanged('prix_asc'),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Prix ↓',
            selected: sort == 'prix_desc',
            onTap: () => onChanged('prix_desc'),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: '⭐ Note',
            selected: sort == 'note',
            onTap: () => onChanged('note'),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? DjassaTheme.primaryBlack : DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected ? DjassaTheme.primaryBlack : DjassaTheme.borderMedium,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? DjassaTheme.primaryWhite : DjassaTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
