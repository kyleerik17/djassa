import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../presentation/screens/shop/shop_data.dart';

class ShopService {
  ShopService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ─────────────────────────────────────────────────────────────────────────

  // ─── Catégories ──────────────────────────────────────────────────────────

  Future<List<ShopCategory>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    return rows.map<ShopCategory>((row) {
      final json = Map<String, dynamic>.from(row);
      return ShopCategory(
        name: json['name'] ?? '',
        icon: _iconFromName(json['icon_name']),
        subtitle: json['subtitle'] ?? '',
        // ✅ items_count n'existe pas → valeur par défaut
        itemsCount: 0,
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

    final products = rows.map<ShopProduct>((row) {
      final json = Map<String, dynamic>.from(row);
      final categoryMap = json['categories'] is Map
          ? Map<String, dynamic>.from(json['categories'])
          : <String, dynamic>{};

      return ShopProduct(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        category: categoryMap['name'] ?? '',
        price: json['price'] ?? 0,
        oldPrice: json['old_price'] ?? 0,
        rating: double.tryParse('${json['rating']}') ?? 4.5,
        stock: json['stock'] ?? 0,
        icon: _iconFromName(json['icon_name']),
        compatibility: json['compatibility'] ?? '',
        badge: json['badge'] ?? 'Top',
      );
    }).toList();

    if (category == null || category.isEmpty) return products;
    return products.where((p) => p.category == category).toList();
  }

  // ─── Commandes ────────────────────────────────────────────────────────────

  Future<List<OrderPreview>> fetchOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from('orders')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return rows.map<OrderPreview>((row) {
      final json = Map<String, dynamic>.from(row);
      return OrderPreview(
        id: json['order_number'] ??
            'DJ-${json['id'].toString().substring(0, 6)}',
        status: _statusLabel(json['status']),
        date: _formatDate(json['created_at']),
        total: json['total'] ?? 0,
        // ✅ items_count n'existe pas → valeur par défaut (ou calcule via order_items)
        items: 1,
      );
    }).toList();
  }

  Future<Map<String, dynamic>> createOrderDraft({
    required List<CartLine> lines,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Connectez-vous avant de commander.');

    final subtotal = lines.fold<int>(
      0,
      (sum, line) => sum + line.product.price * line.quantity,
    );
    const deliveryFee = 2500;
    final total = subtotal + deliveryFee;

    // ✅ Ne PAS inclure 'items_count' dans l'insert (colonne inexistante)
    final order = await _client
        .from('orders')
        .insert({
          'user_id': user.id,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'delivery_address': deliveryAddress,
          'subtotal': subtotal,
          'delivery_fee': deliveryFee,
          'total': total,
          'status': 'pending_payment',
          // ❌ 'items_count': ... ← SUPPRIMÉ (n'existe pas dans le schema)
        })
        .select()
        .single();

    final orderId = order['id'] as String;
    final items = lines
        .map((line) => {
              'order_id': orderId,
              'product_id':
                  _isUuid(line.product.id) ? line.product.id : null,
              'product_name': line.product.name,
              'quantity': line.quantity,
              'unit_price': line.product.price,
              'total': line.product.price * line.quantity,
            })
        .toList();

    if (items.isNotEmpty) {
      await _client.from('order_items').insert(items);
    }

    return Map<String, dynamic>.from(order);
  }

  /// [provider] : 'wave' | 'orange_money' | 'moov_money' | 'mtn_money'
  ///
  /// La clé GeniusPay reste côté backend. Flutter appelle seulement la
  /// Supabase Edge Function `create-payment`.
Future<Map<String, dynamic>> createPayment({
  required String orderId,
  required int amount,
  required String provider,
  required String customerPhone,
  String? customerName,
}) async {
  final user = _client.auth.currentUser;
  if (user == null) throw Exception('Connectez-vous avant de payer.');

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

  // ✅ Cast explicite pour accéder aux propriétés avec ['key']
  final data = response.data as Map<String, dynamic>;

  // ✅ Vérifier les erreurs métier dans la réponse
  if (data['error'] != null) {
    throw Exception('Erreur GeniusPay: ${data['error']}');
  }

  final checkoutUrl = data['checkout_url']?.toString();
  if (checkoutUrl == null || checkoutUrl.isEmpty) {
    throw Exception('checkout_url manquante dans la réponse GeniusPay.');
  }

  // ✅ Retourner les données avec cast sécurisé
  return {
    'checkout_url': checkoutUrl,
    'reference': data['reference']?.toString(),
    'payment_id': data['payment_id']?.toString(),
    'amount': data['amount'] as int?,
    'provider': data['provider']?.toString(),
  };
}

  // ─── Helpers ──────────────────────────────────────────────────────────────

  IconData _iconFromName(dynamic value) {
    switch ('$value') {
      case 'settings':
      case 'moteur':
        return Icons.settings;
      case 'brake':
        return Icons.motion_photos_pause;
      case 'car_repair':
        return Icons.car_repair;
      case 'electric_bolt':
      case 'battery':
        return Icons.electric_bolt;
      case 'oil':
        return Icons.opacity;
      case 'suspension':
        return Icons.vertical_align_center;
      case 'light':
        return Icons.light_mode;
      case 'tire':
        return Icons.trip_origin;
      case 'dashboard':
        return Icons.dashboard_customize;
      default:
        return Icons.directions_car;
    }
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