import 'dart:async';
import 'dart:convert';
import 'package:djassa/data/services/client_order_tracking_service.dart';
import 'package:djassa/presentation/screens/shop/skeleton_loaders.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../../../core/router/app_navigation.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../domain/order_progress.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/order_progress_celebration.dart';
import '../../widgets/shop/order_progress_tracker.dart';
import '../../widgets/shop/shop_widgets.dart';
import '../shop/shop_data.dart';

// ─────────────────────────────────────────────────────────────────────────
// CONFIGURATION VISUELLE
// Tout passe désormais par DjassaTheme (plus de couleurs en dur locales) :
// ça garantit la cohérence avec LoginScreen, ForgotPasswordScreen,
// CourierOrdersScreen, VendorAccountScreen.
// ─────────────────────────────────────────────────────────────────────────

Color get _bg => DjassaTheme.backgroundSecondary;
Color get _card => DjassaTheme.primaryWhite;
Color get _accent => DjassaTheme.accentOrange;
Color get _textPrimary => DjassaTheme.primaryBlack;
Color get _textSecondary => DjassaTheme.textSecondary;
Color get _border => DjassaTheme.borderMedium;

/// Petite palette de rotation pour donner un peu de vie aux icônes de
/// catégories sans dépendre d'une colonne "couleur" par catégorie côté DB.
const List<Color> _categoryAccents = [
  DjassaTheme.accentOrange,
  Color(0xFF3B82F6), // bleu
  Color(0xFF8B5CF6), // violet
  Color(0xFF10B981), // vert
  Color(0xFFEC4899), // rose
  Color(0xFFF59E0B), // ambre
];

const int _kHomeProductLimit = 6;
const int _kMaxRecentSearches = 8;

// ─────────────────────────────────────────────────────────────────────────
// PROVIDERS DÉRIVÉS & UTILITAIRES
// ─────────────────────────────────────────────────────────────────────────

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(userNotificationsProvider);
  return notifsAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref
      .watch(cartProvider)
      .fold<int>(0, (sum, line) => sum + line.quantity);
});

