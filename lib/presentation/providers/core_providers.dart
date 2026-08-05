import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Imports Domain & Data ---
import '../../data/repositories/user_repository_impl.dart';
import '../../data/sources/local/local_data_source.dart';
import '../../data/sources/remote/admin_service.dart';
import '../../data/sources/remote/remote_data_source.dart';
import '../../data/sources/remote/shop_service.dart';
import '../../data/services/admin_notification_service.dart';
import '../../data/services/courier_order_service.dart';
import '../../data/services/courier_profile_service.dart';
import '../../data/services/delivery_tracking_service.dart';
import '../../data/services/client_order_tracking_service.dart';
import '../../data/services/order_chat_service.dart';
import '../../data/services/structure_service.dart';
import '../../core/services/geniuspay_service.dart';
import '../../core/services/location_commune_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/marketplace/marketplace_taxonomy.dart';
import '../../domain/entities/structure.dart';
import '../screens/shop/shop_data.dart'; // Assure-toi que ce chemin est correct
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/auth_usecases.dart' show LoginUser, RegisterUser;
import '../../domain/usecases/user_usecases.dart'
    show
        ClearUserLocally,
        GetCurrentUser,
        GetUserLocally,
        IsLoggedIn,
        Logout,
        SaveUserLocally,
        UpdateProfile;

// ============================================================================
// 1. CONFIGURATION & CONSTANTES (Pas besoin de Riverpod pour ça)
// ============================================================================

/// Villes/communes utilisables dans le profil et au checkout.
/// Const pour éviter toute allocation mémoire inutile à chaque rebuild.
const Map<String, List<String>> deliveryCitiesCommunes = {
  'Abidjan': [
    'Abobo',
    'Adjamé',
    'Attécoubé',
    'Cocody',
    'Koumassi',
    'Marcory',
    'Plateau',
    'Port-Bouët',
    'Treichville',
    'Yopougon',
  ],
  'Bingerville': ['Bingerville Centre'],
  'Anyama': ['Anyama Centre', 'Afeffy'],
  'Songon': ['Songon Centre'],
  'Grand-Bassam': ['Grand-Bassam Centre', 'Moossou'],
};

