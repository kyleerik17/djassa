import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/user_repository_impl.dart';
import '../../data/sources/local/local_data_source.dart';
import '../../data/sources/remote/admin_service.dart';
import '../../data/sources/remote/remote_data_source.dart';
import '../../data/sources/remote/shop_service.dart';
import '../../data/services/admin_notification_service.dart'; // ← notifications
import '../../data/services/courier_order_service.dart';
import '../../data/services/courier_profile_service.dart';
import '../../data/services/delivery_tracking_service.dart';
import '../../data/services/client_order_tracking_service.dart';
import '../../data/services/order_chat_service.dart';
import '../../data/services/structure_service.dart';
import '../../core/services/geniuspay_service.dart';
import '../../core/services/location_commune_service.dart';
import '../../core/services/supabase_service.dart';
import '../../domain/entities/structure.dart';
import '../screens/shop/shop_data.dart';

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

/// SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Initialisez SharedPreferences dans main()',
  );
});

/// Villes/communes utilisables dans le profil et au checkout.
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
  'AdjamÃ©': [
    '220 Logements',
    'Adjame Centre',
    'Bromakote',
    'Dallas',
    'Forum',
    'Gare Nord',
    'Liberte',
    'Mairie',
    'Marche Gouro',
    'Mirador',
    'Saint Michel',
    'Williamsville',
  ],
  'AttÃ©coubÃ©': [
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
  'Port-BouÃ«t': [
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

class DeliveryAddress {
  const DeliveryAddress({
    required this.city,
    required this.commune,
  });

  final String city;
  final String commune;

  String get label => '$commune, $city';

  Map<String, dynamic> toJson() => {
        'city': city,
        'commune': commune,
      };

  static DeliveryAddress? fromJson(Map<String, dynamic> json) {
    final city = json['city']?.toString();
    final commune = json['commune']?.toString();
    if (city == null || city.isEmpty || commune == null || commune.isEmpty) {
      return null;
    }
    return DeliveryAddress(city: city, commune: commune);
  }
}

class SavedDeliveryAddressNotifier extends StateNotifier<DeliveryAddress?> {
  SavedDeliveryAddressNotifier(this._prefs) : super(_load(_prefs));

  static const _prefsKey = 'saved_delivery_address';

  final SharedPreferences _prefs;

  static DeliveryAddress? _load(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DeliveryAddress.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String city, String commune) async {
    final address = DeliveryAddress(city: city, commune: commune);
    await _prefs.setString(_prefsKey, jsonEncode(address.toJson()));
    state = address;
  }

  Future<void> clear() async {
    await _prefs.remove(_prefsKey);
    state = null;
  }
}

final savedDeliveryAddressProvider =
    StateNotifierProvider<SavedDeliveryAddressNotifier, DeliveryAddress?>(
  (ref) => SavedDeliveryAddressNotifier(ref.watch(sharedPreferencesProvider)),
);

// ── Préférences paiement Mobile Money ─────────────────────────

class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.provider,
    required this.phone,
  });

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
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SavedPaymentMethod.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save({required String provider, required String phone}) async {
    final method = SavedPaymentMethod(provider: provider, phone: phone.trim());
    await _prefs.setString(_prefsKey, jsonEncode(method.toJson()));
    state = method;
  }

  Future<void> clear() async {
    await _prefs.remove(_prefsKey);
    state = null;
  }
}

final savedPaymentMethodProvider =
    StateNotifierProvider<SavedPaymentMethodNotifier, SavedPaymentMethod?>(
  (ref) => SavedPaymentMethodNotifier(ref.watch(sharedPreferencesProvider)),
);

enum DeliveryTrackingStage {
  created,
  scheduled,
  shipping,
  delivered,
}

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
    final deliveryMorning = DateTime(
      deliveryAt.year,
      deliveryAt.month,
      deliveryAt.day,
      8,
    );
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
        final deliveryMorning = DateTime(
          deliveryAt.year,
          deliveryAt.month,
          deliveryAt.day,
          8,
        );
        final total = deliveryAt.difference(deliveryMorning).inSeconds;
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
    final clientLatitude = double.tryParse('${json['clientLatitude']}');
    final clientLongitude = double.tryParse('${json['clientLongitude']}');
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
      clientLatitude: clientLatitude,
      clientLongitude: clientLongitude,
    );
  }
}

class DeliveryTrackingNotifier extends StateNotifier<DeliveryTracking?> {
  DeliveryTrackingNotifier(this._prefs) : super(_load(_prefs));

  static const _prefsKey = 'active_delivery_tracking';
  static const _announcedPrefix = 'delivery_stage_announced_';

  final SharedPreferences _prefs;

  static DeliveryTracking? _load(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DeliveryTracking.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
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
    await _prefs.setString(_prefsKey, jsonEncode(tracking.toJson()));
    state = tracking;
    return tracking;
  }

  bool wasStageAnnounced(String orderId, DeliveryTrackingStage stage) {
    return _prefs.getBool('$_announcedPrefix${orderId}_${stage.name}') ?? false;
  }

