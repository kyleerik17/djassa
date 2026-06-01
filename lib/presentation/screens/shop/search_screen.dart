import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({
    super.key,
    this.initialQuery,
    this.category,
  });

  final String? initialQuery;
  final String? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final allProducts = productsAsync.valueOrNull ?? [];
    final normalizedQuery = (initialQuery ?? '').toLowerCase().trim();
    final filteredProducts = allProducts.where((product) {
      final matchesQuery = normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery) ||
          product.category.toLowerCase().contains(normalizedQuery) ||
          product.compatibility.toLowerCase().contains(normalizedQuery);
      final matchesCategory = category == null || product.category == category;
      return matchesQuery && matchesCategory;
    }).toList();

    return ShopScaffold(
      currentIndex: 1,
      title: 'Recherche',
      showBackButton: true,
      actions: const [SizedBox(width: 8)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: true,
            controller: TextEditingController(text: initialQuery),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Nom d’article, marque, référence...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: const Icon(Icons.tune_rounded),
              filled: true,
              fillColor: DjassaTheme.primaryWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) => context.go('/search?q=$value'),
          ),
          const SizedBox(height: 16),
          if (categoriesAsync.isLoading || productsAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (categoriesAsync.hasError || productsAsync.hasError)
            EmptyStateCard(
              icon: Icons.cloud_off_rounded,
              title: 'Catalogue indisponible',
              message: 'Impossible de charger les articles du serveur.',
              buttonLabel: 'Réessayer',
              onPressed: () {
                ref.invalidate(categoriesProvider);
                ref.invalidate(productsProvider);
              },
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(label: 'Tous', selected: category == null),
                for (final item in categories)
                  _FilterChip(
                    label: item.name,
                    selected: category == item.name,
                    onTap: () => context.go('/search?category=${item.name}'),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SectionTitle(
              title: category == null ? 'Résultats' : category!,
              actionLabel: '${filteredProducts.length} articles',
            ),
            const SizedBox(height: 12),
            if (filteredProducts.isEmpty)
              EmptyStateCard(
                icon: Icons.manage_search_rounded,
                title: 'Aucun résultat',
                message:
                    'Essayez une autre recherche ou parcourez les rayons disponibles.',
                buttonLabel: 'Voir les rayons',
                onPressed: () => context.go('/categories'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return ProductTile(product: filteredProducts[index]);
                },
              ),
          ],
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap ?? () => context.go('/search'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? DjassaTheme.primaryBlack : DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: DjassaTheme.borderMedium),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? DjassaTheme.primaryWhite : DjassaTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