/// Set des ids favoris — lookup O(1) et rebuild ciblé via .select()
/// dans chaque carte produit, au lieu d'un .any() O(n) sur toute la liste.
final favoriteIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(favoritesProvider).map((p) => p.id).toSet();
});

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier(this._prefs) : super(_load(_prefs));
  static const _key = 'recent_searches';
  final SharedPreferences _prefs;

  static List<String> _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_key);
      return raw != null ? List<String>.from(jsonDecode(raw)) : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> add(String term) async {
    final clean = term.trim();
    if (clean.isEmpty) return;
    final next = [
      clean,
      ...state.where((t) => t.toLowerCase() != clean.toLowerCase()),
    ].take(_kMaxRecentSearches).toList();
    state = next;
    await _prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clear() async {
    state = [];
    await _prefs.remove(_key);
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
  (ref) => RecentSearchesNotifier(ref.watch(sharedPreferencesProvider)),
);

class EffectiveLocation {
  const EffectiveLocation({required this.label, required this.isManual});
  final String label;
  final bool isManual;
}

final effectiveLocationProvider =
    Provider<AsyncValue<EffectiveLocation>>((ref) {
  final saved = ref.watch(savedDeliveryAddressProvider);
  if (saved != null) {
    return AsyncValue.data(EffectiveLocation(
        label: '${saved.commune}, ${saved.city}', isManual: true));
  }
  return ref.watch(currentCommuneProvider).whenData(
        (p) => EffectiveLocation(
            label: '${p.commune}, ${p.city}', isManual: false),
      );
});

// ─────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Clé composite (orderId + status) : deux commandes différentes qui
  // atteignent le même statut célèbrent chacune la leur.
  final Set<String> _celebratedKeys = {};
  String _sortOption = 'popularite';

  Future<void> _onRefresh() async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(activeClientOrderProvider);
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider);
    final activeOrderAsync = ref.watch(activeClientOrderProvider);
    final locationAsync = ref.watch(effectiveLocationProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final recentSearches = ref.watch(recentSearchesProvider);

    ref.listen(activeClientOrderProvider, (prev, next) {
      final order = next.valueOrNull;
      if (order == null || !mounted) return;
      if (!OrderProgressInfo.isProgressForward(
          prev?.valueOrNull?.status, order.status)) return;

      final key = '${order.id}_${order.status}';
      if (_celebratedKeys.contains(key)) return;
      _celebratedKeys.add(key);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showOrderProgressCelebration(context, status: order.status);
        }
      });
    });

    if ((categoriesAsync.isLoading && !categoriesAsync.hasValue) ||
        (productsAsync.isLoading && !productsAsync.hasValue)) {
      return ShopScaffold(
        currentIndex: 0,
        title: 'Djassa.',
        darkHeader: false,
        padding: EdgeInsets.zero,
        showSellButton: false,
        child: Container(color: _bg, child: const _AmazonSkeleton()),
      );
    }

    return ShopScaffold(
      currentIndex: 0,
      title: 'Djassa.',
      darkHeader: false,
      padding: EdgeInsets.zero,
      showSellButton: false,
      onRefresh: _onRefresh,
      unreadNotificationsCount: ref.watch(unreadNotificationsCountProvider),
      child: Container(
        color: _bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AmazonHeader(locationAsync: locationAsync, cartCount: cartCount),

            if (recentSearches.isNotEmpty)
              _RecentSearchesRow(searches: recentSearches),

            activeOrderAsync.whenOrNull(
                  data: (order) => order != null
                      ? Padding(
                          padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
                          child: _HighlightedOrderTracker(order: order),
                        )
                      : const SizedBox.shrink(),
                ) ??
                const SizedBox.shrink(),

            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Catégories',
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary),
                  ),
                  GestureDetector(
                    onTap: () => context.toCategories(),
                    child: Text('Voir tout',
                        style: TextStyle(color: _accent, fontSize: 10.sp)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 1.5.h),

            categoriesAsync.when(
              data: (cats) => SizedBox(
                height: 13.h,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => SizedBox(width: 4.w),
                  itemBuilder: (_, i) => _DeliverooCategoryItem(
                    category: cats[i],
                    accent: _categoryAccents[i % _categoryAccents.length],
                  )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 40 * i),
                        duration: 260.ms,
                      )
                      .slideY(begin: 0.15, end: 0),
                ),
              ),
              loading: () => SizedBox(
                height: 13.h,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => SizedBox(width: 4.w),
                  itemBuilder: (_, __) => Container(
                    width: 16.w,
                    decoration:
                        BoxDecoration(color: _border, shape: BoxShape.circle),
                  ),
                ),
              ),
              error: (_, __) => _InlineErrorRetry(
                message: 'Impossible de charger les catégories',
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
            ),

            SizedBox(height: 3.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: const _PromoBanner(),
            ),
            SizedBox(height: 3.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recommandés pour vous',
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary),
                  ),
                  GestureDetector(
                    onTap: () => context.toSearch(),
                    child: Text('Voir tout',
                        style: TextStyle(color: _accent, fontSize: 10.sp)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 1.5.h),

            productsAsync.when(
              loading: () => Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: const ProductGridSkeleton(),
              ),
              error: (_, __) => _InlineErrorRetry(
                message: 'Impossible de charger les produits',
                onRetry: () => ref.invalidate(productsProvider),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Aucun produit',
                          style: TextStyle(color: _textSecondary)),
                    ),
                  );
                }

                final sorted = _sortProducts(products, _sortOption)
                    .take(_kHomeProductLimit)
                    .toList();

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sorted.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 1.8.h,
                      crossAxisSpacing: 3.w,
                      childAspectRatio: 0.66,
                    ),
                    itemBuilder: (_, i) {
                      final p = sorted[i];
                      return _AmazonProductCard(
                        key: ValueKey(p.id),
                        name: p.name,
                        price: p.price,
                        image: p.imageUrl ?? '',
                        id: p.id,
                        badge: p.badge,
                        rating: p.rating,
                        product: p,
                        index: i,
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  List<ShopProduct> _sortProducts(List<ShopProduct> p, String opt) {
    final list = [...p];
    switch (opt) {
      case 'prix_asc':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'prix_desc':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'recent':
        return list.reversed.toList();
      default:
        break;
    }
    return list;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// WIDGETS PARTAGÉS
// ─────────────────────────────────────────────────────────────────────────

class _InlineErrorRetry extends StatelessWidget {
  const _InlineErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_circle,
              size: 14.sp, color: _textSecondary),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 10.sp, color: _textSecondary)),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Réessayer',
                style: TextStyle(color: _accent, fontSize: 10.sp)),
          ),
        ],
      ),
    );
  }
}