const Map<String, List<String>> deliveryCommuneNeighborhoods = {
  'Abobo': [
    'Abobo Baoule',
    'Abobo Belleville',
    'Abobo Centre',
    'Abobo Gare',
    'Abobo N\'Dotre',
    'Abobo PK18',
    'Agbekoi',
    'Anador',
    'Avocatier',
    'Banco',
    'BC',
    'Clouetcha',
    'Dokui',
    'Kennedy',
    'Plaque',
    'Sagam',
    'Sogefiha',
    'Sos Abobo',
  ],
  'Adjamé': [
    // Correction encoding si nécessaire
    '220 Logements', 'Adjame Centre', 'Bromakote', 'Dallas', 'Forum',
    'Gare Nord', 'Liberte', 'Mairie', 'Marche Gouro', 'Mirador',
    'Saint Michel', 'Williamsville',
  ],
  'Attécoubé': [
    'Agban Attie',
    'Attecoube 3',
    'Attecoube Centre',
    'Banco',
    'Boribana',
    'Cite Fairmont',
    'Djen Ecarre',
    'Douagoville',
    'Fromager',
    'Locodjro',
    'Mosquee',
    'Sante',
  ],
  'Cocody': [
    '2 Plateaux',
    'Angre',
    'Ambassades',
    'Attoban',
    'Beverly Hills',
    'Blockhauss',
    'Bonoumin',
    'Cocody Centre',
    'Danga',
    'Faya',
    'Genie 2000',
    'II Plateaux Vallon',
    'Les Oscars',
    'Mermoz',
    'Palmeraie',
    'Riviera 1',
    'Riviera 2',
    'Riviera 3',
    'Riviera 4',
    'Riviera Bonoumin',
    'Riviera Golf',
    'Riviera M\'Badon',
    'Saint Jean',
    'Sodefor',
  ],
  'Koumassi': [
    '05',
    'Aklomiabla',
    'Divo',
    'Grand Carrefour',
    'Inch Allah',
    'Koumassi Campement',
    'Koumassi Centre',
    'Nord-Est',
    'Prodomo',
    'Remblais',
    'Sicogi',
    'Sopim',
    'Zone Industrielle',
  ],
  'Marcory': [
    'Anoumabo',
    'Bietry',
    'Champroux',
    'GFCI',
    'Marcory Centre',
    'Marcory Residentiel',
    'Prima',
    'Remblai',
    'Sicogi',
    'Zone 4',
    'Zone Industrielle',
  ],
  'Plateau': [
    'Avenue Chardy',
    'Avenue Nogues',
    'Cite Administrative',
    'Commerce',
    'Gare Sud',
    'Indenie',
    'Plateau Centre',
    'Presidence',
    'Sorbonne',
  ],
  'Port-Bouët': [
    'Adjouffou',
    'Anani',
    'Aeroport',
    'Gonzagueville',
    'Jean Folly',
    'Petit Bassam',
    'Phare',
    'Port-Bouet Centre',
    'Sogefiha',
    'Vridi',
    'Vridi Canal',
    'Vridi Cite',
    'Zone Industrielle',
  ],
  'Treichville': [
    'Arras',
    'Avenue 8',
    'Biafra',
    'Cite Administrative',
    'Habitat',
    'Marche de Treichville',
    'Nanan Yamousso',
    'Port',
    'Treichville Centre',
    'Zone 1',
    'Zone 2',
    'Zone 3',
  ],
  'Yopougon': [
    'Andokoi',
    'Ananeraie',
    'Banco Nord',
    'Camp Militaire',
    'Cite CIE',
    'Cite Verte',
    'Gesco',
    'Koweit',
    'Lubafrique',
    'Maroc',
    'Niangon Nord',
    'Niangon Sud',
    'Port-Bouet 2',
    'Sable',
    'Selmer',
    'Sicogi',
    'Sideci',
    'Sogefiha',
    'Toit Rouge',
    'Wassakara',
    'Yopougon Centre',
  ],
  'Bingerville Centre': ['Bingerville Centre'],
  'Anyama Centre': ['Anyama Centre'],
  'Afeffy': ['Afeffy'],
  'Songon Centre': ['Songon Centre'],
  'Grand-Bassam Centre': ['Grand-Bassam Centre'],
  'Moossou': ['Moossou'],
};

// Frais de livraison fixes (peut devenir dynamique plus tard via Provider)
const int defaultDeliveryFee = 2500;

// ============================================================================
// 2. CORE PROVIDERS (Infrastructure)
// ============================================================================

/// SharedPreferences
/// ⚠️ DOIT être initialisé dans main() avant runApp() ou via FutureProvider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Initialisez SharedPreferences dans main() et override ce provider.',
  );
});

// ============================================================================
// 3. DATA SOURCES & SERVICES (Singletons)
// ============================================================================

/// Local Data Source
final localDataSourceProvider = Provider<LocalDataSource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalDataSource(prefs: prefs);
});

/// Remote Data Source (Supabase)
final remoteDataSourceProvider = Provider<RemoteDataSource>((ref) {
  return RemoteDataSource();
});
// Dans core_providers.dart

/// Frais de livraison (Provider pour permettre une future dynamique)
final deliveryFeeProvider = Provider<int>((ref) => 2500);

/// Shop Service
final shopServiceProvider = Provider<ShopService>((ref) {
  return ShopService();
});

/// Admin Service
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});

/// Admin Notification Service
final adminNotificationServiceProvider =
    Provider<AdminNotificationService>((ref) {
  return AdminNotificationService();
});

final deliveryTrackingServiceProvider =
    Provider<DeliveryTrackingService>((ref) {
  return DeliveryTrackingService();
});

final courierOrderServiceProvider = Provider<CourierOrderService>((ref) {
  return CourierOrderService();
});

final courierProfileServiceProvider = Provider<CourierProfileService>((ref) {
  return CourierProfileService();
});

final structureServiceProvider = Provider<StructureService>((ref) {
  return StructureService();
});

final geniusPayServiceProvider = Provider<GeniusPayService>((ref) {
  return GeniusPayService(SupabaseService.client);
});

final locationCommuneServiceProvider = Provider<LocationCommuneService>((ref) {
  return LocationCommuneService();
});

