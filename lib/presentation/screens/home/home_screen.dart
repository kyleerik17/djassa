import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../providers/auth_provider.dart';

/// Écran d'accueil Djassa
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Djassa'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigation vers notifications
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Salutation
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: DjassaTheme.borderMedium),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: DjassaTheme.accentOrange.withOpacity(0.1),
                      child: user?.avatarUrl != null
                          ? ClipOval(
                              child: Image.network(
                                user!.avatarUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 30,
                              color: DjassaTheme.accentOrange,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour, ${user?.fullName ?? "Utilisateur"}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trouvez vos pièces détachées premium',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        context.go('/profile');
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Barre de recherche
            TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher une pièce...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    // TODO: Ouvrir filtres
                  },
                ),
                filled: true,
                fillColor: DjassaTheme.backgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                context.go('/search?q=$value');
              },
            ),

            const SizedBox(height: 24),

            // Catégories rapides
            Text(
              'Catégories populaires',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryItem(
                    context,
                    icon: Icons.engineering,
                    label: 'Moteur',
                  ),
                  _buildCategoryItem(
                    context,
                    icon: Icons.car_crash,
                    label: 'Carrosserie',
                  ),
                  _buildCategoryItem(
                    context,
                    icon: Icons.brightness_5,
                    label: 'Éclairage',
                  ),
                  _buildCategoryItem(
                    context,
                    icon: Icons.water_drop,
                    label: 'Freinage',
                  ),
                  _buildCategoryItem(
                    context,
                    icon: Icons.settings,
                    label: 'Suspension',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Produits recommandés
            Text(
              'Recommandé pour vous',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return _buildProductCard(context, index);
              },
            ),

            const SizedBox(height: 100), // Espace pour la barre de navigation
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Déjà sur home
              break;
            case 1:
              context.go('/categories');
              break;
            case 2:
              context.go('/cart');
              break;
            case 3:
              context.go('/favorites');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            activeIcon: Icon(Icons.category),
            label: 'Catégories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Panier',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favoris',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: DjassaTheme.accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: DjassaTheme.accentOrange,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, int index) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: DjassaTheme.borderMedium),
      ),
      child: InkWell(
        onTap: () {
          context.go('/product/${index + 1}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: DjassaTheme.backgroundSecondary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.directions_car,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pièce Premium ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'À partir de ${(100 * (index + 1)).toString()} FCFA',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DjassaTheme.accentOrange,
                          fontWeight: FontWeight.w600,
                        ),
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
