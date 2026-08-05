import 'package:djassa/presentation/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/admin_service.dart';

import '../widgets/error_widgets.dart';
import '../widgets/hero_headers.dart';
import '../widgets/product_card.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/stats_widgets.dart';

class CatalogueTab extends ConsumerWidget {
  const CatalogueTab({
    super.key,
    required this.searchController,
    required this.query,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final TextEditingController searchController;
  final String query;
  final VoidCallback onCreate;
  final ValueChanged<AdminProduct> onEdit;
  final ValueChanged<AdminProduct> onToggleActive;
  final ValueChanged<AdminProduct> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(adminProductsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminProductsProvider);
        await ref.read(adminProductsProvider.future);
      },
      child: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorCard(
          title: 'Backoffice indisponible',
          message: '$error',
        ),
        data: (products) {
          final filtered = query.isEmpty
              ? products
              : products.where((p) {
                  return p.name.toLowerCase().contains(query) ||
                      p.categoryName.toLowerCase().contains(query) ||
                      p.compatibility.toLowerCase().contains(query) ||
                      p.badge.toLowerCase().contains(query);
                }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              const SizedBox(height: 8),
              HeroHeader(onCreate: onCreate),
              const SizedBox(height: 16),
              StatsGrid(products: products),
              const SizedBox(height: 16),
              SearchBarWidget(controller: searchController),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${filtered.length} article${filtered.length > 1 ? 's' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    'Gestion catalogue',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                EmptyAdminList(onCreate: onCreate)
              else
                ...filtered.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AdminProductCard(
                      product: product,
                      onEdit: () => onEdit(product),
                      onToggleActive: () => onToggleActive(product),
                      onDelete: () => onDelete(product),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