/// Header remonté visuellement : fond blanc, coins arrondis en bas et
/// ombre légère pour se détacher clairement du fond gris de la page
/// (au lieu d'un simple Container plat sans profondeur).
class _AmazonHeader extends ConsumerWidget {
  const _AmazonHeader({required this.locationAsync, required this.cartCount});
  final AsyncValue<EffectiveLocation> locationAsync;
  final int cartCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = locationAsync.valueOrNull;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: DjassaTheme.shadowLight,
      ),
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showLocationPicker(context, ref),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.location_fill,
                        size: 12.sp, color: _accent),
                    SizedBox(width: 1.w),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        loc?.label ?? 'Choisir une adresse',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary),
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_down,
                        size: 8.sp, color: _textSecondary),
                  ],
                ),
              ),
              const Spacer(),
              _CartButton(count: cartCount),
              SizedBox(width: 2.5.w),
              GestureDetector(
                onTap: () => context.toProfile(),
                child: CircleAvatar(
                  radius: 1.8.h,
                  backgroundColor: _bg,
                  child: Icon(CupertinoIcons.person,
                      size: 12.sp, color: _textPrimary),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.8.h),
          Text(
            'Bonjour 👋',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 0.4.h),
          Text(
            'Que cherchez-vous aujourd\'hui ?',
            style: TextStyle(fontSize: 10.sp, color: _textSecondary),
          ),
          SizedBox(height: 1.5.h),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.toSearch(),
            child: Container(
              height: 5.4.h,
              padding: EdgeInsets.symmetric(horizontal: 3.5.w),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.search,
                      color: _textSecondary, size: 13.sp),
                  SizedBox(width: 2.5.w),
                  Expanded(
                    child: Text(
                      'Rechercher produits, boutiques, marques',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8.w))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Livrer à',
                style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            SizedBox(height: 3.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 40.h),
              child: _AddressPickerList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton panier avec badge — reprend le style Badge déjà utilisé pour
/// les notifications dans ShopScaffold, pour rester cohérent, et rend
/// enfin visible le compteur calculé par cartItemCountProvider.
class _CartButton extends StatelessWidget {
  const _CartButton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(CupertinoIcons.bag, size: 15.sp, color: _textPrimary);

    return GestureDetector(
      onTap: () => context.toCart(),
      child: Container(
        width: 3.6.h,
        height: 3.6.h,
        decoration: BoxDecoration(color: _bg, shape: BoxShape.circle),
        child: Center(
          child: count > 0
              ? Badge(
                  label: Text(count > 9 ? '9+' : '$count'),
                  backgroundColor: _accent,
                  textColor: DjassaTheme.primaryWhite,
                  child: icon,
                )
              : icon,
        ),
      ),
    );
  }
}

/// Aplati la structure ville -> communes en une seule liste paresseuse.
class _AddressPickerList extends ConsumerWidget {
  _AddressPickerList();

  late final List<_AddressPickerRow> _rows = _buildRows();

