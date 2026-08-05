import 'dart:async';
import 'package:djassa/presentation/screens/shop/shop_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.category});
  final String? initialQuery;
  final String? category;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  String _query = '';
  String _sort = 'relevance';
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode()
      ..addListener(() => setState(() => _focused = _focusNode.hasFocus));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != _controller.text) {
      _controller.text = widget.initialQuery ?? '';
      _query = widget.initialQuery ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    _focusNode.unfocus();
    setState(() => _query = value);
    context.replace(
        AppConstants.searchLocation(query: value, category: widget.category));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final allProducts = productsAsync.valueOrNull ?? [];
    final normalizedQuery = _query.toLowerCase().trim();

    final filteredProducts = allProducts.where((product) {
      final productCategory = product.category.toLowerCase().trim();
      final selectedCategory = (widget.category ?? '').toLowerCase().trim();

      final matchesQuery = normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery) ||
          product.category.toLowerCase().contains(normalizedQuery) ||
          product.compatibility.toLowerCase().contains(normalizedQuery) ||
          (product.creatorName ?? '').toLowerCase().contains(normalizedQuery);

      final matchesCategory =
          selectedCategory.isEmpty || productCategory == selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();
    final sortedProducts = _sortProducts(filteredProducts);

    final isLoading = categoriesAsync.isLoading || productsAsync.isLoading;
    final hasError = categoriesAsync.hasError || productsAsync.hasError;

    return ShopScaffold(
      showSellButton: false,
      currentIndex: 1,
      title: 'Recherche',
      showBackButton: true,
      actions: const [SizedBox(width: 8)],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _ProSearchBar(
              controller: _controller,
              focusNode: _focusNode,
              focused: _focused,
              onChanged: _onQueryChanged,
              onSubmitted: _submit,
              onClear: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const _SearchLoadingState()
            else if (hasError)
              EmptyStateCard(
                icon: Icons.cloud_off_rounded,
                title: 'Catalogue indisponible',
                message: 'La connexion au serveur a Ã©chouÃ©.',
                buttonLabel: 'RÃ©essayer',
                onPressed: () {
                  ref.invalidate(categoriesProvider);
                  ref.invalidate(productsProvider);
                },
              )
            else ...[
              _CategoryRow(
                categories: categories,
                selected: widget.category,
                currentQuery: _query,
              ),

              // âœ… BADGES DE FILTRES ACTIFS (UX Pro)
              if (_query.isNotEmpty || widget.category != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (_query.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DjassaTheme.accentOrange.withOpacity(.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_rounded,
                                size: 12, color: DjassaTheme.accentOrange),
                            const SizedBox(width: 4),
                            Text('â€œ$_queryâ€',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: DjassaTheme.accentOrange)),
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() => _query = '');
                                context.replace(AppConstants.searchLocation(
                                    category: widget.category));
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.close_rounded,
                                    size: 12, color: DjassaTheme.accentOrange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DjassaTheme.primaryBlack.withOpacity(.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.label_outline_rounded,
                                size: 12, color: DjassaTheme.textPrimary),
                            const SizedBox(width: 4),
                            Text(widget.category!,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: DjassaTheme.textPrimary)),
                            GestureDetector(
                              onTap: () => context.replace(
                                  AppConstants.searchLocation(query: _query)),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.close_rounded,
                                    size: 12, color: DjassaTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              _SearchToolbar(
                count: sortedProducts.length,
                sort: _sort,
                onSortChanged: (value) => setState(() => _sort = value),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category == null
                              ? 'RÃ‰SULTATS'
                              : widget.category!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: DjassaTheme.textPrimary.withOpacity(.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          normalizedQuery.isEmpty
                              ? 'Tous les articles'
                              : 'â€œ$_queryâ€',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    height: 1.1,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DjassaTheme.accentOrange.withOpacity(.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${sortedProducts.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: DjassaTheme.accentOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (sortedProducts.isEmpty)
                EmptyStateCard(
                  icon: Icons.manage_search_rounded,
                  title: 'Aucun rÃ©sultat',
                  message: normalizedQuery.isEmpty
                      ? 'Aucun article dans ce rayon.'
                      : 'Essayez un autre mot-clÃ©.',
                  buttonLabel: 'Voir les rayons',
                  onPressed: () => context.push(AppConstants.categoriesRoute),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedProducts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemBuilder: (context, index) => _StaggeredEntry(
                    index: index,
                    child: _ProProductCard(product: sortedProducts[index]),
                  ),
                ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<ShopProduct> _sortProducts(List<ShopProduct> products) {
    final sorted = [...products];
    switch (_sort) {
      case 'price_asc':
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        break;
    }
    return sorted;
  }
}

// ============================================================================
// ðŸŽ¨ CARTE PRODUIT PROFESSIONNELLE
// ============================================================================

class _SearchToolbar extends StatelessWidget {
  const _SearchToolbar({
    required this.count,
    required this.sort,
    required this.onSortChanged,
  });

  final int count;
  final String sort;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count article${count > 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          PopupMenuButton<String>(
            initialValue: sort,
            onSelected: onSortChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'relevance', child: Text('Pertinence')),
              PopupMenuItem(value: 'price_asc', child: Text('Prix croissant')),
              PopupMenuItem(
                value: 'price_desc',
                child: Text('Prix décroissant'),
              ),
              PopupMenuItem(value: 'rating', child: Text('Mieux notés')),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_rounded, size: 18),
                const SizedBox(width: 6),
                Text(
                  _sortLabel(sort),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(String value) {
    switch (value) {
      case 'price_asc':
        return 'Prix + bas';
      case 'price_desc':
        return 'Prix + haut';
      case 'rating':
        return 'Notes';
      default:
        return 'Pertinence';
    }
  }
}

class _ProProductCard extends StatelessWidget {
  const _ProProductCard({required this.product});
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(AppConstants.productLocation(product.id)),
      child: Container(
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DjassaTheme.borderLight.withOpacity(.5)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone Image Fixe (AspectRatio works fine here)
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: product.imageUrl != null &&
                            product.imageUrl!.isNotEmpty
                        ? Image.network(product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const _Placeholder())
                        : const _Placeholder(),
                  ),
                  if (product.stock <= 0)
                    Positioned(
                        top: 8,
                        right: 8,
                        child: _Badge('Rupture', Colors.redAccent))
                  else if (product.badge.isNotEmpty)
                    Positioned(
                        top: 8,
                        right: 8,
                        child: _Badge(product.badge, DjassaTheme.accentOrange)),
                ],
              ),
            ),
            // Zone Infos StructurÃ©e (SANS Expanded ni Spacer)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: DjassaTheme.accentOrange),
                      const SizedBox(width: 3),
                      Text(
                        (product.rating <= 0 ? 4.6 : product.rating)
                            .toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          product.creatorName?.trim().isNotEmpty == true
                              ? product.creatorName!.trim()
                              : product.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: DjassaTheme.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${product.price} FCFA',
                          style: const TextStyle(
                              color: DjassaTheme.accentOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                      if (product.oldPrice > product.price) ...[
                        const SizedBox(width: 6),
                        Text('${product.oldPrice}',
                            style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey.shade400,
                                fontSize: 11)),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    return Container(
        color: DjassaTheme.backgroundSecondary,
        child: const Center(
            child: Icon(Icons.image_outlined,
                size: 32, color: DjassaTheme.textSecondary)));
  }
}

// ============================================================================
// ðŸ” BARRE DE RECHERCHE PREMIUM
// ============================================================================

class _ProSearchBar extends StatelessWidget {
  const _ProSearchBar(
      {required this.controller,
      required this.focusNode,
      required this.focused,
      required this.onChanged,
      required this.onSubmitted,
      required this.onClear});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: focused
            ? DjassaTheme.primaryWhite
            : DjassaTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: focused ? DjassaTheme.accentOrange : Colors.transparent,
            width: 1.5),
        boxShadow: focused
            ? [
                BoxShadow(
                    color: DjassaTheme.accentOrange.withOpacity(.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: focused
                  ? DjassaTheme.accentOrange
                  : DjassaTheme.textPrimary.withOpacity(.4),
              size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              decoration: const InputDecoration(
                  hintText: 'Rechercher un produit...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14)),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: onClear,
                    child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: DjassaTheme.textPrimary.withOpacity(.08),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 16))),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ðŸ·ï¸ CHIPS CATÃ‰GORIES Ã‰PURÃ‰ES
// ============================================================================

class _CategoryRow extends StatelessWidget {
  const _CategoryRow(
      {required this.categories,
      required this.selected,
      required this.currentQuery});
  final List<dynamic> categories;
  final String? selected;
  final String currentQuery;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _Chip(
              label: 'Tous',
              selected: selected == null,
              onTap: () => context.replace(
                AppConstants.searchLocation(query: currentQuery),
              ),
            );
          }
          final item = categories[index - 1];
          return _Chip(
              label: item.name,
              selected: selected == item.name,
              onTap: () => context.replace(AppConstants.searchLocation(
                  category: item.name, query: currentQuery)));
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? DjassaTheme.primaryBlack : DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected
                  ? DjassaTheme.primaryBlack
                  : DjassaTheme.borderMedium.withOpacity(.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected
                    ? DjassaTheme.primaryWhite
                    : DjassaTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      ),
    );
  }
}

// ============================================================================
// â³ SKELETON & ANIMATION
// ============================================================================

class _SearchLoadingState extends StatelessWidget {
  const _SearchLoadingState();
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          height: 36,
          child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _Shimmer(
                  width: 60 + (i.isEven ? 20 : 0), height: 36, radius: 999))),
      const SizedBox(height: 24),
      GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.65),
          itemBuilder: (context, _) => const _Shimmer(radius: 16)),
    ]);
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({this.width, this.height, required this.radius});
  final double? width, height;
  final double radius;
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
                color:
                    DjassaTheme.textPrimary.withOpacity(.05 + .04 * _c.value),
                borderRadius: BorderRadius.circular(widget.radius))));
  }
}

class _StaggeredEntry extends StatelessWidget {
  const _StaggeredEntry({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 200 + (index.clamp(0, 6) * 40)),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(
            opacity: v,
            child:
                Transform.translate(offset: Offset(0, (1 - v) * 12), child: c)),
        child: child);
  }
}
