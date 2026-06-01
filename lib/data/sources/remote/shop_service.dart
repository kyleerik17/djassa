import 'package:djassa/core/utils/icon_mapper.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../presentation/screens/shop/shop_data.dart';

class VendorProductInput {
  const VendorProductInput({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.compatibility,
    required this.price,
    required this.oldPrice,
    required this.stock,
    required this.badge,
    required this.iconName,
    required this.isActive,
  });

  final String categoryId;
  final String name;
  final String description;
  final String compatibility;
  final int price;
  final int oldPrice;
  final int stock;
  final String badge;
  final String iconName;
  final bool isActive;

  Map<String, dynamic> toJson({required String slug}) {
    return {
      'category_id': categoryId,
      'name': name.trim(),
      'slug': slug,
      'description': description.trim(),
      'compatibility': compatibility.trim(),
      'price': price,
      'old_price': oldPrice,
      'stock': stock,
      'rating': 4.5,
      'badge': badge.trim().isEmpty ? 'Top' : badge.trim(),
      'icon_name': iconName.trim().isEmpty ? 'storefront_rounded' : iconName,
      'is_active': isActive,
    };
  }
}

class ShopService {
  ShopService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ─── Catégories ──────────────────────────────────────────────────────────

  Future<List<ShopCategory>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    final productRows = await _client
        .from('products')
        .select('category_id')
        .eq('is_active', true);

    final itemCounts = <String, int>{};
    for (final row in productRows) {
      final categoryId = '${row['category_id'] ?? ''}';
      if (categoryId.isEmpty) continue;
      itemCounts[categoryId] = (itemCounts[categoryId] ?? 0) + 1;
    }

