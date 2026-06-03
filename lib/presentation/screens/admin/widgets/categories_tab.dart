import 'package:djassa/presentation/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/djassa_theme.dart';
import '../../../../data/sources/remote/admin_service.dart';

import '../widgets/category_card.dart';
import '../widgets/error_widgets.dart';
import '../widgets/hero_headers.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/stats_widgets.dart';

class CategoriesTab extends ConsumerWidget {
  const CategoriesTab({
    super.key,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final VoidCallback onCreate;
  final ValueChanged<AdminCategory> onEdit;
  final ValueChanged<AdminCategory> onToggleActive;
  final ValueChanged<AdminCategory> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(adminCategoriesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminCategoriesProvider);
        ref.invalidate(categoriesProvider);
        await ref.read(adminCategoriesProvider.future);
      },
      child: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorCard(
          title: 'Rayons indisponibles',
          message: '$error',
        ),
        data: (categories) {
          final active = categories.where((c) => c.isActive).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              const SizedBox(height: 8),
              CategoryHeroHeader(onCreate: onCreate),
              const SizedBox(height: 16),
              SizedBox(
                height: 122,
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Rayons',
                        value: '${categories.length}',
                        icon: Icons.grid_view_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'En ligne',
                        value: '$active',
                        icon: Icons.visibility_rounded,
                        color: DjassaTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${categories.length} rayon${categories.length > 1 ? 's' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    'Gestion catégories',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                EmptyCategoryList(onCreate: onCreate)
              else
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AdminCategoryCard(
                      category: category,
                      onEdit: () => onEdit(category),
                      onToggleActive: () => onToggleActive(category),
                      onDelete: () => onDelete(category),
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