final clientOrderTrackingServiceProvider =
    Provider<ClientOrderTrackingService>((ref) {
  return ClientOrderTrackingService();
});

final orderChatServiceProvider = Provider<OrderChatService>((ref) {
  return OrderChatService();
});

// ============================================================================
// 4. DOMAIN / REPOSITORY LAYER
// ============================================================================

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final remoteDataSource = ref.watch(remoteDataSourceProvider);
  return UserRepositoryImpl(
    prefs: prefs,
    remoteDataSource: remoteDataSource,
  );
});

// ============================================================================
// 5. USE CASES
// ============================================================================

final loginUserProvider = Provider((ref) {
  return LoginUser(repository: ref.watch(userRepositoryProvider));
});

final registerUserProvider = Provider((ref) {
  return RegisterUser(repository: ref.watch(userRepositoryProvider));
});

final getCurrentUserProvider = Provider((ref) {
  return GetCurrentUser(repository: ref.watch(userRepositoryProvider));
});

final isLoggedInProvider = Provider((ref) {
  return IsLoggedIn(repository: ref.watch(userRepositoryProvider));
});

final logoutProvider = Provider((ref) {
  return Logout(repository: ref.watch(userRepositoryProvider));
});

final saveUserLocallyProvider = Provider((ref) {
  return SaveUserLocally(repository: ref.watch(userRepositoryProvider));
});

final getUserLocallyProvider = Provider((ref) {
  return GetUserLocally(repository: ref.watch(userRepositoryProvider));
});

final clearUserLocallyProvider = Provider((ref) {
  return ClearUserLocally(repository: ref.watch(userRepositoryProvider));
});

final updateProfileProvider = Provider((ref) {
  return UpdateProfile(repository: ref.watch(userRepositoryProvider));
});

// ============================================================================
// 6. STATE NOTIFIERS (UI State & Persistence)
// ============================================================================

// --- Delivery Address ---

class DeliveryAddress {
  const DeliveryAddress({required this.city, required this.commune});
  final String city;
  final String commune;
  String get label => '$commune, $city';

  Map<String, dynamic> toJson() => {'city': city, 'commune': commune};

  static DeliveryAddress? fromJson(Map<String, dynamic> json) {
    final city = json['city']?.toString();
    final commune = json['commune']?.toString();
    if (city == null || city.isEmpty || commune == null || commune.isEmpty)
      return null;
    return DeliveryAddress(city: city, commune: commune);
  }
}

class SavedDeliveryAddressNotifier extends StateNotifier<DeliveryAddress?> {
  SavedDeliveryAddressNotifier(this._prefs) : super(_load(_prefs));
  static const _prefsKey = 'saved_delivery_address';
  final SharedPreferences _prefs;

  static DeliveryAddress? _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      return DeliveryAddress.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String city, String commune) async {
    final address = DeliveryAddress(city: city, commune: commune);
    try {
      await _prefs.setString(_prefsKey, jsonEncode(address.toJson()));
      state = address;
    } catch (e) {
      // Log error but don't crash UI
      print('Failed to save delivery address: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_prefsKey);
      state = null;
    } catch (e) {
      print('Failed to clear delivery address: $e');
    }
  }
}

final savedDeliveryAddressProvider =
    StateNotifierProvider<SavedDeliveryAddressNotifier, DeliveryAddress?>(
  (ref) => SavedDeliveryAddressNotifier(ref.watch(sharedPreferencesProvider)),
);

// --- Payment Method ---

class SavedPaymentMethod {
  const SavedPaymentMethod({required this.provider, required this.phone});
  final String provider;
  final String phone;
  bool get isConfigured => provider.isNotEmpty && phone.length >= 8;

  Map<String, dynamic> toJson() => {'provider': provider, 'phone': phone};

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) {
    return SavedPaymentMethod(
      provider: '${json['provider'] ?? 'wave'}',
      phone: '${json['phone'] ?? ''}',
    );
  }
}

class SavedPaymentMethodNotifier extends StateNotifier<SavedPaymentMethod?> {
  SavedPaymentMethodNotifier(this._prefs) : super(_load(_prefs));
  static const _prefsKey = 'saved_payment_method';
  final SharedPreferences _prefs;