    return rows.map<ShopCategory>((row) {
      final json = Map<String, dynamic>.from(row);
      final id = '${json['id'] ?? ''}';
      return ShopCategory(
        id: id,
        name: json['name'] ?? '',
        icon: _iconFromName(json['icon_name']),
        iconName: '${json['icon_name'] ?? 'category'}',
        subtitle: json['subtitle'] ?? '',
        itemsCount:
            itemCounts[id] ?? (json['items_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  // ─── Produits ─────────────────────────────────────────────────────────────

  Future<List<ShopProduct>> fetchProducts({
    String? query,
    String? category,
  }) async {
    dynamic request = _client
        .from('products')
        .select('*, categories(name)')
        .eq('is_active', true);

    if (query != null && query.trim().isNotEmpty) {
      final value = '%${query.trim()}%';
      request = request.or(
        'name.ilike.$value,description.ilike.$value,compatibility.ilike.$value',
      );
    }

    final rows = await request.order('created_at', ascending: false);
    final products = rows.map<ShopProduct>(_productFromRow).toList();

    if (category == null || category.isEmpty) return products;
    return products.where((p) => p.category == category).toList();
  }

  Future<List<ShopProduct>> fetchVendorProducts({
    required String structureId,
  }) async {
    final id = structureId.trim();
    if (id.isEmpty) return const [];

    try {
      final rows = await _client
          .from('products')
          .select('*, categories(id,name)')
          .eq('structure_id', id)
          .order('created_at', ascending: false);

      return rows.map<ShopProduct>(_productFromRow).toList();
    } on PostgrestException catch (e) {
      if (_isMissingStructureIdColumn(e)) {
        throw Exception(
          'Colonne structure_id manquante. Executez supabase/vendor_structures.sql.',
        );
      }
      rethrow;
    }
  }

  Future<ShopProduct> createVendorProduct({
    required String structureId,
    required VendorProductInput input,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Connectez-vous avant de creer un article.');
    }

    final id = structureId.trim();
    if (id.isEmpty) {
      throw Exception('Enregistrez votre boutique avant de creer un article.');
    }

    final slug = await _uniqueProductSlug(input.name, structureId: id);
    final payload = input.toJson(slug: slug)..['structure_id'] = id;

    try {
      final row = await _client
          .from('products')
          .insert(payload)
          .select('*, categories(id,name)')
          .single();
      return _productFromRow(row);
    } on PostgrestException catch (e) {
      if (_isMissingStructureIdColumn(e)) {
        throw Exception(
          'Colonne structure_id manquante. Executez supabase/vendor_structures.sql.',
        );
      }
      if (_isPermissionError(e)) {
        throw Exception(
          'Droits vendeur manquants sur les articles. Executez supabase/vendor_structures.sql.',
        );
      }
      rethrow;
    }
  }

  // ─── Commandes ────────────────────────────────────────────────────────────

  Future<ShopProduct> updateVendorProduct({
    required String structureId,
    required String productId,
    required VendorProductInput input,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Connectez-vous avant de modifier un article.');
    }

    final cleanStructureId = structureId.trim();
    final cleanProductId = productId.trim();
    if (cleanStructureId.isEmpty || cleanProductId.isEmpty) {
      throw Exception('Article introuvable.');
    }

    try {
      final row = await _client
          .from('products')
          .update(input.toJson(slug: _slugify(input.name)))
          .eq('id', cleanProductId)
          .eq('structure_id', cleanStructureId)
          .select('*, categories(id,name)')
          .single();
      return _productFromRow(row);
    } on PostgrestException catch (e) {
      if (_isMissingStructureIdColumn(e)) {
        throw Exception(
          'Colonne structure_id manquante. Executez supabase/vendor_structures.sql.',
        );
      }
      if (_isPermissionError(e)) {
        throw Exception(
          'Droits vendeur manquants sur les articles. Executez supabase/vendor_structures.sql.',
        );
      }
      rethrow;
    }
  }

  Future<void> deleteVendorProduct({
    required String structureId,
    required String productId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Connectez-vous avant de supprimer un article.');
    }

    final cleanStructureId = structureId.trim();
    final cleanProductId = productId.trim();
    if (cleanStructureId.isEmpty || cleanProductId.isEmpty) {
      throw Exception('Article introuvable.');
    }

    try {
      await _client
          .from('products')
          .delete()
          .eq('id', cleanProductId)
          .eq('structure_id', cleanStructureId);
    } on PostgrestException catch (e) {
      if (_isMissingStructureIdColumn(e)) {
        throw Exception(
          'Colonne structure_id manquante. Executez supabase/vendor_structures.sql.',
        );
      }
      if (_isPermissionError(e)) {
        throw Exception(
          'Droits vendeur manquants sur les articles. Executez supabase/vendor_structures.sql.',
        );
      }
      rethrow;
    }
  }

  Future<List<OrderPreview>> fetchOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await _client
          .from('orders')
          .select()
          .eq('user_id', user.id)
          .neq('status', 'pending_payment')
          .order('created_at', ascending: false);

      return rows.map<OrderPreview>((row) {
        final json = Map<String, dynamic>.from(row);
        final statusKey = '${json['status'] ?? ''}';
        return OrderPreview(
          id: json['order_number'] ??
              'DJ-${json['id'].toString().substring(0, 6)}',
          orderUuid: '${json['id']}',
          statusKey: statusKey,
          status: _statusLabel(statusKey),
          date: _formatDate(json['created_at']),
          total: (json['total'] as num?)?.toInt() ?? 0,
          items: 1,
        );
      }).toList();
    } on PostgrestException catch (e) {
      debugPrint(
        '[ShopService.fetchOrders] code=${e.code} message=${e.message} details=${e.details}',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOrderDraft({
    required List<CartLine> lines,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Connectez-vous avant de commander.');

    if (lines.isEmpty) throw Exception('Votre panier est vide.');

    // Nettoyage du numéro : retire espaces, tirets, parenthèses
    final cleanPhone =
        customerPhone.replaceAll(RegExp(r'[\s\-().]+'), '').trim();

    // Validation du format téléphone (requis par la contrainte CHECK)
    final phoneValid = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleanPhone);
    if (!phoneValid) {
      throw Exception(
        'Numéro de téléphone invalide : $cleanPhone. '
        'Format attendu : chiffres uniquement, 7 à 15 caractères.',
      );
    }

    final subtotal = lines.fold<int>(
      0,
      (sum, line) => sum + line.product.price * line.quantity,
    );
    const deliveryFee = 2500;
    final total = subtotal + deliveryFee;

    late Map<String, dynamic> order;

    try {
      order = await _client
          .from('orders')
          .insert({
            'user_id': user.id,
            'customer_name': customerName.trim().isEmpty
                ? 'Client Djassa'
                : customerName.trim(),
            'customer_phone': cleanPhone,
            'delivery_address': deliveryAddress.trim(),
            'subtotal': subtotal,
            'delivery_fee': deliveryFee,
            'total': total,
            'status': 'pending_payment',
          })
          .select()
          .single();
    } on PostgrestException catch (e) {
      debugPrint(
        '[ShopService.createOrderDraft] INSERT orders '
        'code=${e.code} message=${e.message} details=${e.details}',
      );

      // Messages lisibles selon le code d'erreur Postgres
      if (e.code == '23514') {
        // Violation CHECK
        throw Exception(
          'Données invalides pour la commande. '
          'Vérifiez votre numéro de téléphone.',
        );
      }
      if (e.code == '23502') {
        // NOT NULL violation - plus précis pour le debugging
        final details = e.details?.toString() ?? '';
        if (details.contains('changed_by_role')) {
          // Cette erreur ne devrait plus arriver si le trigger est corrigé
          debugPrint(
            '[ShopService] Trigger order_status_history : '
            'changed_by_role est NULL. Vérifiez le trigger.',
          );
        }
        throw Exception(
          'Un champ obligatoire est manquant dans la commande. '
          'Contactez le support si le problème persiste.',
        );
      }
      if (_isPermissionError(e)) {
        throw Exception(
          'Vous n\'avez pas les droits pour passer une commande.',
        );
      }
      throw Exception(
        'Impossible de créer la commande. Veuillez réessayer.',
      );
    }

    final orderId = order['id'] as String;

    final items = lines
        .map((line) => {
              'order_id': orderId,
              'product_id': _isUuid(line.product.id) ? line.product.id : null,
              'product_name': line.product.name,
              'quantity': line.quantity,
              'unit_price': line.product.price,
              'total': line.product.price * line.quantity,
            })
        .toList();

    if (items.isNotEmpty) {
      try {
        await _client.from('order_items').insert(items);
      } on PostgrestException catch (e) {
        debugPrint(
          '[ShopService.createOrderDraft] INSERT order_items '
          'code=${e.code} message=${e.message} details=${e.details}',
        );
        // Annuler la commande si les articles ne s'insèrent pas
        await _client.from('orders').delete().eq('id', orderId);
        throw Exception(
          'Erreur lors de l\'ajout des articles. Commande annulée.',
        );
      }
    }

    return Map<String, dynamic>.from(order);
  }

  /// [provider] : 'wave' | 'orange_money' | 'moov_money' | 'mtn_money'
  Future<Map<String, dynamic>> createPayment({
    required String orderId,
    required int amount,
    required String provider,
    required String customerPhone,
    String? customerName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Connectez-vous avant de payer.');

    try {
      final response = await _client.functions.invoke(
        'create-geniuspay-payment',
        body: {
          'order_id': orderId,
          'amount': amount,
          'provider': provider,
          'customer_phone': customerPhone,
          if (customerName != null && customerName.isNotEmpty)
            'customer_name': customerName,
        },
      );

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null || data['success'] == false) {
        final message = data['message']?.toString() ??
            data['error']?.toString() ??
            'creation du paiement impossible';
        throw Exception('Erreur GeniusPay : $message');
      }

      final checkoutUrl =
          (data['checkout_url'] ?? data['payment_url'])?.toString();
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('URL de paiement introuvable.');
      }

      return {
        'checkout_url': checkoutUrl,
        'reference': data['reference']?.toString(),
        'payment_id': data['payment_id']?.toString(),
        'amount': (data['amount'] as num?)?.toInt() ?? amount,
        'provider': data['provider']?.toString() ?? provider,
      };
    } on FunctionException catch (e) {
      debugPrint(
        '[ShopService.createPayment] FunctionException: ${e.details}',
      );
      throw Exception(
        'Échec du paiement. Veuillez réessayer ou choisir '
        'un autre moyen de paiement.',
      );
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  ShopProduct _productFromRow(dynamic row) {
    final json = Map<String, dynamic>.from(row as Map);
    final categoryMap = json['categories'] is Map
        ? Map<String, dynamic>.from(json['categories'])
        : <String, dynamic>{};

    return ShopProduct(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      categoryId: '${json['category_id'] ?? ''}',
      category: '${categoryMap['name'] ?? 'Sans categorie'}',
      description: '${json['description'] ?? ''}',
      price: _asInt(json['price']),
      oldPrice: _asInt(json['old_price']),
      rating: _asDouble(json['rating'], fallback: 4.5),
      stock: _asInt(json['stock']),
      icon: _iconFromName(json['icon_name']),
      compatibility: '${json['compatibility'] ?? ''}',
      badge: '${json['badge'] ?? 'Top'}',
      imageUrl: json['image_url'] == null || '${json['image_url']}'.isEmpty
          ? null
          : '${json['image_url']}',
      isActive: json['is_active'] != false,
    );
  }

  IconData _iconFromName(dynamic value) {
    return IconMapper.fromString(value?.toString());
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  double _asDouble(dynamic value, {required double fallback}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  Future<String> _uniqueProductSlug(
    String name, {
    required String structureId,
  }) async {
    final base = _slugify(name);
    final cleanStructureId = structureId.replaceAll('-', '');
    final suffix = cleanStructureId.length <= 8
        ? cleanStructureId
        : cleanStructureId.substring(0, 8);
    final safeBase = '${base.isEmpty ? 'article' : base}-$suffix';
    var candidate = safeBase;
    var index = 2;

    while (true) {
      final existing = await _client
          .from('products')
          .select('id')
          .eq('slug', candidate)
          .maybeSingle();
      if (existing == null) return candidate;
      candidate = '$safeBase-$index';
      index++;
    }
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  bool _isMissingStructureIdColumn(PostgrestException e) {
    final text = '${e.code} ${e.message}'.toLowerCase();
    return text.contains('structure_id') &&
        (text.contains('does not exist') || text.contains('42703'));
  }

  bool _isPermissionError(PostgrestException e) {
    final text = '${e.code} ${e.message}'.toLowerCase();
    return text.contains('row-level security') ||
        text.contains('permission denied') ||
        text.contains('42501');
  }

  String _statusLabel(dynamic status) {
    switch ('$status') {
      case 'pending_payment':
        return 'Paiement attendu';
      case 'paid':
        return 'Payée';
      case 'confirmed':
        return 'Confirmée';
      case 'courier_assigned':
        return 'Livreur assigné';
      case 'shipping':
        return 'En route';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      case 'refunded':
        return 'Remboursée';
      default:
        return '$status';
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse('$value');
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}'
      r'-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
