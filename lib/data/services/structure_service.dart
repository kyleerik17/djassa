import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../domain/entities/structure.dart';

class VendorOrderItem {
  const VendorOrderItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final int total;
}

class VendorOrder {
  const VendorOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.deliveryAddress,
    required this.createdAt,
    required this.items,
    this.clientLatitude,
    this.clientLongitude,
  });

  final String id;
  final String orderNumber;
  final String status;
  final String deliveryAddress;
  final DateTime? createdAt;
  final List<VendorOrderItem> items;
  final double? clientLatitude;
  final double? clientLongitude;

  int get total => items.fold<int>(0, (sum, item) => sum + item.total);
  int get itemsCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  String get statusLabel {
    switch (status) {
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
        return status.isEmpty ? 'En attente' : status;
    }
  }
}

class StructureService {
  StructureService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<Structure> fetchMine() async {
    final user = _client.auth.currentUser;
    if (user == null) return Structure.empty;

    try {
      final row = await _client
          .from('structures')
          .select()
          .eq('owner_id', user.id)
          .maybeSingle();

      if (row == null) return Structure.empty;
      return Structure.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (_isMissingStructuresTable(e)) return Structure.empty;
      rethrow;
    }
  }

  Future<Structure> save(Structure structure) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Connectez-vous avant de modifier votre boutique.');
    }

    final payload = structure.copyWith(ownerId: user.id).toJson()..remove('id');

    try {
      if (structure.id.isEmpty) {
        final slug = structure.slug.isNotEmpty
            ? structure.slug
            : _defaultSlug(structure.name, user.id);
        payload['slug'] = slug;
        payload['owner_id'] = user.id;

        final row =
            await _client.from('structures').insert(payload).select().single();
        return Structure.fromJson(Map<String, dynamic>.from(row));
      }

      final row = await _client
          .from('structures')
          .update(payload)
          .eq('id', structure.id)
          .eq('owner_id', user.id)
          .select()
          .single();
      return Structure.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (_isMissingStructuresTable(e)) {
        throw Exception(
          'Table structures manquante. Exécutez supabase/vendor_structures.sql.',
        );
      }
      rethrow;
    }
  }

  Future<List<VendorOrder>> fetchVendorOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await _client.rpc('get_vendor_orders');
      final rows = response is List ? response : const [];
      final grouped = <String, _VendorOrderBuilder>{};

      for (final row in rows) {
        final json = Map<String, dynamic>.from(row as Map);
        final id = '${json['order_id'] ?? ''}';
        if (id.isEmpty) continue;

        final builder = grouped.putIfAbsent(
          id,
          () => _VendorOrderBuilder(
            id: id,
            orderNumber:
                '${json['order_number'] ?? 'DJ-${id.substring(0, 6)}'}',
            status: '${json['status'] ?? ''}',
            deliveryAddress: '${json['delivery_address'] ?? ''}',
            createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
            clientLatitude: double.tryParse('${json['client_latitude']}'),
            clientLongitude: double.tryParse('${json['client_longitude']}'),
          ),
        );

        builder.items.add(
          VendorOrderItem(
            name: '${json['item_name'] ?? 'Article'}',
            quantity: (json['quantity'] as num?)?.toInt() ?? 0,
            unitPrice: (json['unit_price'] as num?)?.toInt() ?? 0,
            total: (json['item_total'] as num?)?.toInt() ?? 0,
          ),
        );
      }

      final orders = grouped.values.map((builder) => builder.build()).toList()
        ..sort((a, b) {
          final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
      return orders;
    } on PostgrestException catch (e) {
      final message = '${e.code} ${e.message}'.toLowerCase();
      if (message.contains('get_vendor_orders') ||
          message.contains('function') ||
          message.contains('pgrst202')) {
        throw Exception(
          'Fonction get_vendor_orders manquante. Exécutez supabase/vendor_structures.sql.',
        );
      }
      rethrow;
    }
  }

  /// Crée une boutique par défaut à l'inscription vendeur.
  Future<Structure> createDefaultForOwner({
    required String ownerId,
    required String displayName,
    required String phone,
    String? email,
  }) async {
    final slug = _defaultSlug(displayName, ownerId);
    final row = await _client
        .from('structures')
        .insert({
          'owner_id': ownerId,
          'name':
              displayName.trim().isEmpty ? 'Ma boutique' : displayName.trim(),
          'slug': slug,
          'phone': phone,
          'email': email,
        })
        .select()
        .single();

    return Structure.fromJson(Map<String, dynamic>.from(row));
  }

  String _defaultSlug(String name, String ownerId) {
    final base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final suffix = ownerId.replaceAll('-', '').substring(0, 8);
    return '${base.isEmpty ? 'boutique' : base}-$suffix';
  }

  bool _isMissingStructuresTable(PostgrestException e) {
    final text = '${e.code} ${e.message}'.toLowerCase();
    return text.contains('structures') &&
        (text.contains('does not exist') || text.contains('42p01'));
  }
}

class _VendorOrderBuilder {
  _VendorOrderBuilder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.deliveryAddress,
    required this.createdAt,
    required this.clientLatitude,
    required this.clientLongitude,
  });

  final String id;
  final String orderNumber;
  final String status;
  final String deliveryAddress;
  final DateTime? createdAt;
  final double? clientLatitude;
  final double? clientLongitude;
  final List<VendorOrderItem> items = [];

  VendorOrder build() {
    return VendorOrder(
      id: id,
      orderNumber: orderNumber,
      status: status,
      deliveryAddress: deliveryAddress,
      createdAt: createdAt,
      items: List.unmodifiable(items),
      clientLatitude: clientLatitude,
      clientLongitude: clientLongitude,
    );
  }
}