  static SavedPaymentMethod? _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      return SavedPaymentMethod.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> save({required String provider, required String phone}) async {
    final method = SavedPaymentMethod(provider: provider, phone: phone.trim());
    try {
      await _prefs.setString(_prefsKey, jsonEncode(method.toJson()));
      state = method;
    } catch (e) {
      print('Failed to save payment method: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_prefsKey);
      state = null;
    } catch (e) {
      print('Failed to clear payment method: $e');
    }
  }
}

final savedPaymentMethodProvider =
    StateNotifierProvider<SavedPaymentMethodNotifier, SavedPaymentMethod?>(
  (ref) => SavedPaymentMethodNotifier(ref.watch(sharedPreferencesProvider)),
);

// --- Delivery Tracking ---

enum DeliveryTrackingStage { created, scheduled, shipping, delivered }

class DeliveryTracking {
  const DeliveryTracking({
    required this.orderId,
    required this.orderNumber,
    required this.address,
    required this.createdAt,
    required this.deliveryAt,
    this.clientLatitude,
    this.clientLongitude,
  });

  final String orderId;
  final String orderNumber;
  final String address;
  final DateTime createdAt;
  final DateTime deliveryAt;
  final double? clientLatitude;
  final double? clientLongitude;

  DeliveryTrackingStage stageAt(DateTime now) {
    final deliveryMorning =
        DateTime(deliveryAt.year, deliveryAt.month, deliveryAt.day, 8);
    if (!now.isBefore(deliveryAt)) return DeliveryTrackingStage.delivered;
    if (!now.isBefore(deliveryMorning)) return DeliveryTrackingStage.shipping;
    if (now.difference(createdAt) < const Duration(minutes: 3)) {
      return DeliveryTrackingStage.created;
    }
    return DeliveryTrackingStage.scheduled;
  }

  double progressAt(DateTime now) {
    switch (stageAt(now)) {
      case DeliveryTrackingStage.created:
        return .12;
      case DeliveryTrackingStage.scheduled:
        return .36;
      case DeliveryTrackingStage.shipping:
        final deliveryMorning =
            DateTime(deliveryAt.year, deliveryAt.month, deliveryAt.day, 8);
        final total = deliveryAt.difference(deliveryMorning).inSeconds;
        if (total <= 0) return 0.93;
        final elapsed = now.difference(deliveryMorning).inSeconds;
        return (.48 + (.45 * (elapsed / total))).clamp(.48, .93);
      case DeliveryTrackingStage.delivered:
        return 1;
    }
  }

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'address': address,
        'createdAt': createdAt.toIso8601String(),
        'deliveryAt': deliveryAt.toIso8601String(),
        'clientLatitude': clientLatitude,
        'clientLongitude': clientLongitude,
      };

  static DeliveryTracking? fromJson(Map<String, dynamic> json) {
    final orderId = json['orderId']?.toString();
    final orderNumber = json['orderNumber']?.toString();
    final address = json['address']?.toString();
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    final deliveryAt = DateTime.tryParse('${json['deliveryAt']}');

    if (orderId == null ||
        orderId.isEmpty ||
        orderNumber == null ||
        orderNumber.isEmpty ||
        address == null ||
        address.isEmpty ||
        createdAt == null ||
        deliveryAt == null) {
      return null;
    }

    return DeliveryTracking(
      orderId: orderId,
      orderNumber: orderNumber,
      address: address,
      createdAt: createdAt,
      deliveryAt: deliveryAt,
      clientLatitude: double.tryParse('${json['clientLatitude']}'),
      clientLongitude: double.tryParse('${json['clientLongitude']}'),
    );
  }
}

class DeliveryTrackingNotifier extends StateNotifier<DeliveryTracking?> {
  DeliveryTrackingNotifier(this._prefs) : super(_load(_prefs));
  static const _prefsKey = 'active_delivery_tracking';
  static const _announcedPrefix = 'delivery_stage_announced_';
  final SharedPreferences _prefs;