  List<_AddressPickerRow> _buildRows() {
    final rows = <_AddressPickerRow>[];
    for (final entry in deliveryCitiesCommunes.entries) {
      rows.add(_AddressPickerRow.header(entry.key));
      for (final commune in entry.value) {
        rows.add(_AddressPickerRow.commune(city: entry.key, commune: commune));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: _rows.length,
      itemBuilder: (_, i) {
        final row = _rows[i];
        if (row.isHeader) {
          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 1.h, bottom: 0.5.h),
            child: Text(row.city,
                style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
          );
        }
        return ListTile(
          dense: true,
          title: Text(row.commune!),
          onTap: () async {
            await ref
                .read(savedDeliveryAddressProvider.notifier)
                .save(row.city, row.commune!);
            if (context.mounted) Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _AddressPickerRow {
  final bool isHeader;
  final String city;
  final String? commune;
  _AddressPickerRow.header(this.city)
      : isHeader = true,
        commune = null;
  _AddressPickerRow.commune({required this.city, required String commune})
      : isHeader = false,
        commune = commune;
}

/// Ligne "recherches récentes" — rend enfin utile recentSearchesProvider,
/// qui existait déjà mais n'apparaissait nulle part sur le Home.
class _RecentSearchesRow extends ConsumerWidget {
  const _RecentSearchesRow({required this.searches});
  final List<String> searches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.8.h, 4.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recherches récentes',
                style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary),
              ),
              GestureDetector(
                onTap: () => ref.read(recentSearchesProvider.notifier).clear(),
                child: Text('Effacer',
                    style: TextStyle(color: _accent, fontSize: 9.5.sp)),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          SizedBox(
            height: 4.2.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: searches.length,
              separatorBuilder: (_, __) => SizedBox(width: 2.w),
              itemBuilder: (_, i) {
                final term = searches[i];
                return GestureDetector(
                  onTap: () => context.toSearch(query: term),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.clock, size: 10.sp, color: _textSecondary),
                        SizedBox(width: 1.2.w),
                        Text(term,
                            style: TextStyle(
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Icône variée par catégorie (accent en rotation) au lieu du même tag
/// orange répété pour toutes les catégories.
class _DeliverooCategoryItem extends StatelessWidget {
  const _DeliverooCategoryItem({required this.category, required this.accent});
  final ShopCategory category;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.toSearch(category: category.name),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16.w,
            height: 16.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: .25)),
            ),
            child: Icon(category.icon, color: accent, size: 13.sp),
          ),
          SizedBox(height: 1.h),
          SizedBox(
            width: 18.w,
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau promo avec indicateurs de page + CTA cliquable, au lieu d'un
/// simple carrousel d'images sans action ni repère de position.
class _PromoBanner extends StatefulWidget {
  const _PromoBanner();
  @override
  State<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<_PromoBanner> {
  final _controller = PageController(viewportFraction: 1);
  int _page = 0;
  Timer? _timer;

  // TODO: idéalement une table Supabase (ex: promo_banners) plutôt que du
  // hardcodé, dans la logique de ce que tu as déjà fait côté GDCI admin.
  static const _promos = [
    {
      'img':
          'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&q=80',
      'title': 'Jusqu\'à -30% sur les pièces moteur',
    },
    {
      'img':
          'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=800&q=80',
      'title': 'Livraison offerte dès 20 000 FCFA',
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (_controller.hasClients) {
        final next = _page + 1 >= _promos.length ? 0 : _page + 1;
        _controller.animateToPage(next,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.w),
      child: SizedBox(
        height: 22.h,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _promos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () => context.toCategories(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _promos[i]['img'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _border,
                          child: Icon(Icons.image_not_supported,
                              color: _textSecondary),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 3.6.h,
                        left: 4.w,
                        right: 4.w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 2.5.w, vertical: 0.5.h),
                              decoration: BoxDecoration(
                                color: _accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'OFFRE SPÉCIALE',
                                style: TextStyle(
                                    color: DjassaTheme.primaryWhite,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 8.sp),
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              _promos[i]['title'] as String,
                              style: TextStyle(
                                  color: DjassaTheme.primaryWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 2.h,
                        right: 3.5.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2.5.w, vertical: 0.7.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Voir l\'offre',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5.sp,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 1.4.h,
              right: 4.w,
              child: Row(
                children: List.generate(_promos.length, (i) {
                  final selected = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(left: 4),
                    width: selected ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte produit enrichie : badge, note, animation d'entrée — pour
/// rejoindre le niveau de finition de ProductCard dans shop_widgets.dart.
class _AmazonProductCard extends ConsumerWidget {
  const _AmazonProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.image,
    required this.id,
    required this.product,
    required this.index,
    this.badge,
    this.rating,
  });
  final String name;
  final int price;
  final String image;
  final String id;
  final ShopProduct product;
  final int index;
  final String? badge;
  final num? rating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav =
        ref.watch(favoriteIdsProvider.select((ids) => ids.contains(id)));
    final hasBadge = badge != null && badge!.trim().isNotEmpty;
    final hasRating = rating != null && rating! > 0;

    return GestureDetector(
      onTap: () => context.toProduct(id),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: DjassaTheme.shadowLight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: SizedBox(
                      width: double.infinity,
                      child: image.isEmpty
                          ? Container(
                              color: _bg,
                              child: Icon(Icons.image, color: _border),
                            )
                          : Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: _bg),
                            ),
                    ),
                  ),
                  if (hasBadge)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        final n = ref.read(favoritesProvider.notifier);
                        isFav ? n.remove(product) : n.add(product);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          size: 13.sp,
                          color: isFav ? Colors.red : _textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(2.5.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: _textPrimary),
                    ),
                    if (hasRating) ...[
                      SizedBox(height: 0.4.h),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFBBF24), size: 12),
                          const SizedBox(width: 2),
                          Text(
                            rating!.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: _textSecondary),
                          ),
                        ],
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$price FCFA',
                          style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Icon(CupertinoIcons.add,
                              color: Colors.white, size: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 40 * (index % 10)),
          duration: 280.ms,
        )
        .scale(begin: const Offset(.96, .96));
  }
}

class _HighlightedOrderTracker extends StatelessWidget {
  const _HighlightedOrderTracker({required this.order});
  final ClientActiveOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: DjassaTheme.shadowMedium,
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: OrderProgressTracker(
          key: ValueKey(order.id), order: order, compact: true),
    );
  }
}

class _AmazonSkeleton extends StatelessWidget {
  const _AmazonSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 12.h,
          color: _card,
          padding: EdgeInsets.all(4.w),
          child: Row(
            children: [
              Container(width: 40.w, height: 2.h, color: _border),
              const Spacer(),
              CircleAvatar(radius: 1.8.h, backgroundColor: _border),
            ],
          ),
        ),
        SizedBox(height: 2.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Container(
            height: 22.h,
            decoration:
                BoxDecoration(color: _border, borderRadius: BorderRadius.circular(8)),
          ),
        ),
        SizedBox(height: 3.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: List.generate(
              4,
              (i) => Container(
                width: 16.w,
                height: 16.w,
                margin: EdgeInsets.only(right: 4.w),
                decoration: BoxDecoration(color: _border, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
        SizedBox(height: 3.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 1.5.h,
              crossAxisSpacing: 3.w,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(8),
                boxShadow: DjassaTheme.shadowLight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}