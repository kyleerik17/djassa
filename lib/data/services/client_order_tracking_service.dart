import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

/// Commande active affichée dans le suivi client.
class ClientActiveOrder {
  const ClientActiveOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.deliveryAddress,
    required this.total,
    required this.createdAt,
    this.courierId,
  });

  final String id;
  final String orderNumber;
  final String status;
  final String deliveryAddress;
  final int total;
  final DateTime createdAt;
  final String? courierId;

  bool get isPaid => status != 'pending_payment' && status != 'cancelled';

  factory ClientActiveOrder.fromJson(Map<String, dynamic> json) {
    return ClientActiveOrder(
      id: '${json['id']}',
      orderNumber: '${json['order_number'] ?? ''}',
      status: '${json['status'] ?? 'pending_payment'}',
      deliveryAddress: '${json['delivery_address'] ?? ''}',
      total: (json['total'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      courierId: json['courier_id']?.toString(),
    );
  }
}

class ClientOrderTrackingService {
  ClientOrderTrackingService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const _activeStatuses = [
    'paid',
    'confirmed',
    'courier_assigned',
    'shipping',
  ];

  Future<ClientActiveOrder?> fetchActive() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _client
          .from('orders')
          .select(
            'id, order_number, status, delivery_address, total, '
            'created_at, courier_id',
          )
          .eq('user_id', user.id)
          .inFilter('status', _activeStatuses)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      return ClientActiveOrder.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Stream<ClientActiveOrder?> watchActive() async* {
    final user = _client.auth.currentUser;
    if (user == null) {
      yield null;
      return;
    }

    yield await fetchActive();

    try {
      await for (final rows in _client
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('created_at', ascending: false)) {
        ClientActiveOrder? active;
        for (final raw in rows) {
          final json = Map<String, dynamic>.from(raw);
          final status = '${json['status']}';
          if (_activeStatuses.contains(status)) {
            active = ClientActiveOrder.fromJson(json);
            break;
          }
        }
        yield active;
      }
    } catch (_) {
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 6));
        yield await fetchActive();
      }
    }
  }
}