  static DeliveryTracking? _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      return DeliveryTracking.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<DeliveryTracking> start({
    required String orderId,
    required String orderNumber,
    required String address,
    double? clientLatitude,
    double? clientLongitude,
  }) async {
    final now = DateTime.now();
    final tracking = DeliveryTracking(
      orderId: orderId,
      orderNumber: orderNumber,
      address: address,
      createdAt: now,
      deliveryAt: DateTime(now.year, now.month, now.day + 1, 18),
      clientLatitude: clientLatitude,
      clientLongitude: clientLongitude,
    );
    try {
      await _prefs.setString(_prefsKey, jsonEncode(tracking.toJson()));
      state = tracking;
    } catch (e) {
      print('Failed to start tracking: $e');
    }
    return tracking;
  }

  bool wasStageAnnounced(String orderId, DeliveryTrackingStage stage) {
    return _prefs.getBool('$_announcedPrefix${orderId}_${stage.name}') ?? false;
  }

  Future<void> markStageAnnounced(
      String orderId, DeliveryTrackingStage stage) async {
    try {
      await _prefs.setBool('$_announcedPrefix${orderId}_${stage.name}', true);
    } catch (e) {
      print('Failed to mark stage announced: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_prefsKey);
      state = null;
    } catch (e) {
      print('Failed to clear tracking: $e');
    }
  }

  Future<void> clearIfDelivered() async {
    final current = state;
    if (current != null &&
        current.stageAt(DateTime.now()) == DeliveryTrackingStage.delivered) {
      await clear();
    }
  }
}

final deliveryTrackingProvider =
    StateNotifierProvider<DeliveryTrackingNotifier, DeliveryTracking?>(
  (ref) => DeliveryTrackingNotifier(ref.watch(sharedPreferencesProvider)),
);

final deliveryTrackingClockProvider = StreamProvider.autoDispose<DateTime>(
  (ref) async* {
    while (true) {
      yield DateTime.now();
      await Future<void>.delayed(const Duration(seconds: 20));
    }
  },
);

// --- Cart (Persistent) ---

final cartProvider = StateNotifierProvider<CartNotifier, List<CartLine>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CartNotifier(prefs);
});

class CartNotifier extends StateNotifier<List<CartLine>> {
  CartNotifier(this._prefs) : super(_load(_prefs));
  static const _prefsKey = 'cart_lines';
  final SharedPreferences _prefs;

  static List<CartLine> _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return []; // Start empty if no cache
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => CartLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _persist() {
    try {
      final raw = jsonEncode(state.map((line) => line.toJson()).toList());
      _prefs.setString(_prefsKey, raw);
    } catch (_) {
      // Ignore persistence errors to keep UI responsive
    }
  }

  int get itemCount => state.fold<int>(0, (sum, line) => sum + line.quantity);
  int get subtotal => state.fold<int>(
      0, (sum, line) => sum + line.product.price * line.quantity);

  void add(ShopProduct product, {int quantity = 1}) {
    final safeQuantity =
        quantity.clamp(1, product.stock <= 0 ? 1 : product.stock).toInt();
    final index = state.indexWhere((line) => line.product.id == product.id);

    if (index == -1) {
      state = [...state, CartLine(product: product, quantity: safeQuantity)];
    } else {
      final next = [...state];
      final current = next[index];
      final maxQuantity =
          product.stock <= 0 ? current.quantity + safeQuantity : product.stock;
      next[index] = CartLine(
        product: product,
        quantity:
            (current.quantity + safeQuantity).clamp(1, maxQuantity).toInt(),
      );
      state = next;
    }
    _persist();
  }

  void increment(String productId) {
    state = state.map((line) {
      if (line.product.id != productId) return line;
      final maxQuantity =
          line.product.stock <= 0 ? line.quantity + 1 : line.product.stock;
      return CartLine(
        product: line.product,
        quantity: (line.quantity + 1).clamp(1, maxQuantity).toInt(),
      );
    }).toList();
    _persist();
  }

  void decrement(String productId) {
    state = state.map((line) {
      if (line.product.id != productId || line.quantity <= 1) return line;
      return CartLine(product: line.product, quantity: line.quantity - 1);
    }).toList();
    _persist();
  }

  void remove(String productId) {
    state = state.where((line) => line.product.id != productId).toList();
    _persist();
  }

  void clear() {
    state = [];
    _persist();
  }
}

// --- Favorites ---

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<ShopProduct>>((ref) {
  return FavoritesNotifier(const []);
});

