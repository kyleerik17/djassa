import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sizer/flutter_sizer.dart'; // ✅ Import de Sizer
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return ShopScaffold(
      currentIndex: 1,
      showSellButton: false,
      title: 'Rayons',
      child: SingleChildScrollView( // ✅ Ajouté pour éviter les débordements globaux sur petits écrans
        padding: EdgeInsets.all(2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PromoCard(
              title: 'Trouvez vite le bon article',
              subtitle: 'Parcourez les rayons, comparez les prix et ouvrez une fiche article.',
              buttonLabel: 'Rechercher',
              icon: Icons.grid_view_rounded,
              onPressed: () => context.go(AppConstants.searchRoute),
            ),
            SizedBox(height: 3.h),
            
            // Utilisation de Sizer pour le titre de section si c'est un widget personnalisé, 
            // sinon gardez votre SectionTitle tel quel.
            const SectionTitle(title: 'Toutes les catégories'),
            SizedBox(height: 1.5.h),
            
            categoriesAsync.when(
              loading: () => SizedBox(
                height: 40.h,
                child: const Center(child: CircularProgressIndicator()),
              ),
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 1.5.h,      // ✅ Espacement vertical responsive
                        crossAxisSpacing: 1.5.h,     // ✅ Espacement horizontal responsive
                        childAspectRatio: 0.85,      // ✅ Légèrement plus haut pour donner de l'air au texte
                      ),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(2.h),
                          onTap: () => context.go(
                            AppConstants.searchLocation(category: category.name),
                          ),
                          child: Container(
                            padding: EdgeInsets.all(2.h), // ✅ Padding responsive
                            decoration: BoxDecoration(
                              color: DjassaTheme.primaryWhite,
                              borderRadius: BorderRadius.circular(2.h),
                              border: Border.all(color: DjassaTheme.borderMedium),
                              boxShadow: DjassaTheme.shadowLight,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 3.5.h, // ✅ Rayon responsive (environ 28-32px selon l'écran)
                                  backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .12),
                                  child: Icon(
                                    category.icon,
                                    color: DjassaTheme.accentOrange,
                                    size: 3.h,   // ✅ Taille d'icône responsive
                                  ),
                                ),
                                SizedBox(height: 1.5.h),
                                
                                // ✅ NOM DE LA CATÉGORIE : maxLines est CRUCIAL ici
                                Text(
                                  category.name,
                                  maxLines: 2, 
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 1.8.sp, // ✅ Police responsive (environ 14-16px)
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                
                                SizedBox(height: 0.8.h),
                                
                                // ✅ SOUS-TITRE : maxLines est CRUCIAL ici
                                Text(
                                  category.subtitle ?? '', // Protection contre les nulls
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 1.3.sp, // ✅ Police responsive (environ 10-12px)
                                    color: DjassaTheme.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                                
                                const Spacer(), // Pousse le compteur tout en bas de manière flexible
                                
                                // ✅ COMPTEUR D'ARTICLES
                                Text(
                                  '${category.itemsCount ?? 0} articles',
                                  style: TextStyle(
                                    color: DjassaTheme.accentOrange,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 1.3.sp, // ✅ Police responsive
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: 10.h), // ✅ Espace responsive pour la barre de navigation du bas
          ],
        ),
      ),
    );
  }
}