  Future<void> markStageAnnounced(
    String orderId,
    DeliveryTrackingStage stage,
  ) async {
    await _prefs.setBool('$_announcedPrefix${orderId}_${stage.name}', true);
  }

  Future<void> clear() async {
    await _prefs.remove(_prefsKey);
    state = null;
  }

  Future<void> clearIfDelivered() async {
    final current = state;
    if (current == null) return;
    if (current.stageAt(DateTime.now()) == DeliveryTrackingStage.delivered) {
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

/// Frais de livraison dynamiques
final deliveryFeeProvider = Provider<int>((ref) => 2500);

/// Local Data Source
final localDataSourceProvider = Provider<LocalDataSource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalDataSource(prefs: prefs);
});

/// Remote Data Source (Supabase)
final remoteDataSourceProvider = Provider<RemoteDataSource>((ref) {
  return RemoteDataSource();
});

/// Shop Service (Supabase)
final shopServiceProvider = Provider<ShopService>((ref) {
  return ShopService();
});

/// Admin Service (Backoffice Supabase)
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

final courierProfileProvider = FutureProvider<CourierProfile>((ref) async {
  return ref.watch(courierProfileServiceProvider).fetch();
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

final currentCommuneProvider = FutureProvider<CommunePosition>((ref) async {
  return ref.watch(locationCommuneServiceProvider).currentCommune();
});

final clientOrderTrackingServiceProvider =
    Provider<ClientOrderTrackingService>((ref) {
  return ClientOrderTrackingService();
});

final orderChatServiceProvider = Provider<OrderChatService>((ref) {
  return OrderChatService();
});

/// Commande en cours du client (temps réel Supabase).
final activeClientOrderProvider =
    StreamProvider.autoDispose<ClientActiveOrder?>((ref) {
  return ref.watch(clientOrderTrackingServiceProvider).watchActive();
});

final vendorStructureProvider = FutureProvider<Structure>((ref) async {
  final structure = await ref.watch(structureServiceProvider).fetchMine();
  return structure;
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
      orderId: tracking.orderId,
      role: 'client',
    );
  },
);

final courierLocationPublisherProvider = StreamProvider.autoDispose
    .family<DeliveryPositionPublishStatus, DeliveryTracking>(
  (ref, tracking) {
    final service = ref.watch(deliveryTrackingServiceProvider);
    return service.publishDevicePosition(
      orderId: tracking.orderId,
      role: 'courier',
    );
  },
);

// ── Admin providers ───────────────────────────────────────────

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

// ── Notifications providers ───────────────────────────────────

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

// ── Shop providers ────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<ShopCategory>>((ref) async {
  return ref.watch(shopServiceProvider).fetchCategories();
});

final productsProvider = FutureProvider<List<ShopProduct>>((ref) async {
  return ref.watch(shopServiceProvider).fetchProducts();
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

// ── Panier ────────────────────────────────────────────────────

final cartProvider = StateNotifierProvider<CartNotifier, List<CartLine>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<CartLine>> {
  CartNotifier() : super(List<CartLine>.from(cartLines));

  int get itemCount => state.fold<int>(0, (sum, line) => sum + line.quantity);

  int get subtotal => state.fold<int>(
        0,
        (sum, line) => sum + line.product.price * line.quantity,
      );

  void add(ShopProduct product, {int quantity = 1}) {
    final safeQuantity =
        quantity.clamp(1, product.stock <= 0 ? 1 : product.stock).toInt();
    final index = state.indexWhere((line) => line.product.id == product.id);

    if (index == -1) {
      state = [...state, CartLine(product: product, quantity: safeQuantity)];
      return;
    }

    final next = [...state];
    final current = next[index];
    final maxQuantity =
        product.stock <= 0 ? current.quantity + safeQuantity : product.stock;
    next[index] = CartLine(
      product: product,
      quantity: (current.quantity + safeQuantity).clamp(1, maxQuantity).toInt(),
    );
    state = next;
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
  }

  void decrement(String productId) {
    state = state.map((line) {
      if (line.product.id != productId || line.quantity <= 1) return line;
      return CartLine(product: line.product, quantity: line.quantity - 1);
    }).toList();
  }

  void remove(String productId) {
    state = state.where((line) => line.product.id != productId).toList();
  }

  void clear() {
    state = [];
  }
}

// ── User Repository ───────────────────────────────────────────

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final remoteDataSource = ref.watch(remoteDataSourceProvider);
  return UserRepositoryImpl(
    prefs: prefs,
    remoteDataSource: remoteDataSource,
  );
});

// ── Auth Usecases ─────────────────────────────────────────────

final loginUserProvider = Provider((ref) {
  return LoginUser(repository: ref.watch(userRepositoryProvider));
});

final registerUserProvider = Provider((ref) {
  return RegisterUser(repository: ref.watch(userRepositoryProvider));
});

// ── User Usecases ─────────────────────────────────────────────

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