class FavoritesNotifier extends StateNotifier<List<ShopProduct>> {
  FavoritesNotifier(super.initial);

  bool contains(String productId) =>
      state.any((product) => product.id == productId);

  void remove(ShopProduct product) {
    state = state.where((p) => p.id != product.id).toList();
  }

  void add(ShopProduct product) {
    if (!contains(product.id)) {
      state = [...state, product];
    }
  }
}

// ============================================================================
// 7. ADVANCED CACHING STRATEGY (Stale-While-Revalidate)
// ============================================================================

/// Generic cached list notifier.
/// Loads from disk immediately, then fetches from network in background.
class CachedListNotifier<T> extends StateNotifier<AsyncValue<List<T>>> {
  CachedListNotifier({
    required SharedPreferences prefs,
    required String cacheKey,
    required Future<List<T>> Function() fetch,
    required Map<String, dynamic> Function(T item) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
    List<T> fallback = const [],
  })  : _prefs = prefs,
        _cacheKey = cacheKey,
        _fetch = fetch,
        _toJson = toJson,
        _fromJson = fromJson,
        _fallback = fallback,
        super(const AsyncValue.loading()) {
    _init();
  }

  final SharedPreferences _prefs;
  final String _cacheKey;
  final Future<List<T>> Function() _fetch;
  final Map<String, dynamic> Function(T item) _toJson;
  final T Function(Map<String, dynamic> json) _fromJson;
  final List<T> _fallback;

  Future<void> _init() async {
    // 1. Load from cache immediately
    final cached = _readCache();
    if (cached != null && cached.isNotEmpty) {
      state = AsyncValue.data(cached);
    }

    // 2. Fetch from network in background
    await _fetchAndUpdate(hasCache: cached != null && cached.isNotEmpty);
  }

  Future<void> _fetchAndUpdate({required bool hasCache}) async {
    try {
      // Add timeout to prevent hanging forever
      final fresh = await _fetch().timeout(const Duration(seconds: 10));

      if (fresh.isNotEmpty) {
        _writeCache(fresh);
      }

      if (mounted) {
        state = AsyncValue.data(fresh.isEmpty ? _fallback : fresh);
      }
    } catch (e, stackTrace) {
      // If we have cache, stay on cache (silent fail)
      // If no cache, show error
      if (!hasCache && mounted) {
        if (_fallback.isNotEmpty) {
          state = AsyncValue.data(_fallback);
        } else {
          state = AsyncValue.error(e, stackTrace);
        }
      } else if (mounted) {
        // Optional: Show a small snackbar that data might be old
        // But don't change the main state to error
      }
    }
  }

  /// Force refresh (e.g., pull-to-refresh)
  Future<void> refresh() async {
    state = const AsyncValue.loading(); // Show loading indicator briefly
    final cached = _readCache();
    await _fetchAndUpdate(hasCache: cached != null && cached.isNotEmpty);
  }

  List<T>? _readCache() {
    try {
      final raw = _prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => _fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  void _writeCache(List<T> items) {
    try {
      final raw = jsonEncode(items.map(_toJson).toList());
      _prefs.setString(_cacheKey, raw);
    } catch (_) {
      // Ignore serialization errors
    }
  }
}

// ============================================================================
// 8. SHOP PROVIDERS (Using Cache)
// ============================================================================

final categoriesProvider = StateNotifierProvider<
    CachedListNotifier<ShopCategory>, AsyncValue<List<ShopCategory>>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = ref.watch(shopServiceProvider);
  return CachedListNotifier<ShopCategory>(
    prefs: prefs,
    cacheKey: 'cache_shop_categories',
    fetch: () => service.fetchCategories(),
    toJson: (c) => c.toJson(),
    fromJson: ShopCategory.fromJson,
    fallback: MarketplaceTaxonomy.categories
        .map(
          (category) => ShopCategory(
            name: category.name,
            icon: category.icon,
            iconName: category.iconName,
            subtitle: category.subtitle,
            itemsCount: 0,
          ),
        )
        .toList(),
  );
});

