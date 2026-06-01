import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return ShopScaffold(
      currentIndex: 1,
      title: 'Rayons',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PromoCard(
            title: 'Trouvez vite le bon article',
            subtitle:
                'Parcourez les rayons, comparez les prix et ouvrez une fiche article.',
            buttonLabel: 'Rechercher',
            icon: Icons.grid_view_rounded,
            onPressed: () => context.go('/search'),
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Toutes les catégories'),
          const SizedBox(height: 12),
          categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyStateCard(
              icon: Icons.cloud_off_rounded,
              title: 'Rayons indisponibles',
              message: 'Impossible de charger les rayons du serveur.',
              buttonLabel: 'Réessayer',
              onPressed: () => ref.invalidate(categoriesProvider),
            ),
            data: (categories) => categories.isEmpty
                ? EmptyStateCard(
                    icon: Icons.grid_view_rounded,
                    title: 'Aucun rayon',
                    message: 'Créez vos catégories depuis le backoffice admin.',
                    buttonLabel: 'Actualiser',
                    onPressed: () => ref.invalidate(categoriesProvider),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categories.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: .9,
                    ),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(26),
                        onTap: () =>
                            context.go('/search?category=${category.name}'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: DjassaTheme.primaryWhite,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: DjassaTheme.borderMedium),
                            boxShadow: DjassaTheme.shadowLight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: DjassaTheme.accentOrange
                                    .withValues(alpha: .12),
                                child: Icon(
                                  category.icon,
                                  color: DjassaTheme.accentOrange,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                category.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                category.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${category.itemsCount} articles',
                                style: const TextStyle(
                                  color: DjassaTheme.accentOrange,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}
