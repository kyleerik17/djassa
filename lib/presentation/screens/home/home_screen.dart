import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/location_commune_service.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../domain/order_progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/order_progress_celebration.dart';
import '../../widgets/shop/order_progress_tracker.dart';
import '../../widgets/shop/shop_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _lastCelebratedStatus;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider);
    final activeOrderAsync = ref.watch(activeClientOrderProvider);

    ref.listen(activeClientOrderProvider, (previous, next) {
      final order = next.valueOrNull;
      if (order == null || !mounted) return;
      final prevStatus = previous?.valueOrNull?.status;
      if (!OrderProgressInfo.isProgressForward(prevStatus, order.status)) {
        return;
      }
      if (_lastCelebratedStatus == order.status) return;
      _lastCelebratedStatus = order.status;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showOrderProgressCelebration(context, status: order.status);
      });
    });

    return ShopScaffold(
      currentIndex: 0,
      title: 'Djassa.',
      darkHeader: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeHero(
            locationAsync: ref.watch(currentCommuneProvider),
            categoriesAsync: categoriesAsync,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Text(
              'Bonjour ${user?.fullName ?? 'a vous'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          activeOrderAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (order) {
              if (order == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: OrderProgressTracker(
                  key: ValueKey('${order.id}_${order.status}'),
                  order: order,
                  compact: true,
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PromoCard(
              title: 'Promos du moment',
              subtitle:
                  'Decouvrez les meilleures offres selectionnees pour vous.',
              buttonLabel: 'Voir les promos',
              icon: Icons.local_offer_rounded,
              onPressed: () => context.go('/categories'),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionTitle(
              title: 'Categories rapides',
              actionLabel: 'Voir tout',
              onAction: () => context.go('/categories'),
            ),
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            loading: () => const SizedBox(
              height: 126,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 126,
              child: Center(
                child: Text(
                  'Impossible de charger les categories.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            data: (categories) => categories.isEmpty
                ? const SizedBox(
                    height: 126,
                    child: Center(child: Text('Aucune categorie disponible.')),
                  )
                : SizedBox(
                    height: 126,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return CategoryPill(
                          category: category,
                          onTap: () => context.go(
                            '/search?category=${category.name}',
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionTitle(
              title: 'Tendances',
              actionLabel: 'Voir tout',
              onAction: () => context.go('/search'),
            ),
          ),
          const SizedBox(height: 12),
          productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Impossible de charger les produits.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            data: (products) => products.isEmpty
                ? const Center(child: Text('Aucun produit disponible.'))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: .61,
                      ),
                      itemBuilder: (context, index) {
                        return ProductCard(product: products[index]);
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _HomeHero extends ConsumerStatefulWidget {
  const _HomeHero({
    required this.locationAsync,
    required this.categoriesAsync,
  });

  final AsyncValue<CommunePosition> locationAsync;
  final AsyncValue<List<dynamic>> categoriesAsync;

  @override
  ConsumerState<_HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<_HomeHero> {
  String? _selectedCategoryName;

  @override
  Widget build(BuildContext context) {
    final locationLabel = widget.locationAsync.when(
      data: (location) => location.label,
      loading: () => 'Localisation...',
      error: (_, __) => LocationCommuneService.fallback.label,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
      decoration: const BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Actualiser la position',
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => ref.invalidate(currentCommuneProvider),
                icon: const Icon(
                  Icons.location_on_outlined,
                  color: DjassaTheme.primaryWhite,
                  size: 20,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: DjassaTheme.primaryWhite,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.go('/profile'),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      DjassaTheme.primaryWhite.withValues(alpha: .12),
                  child: const Icon(
                    Icons.person_rounded,
                    color: DjassaTheme.primaryWhite,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.go('/search'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: DjassaTheme.primaryWhite,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rechercher un produit...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const Icon(
                    Icons.tune_rounded,
                    color: DjassaTheme.accentOrange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: widget.categoriesAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DjassaTheme.primaryWhite,
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (categories) {
                if (categories.isEmpty) return const SizedBox.shrink();
                
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategoryName == category.name;
                    
                    return _HeaderChip(
                      label: category.name,
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedCategoryName = isSelected ? null : category.name;
                        });
                        context.go('/search?category=${category.name}');
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? DjassaTheme.accentOrange
              : DjassaTheme.primaryWhite.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: DjassaTheme.primaryWhite,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}