final productsProvider = StateNotifierProvider<CachedListNotifier<ShopProduct>,
    AsyncValue<List<ShopProduct>>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = ref.watch(shopServiceProvider);
  return CachedListNotifier<ShopProduct>(
    prefs: prefs,
    cacheKey: 'cache_shop_products',
    fetch: () => service.fetchProducts(),
    toJson: (p) => p.toJson(),
    fromJson: ShopProduct.fromJson,
  );
});

final vendorProductsProvider =
    FutureProvider.autoDispose.family<List<ShopProduct>, String>(
  (ref, structureId) async {
    if (structureId.trim().isEmpty) return const [];
    return ref
        .watch(shopServiceProvider)
        .fetchVendorProducts(structureId: structureId);
  },
);

final ordersProvider = FutureProvider<List<OrderPreview>>((ref) async {
  try {
    return await ref.watch(shopServiceProvider).fetchOrders();
  } catch (_) {
    return const [];
  }
});

// ============================================================================
// 9. STREAM PROVIDERS (Real-time)
// ============================================================================

final activeClientOrderProvider =
    StreamProvider.autoDispose<ClientActiveOrder?>((ref) {
  return ref.watch(clientOrderTrackingServiceProvider).watchActive();
});

final vendorStructureProvider = FutureProvider<Structure>((ref) async {
  return ref.watch(structureServiceProvider).fetchMine();
});

final vendorOrdersProvider =
    FutureProvider.autoDispose<List<VendorOrder>>((ref) async {
  return ref.watch(structureServiceProvider).fetchVendorOrders();
});

final courierOrdersProvider =
    StreamProvider.autoDispose<List<CourierOrder>>((ref) {
  return ref.watch(courierOrderServiceProvider).watchOrders();
});

final liveDeliveryTrackingProvider =
    StreamProvider.autoDispose.family<DeliveryLiveSnapshot, DeliveryTracking>(
  (ref, tracking) {
    final service = ref.watch(deliveryTrackingServiceProvider);
    return service.watchOrder(
      DeliveryTrackingQuery(
        orderId: tracking.orderId,
        address: tracking.address,
        createdAt: tracking.createdAt,
        deliveryAt: tracking.deliveryAt,
        clientLatitude: tracking.clientLatitude,
        clientLongitude: tracking.clientLongitude,
      ),
    );
  },
);

final clientLocationPublisherProvider = StreamProvider.autoDispose
    .family<DeliveryPositionPublishStatus, DeliveryTracking>(
  (ref, tracking) {
    final service = ref.watch(deliveryTrackingServiceProvider);
    return service.publishDevicePosition(
        orderId: tracking.orderId, role: 'client');
  },
);

final courierLocationPublisherProvider = StreamProvider.autoDispose
    .family<DeliveryPositionPublishStatus, DeliveryTracking>(
  (ref, tracking) {
    final service = ref.watch(deliveryTrackingServiceProvider);
    return service.publishDevicePosition(
        orderId: tracking.orderId, role: 'courier');
  },
);

// ============================================================================
// 10. ADMIN & NOTIFICATIONS
// ============================================================================

final isAdminProvider = FutureProvider<bool>((ref) async {
  return ref.watch(adminServiceProvider).isCurrentUserAdmin();
});

final adminCategoriesProvider =
    FutureProvider.autoDispose<List<AdminCategory>>((ref) async {
  return ref.watch(adminServiceProvider).fetchCategories();
});

final adminProductsProvider =
    FutureProvider.autoDispose<List<AdminProduct>>((ref) async {
  return ref.watch(adminServiceProvider).fetchProducts();
});

final adminNotificationsProvider =
    FutureProvider.autoDispose<List<AdminNotification>>((ref) async {
  return ref.watch(adminNotificationServiceProvider).fetchAll();
});

final userNotificationsProvider =
    FutureProvider<List<AdminNotification>>((ref) async {
  return ref.watch(adminNotificationServiceProvider).fetchAll();
});

final notifUsersProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  return ref.watch(adminNotificationServiceProvider).fetchUsers();
});

final currentCommuneProvider = FutureProvider<CommunePosition>((ref) async {
  return ref.watch(locationCommuneServiceProvider).currentCommune();
});

final courierProfileProvider = FutureProvider<CourierProfile>((ref) async {
  return ref.watch(courierProfileServiceProvider).fetch();
});
