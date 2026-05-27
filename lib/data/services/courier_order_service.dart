import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

class CourierOrder {
  const CourierOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.total,
    required this.status,
    required this.createdAt,
    this.courierId,
    this.itemsCount = 1,
  });

  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final int total;
  final String status;
  final DateTime createdAt;
  final String? courierId;
  final int itemsCount;

  bool get isAssigned => courierId != null && courierId!.isNotEmpty;

  factory CourierOrder.fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}';
    final shortId = id.length > 6 ? id.substring(0, 6) : id;
    return CourierOrder(
      id: id,
      orderNumber: '${json['order_number'] ?? 'DJ-$shortId'}',
      customerName: '${json['customer_name'] ?? 'Client Djassa'}',
      customerPhone: '${json['customer_phone'] ?? ''}',
      deliveryAddress: '${json['delivery_address'] ?? ''}',
      total: int.tryParse('${json['total'] ?? 0}') ?? 0,
      status: '${json['status'] ?? 'pending_payment'}',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      courierId: json['courier_id']?.toString(),
      itemsCount: int.tryParse('${json['items_count'] ?? 1}') ?? 1,
    );
  }
}

class CourierOrderService {
  CourierOrderService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Stream<List<CourierOrder>> watchOrders() async* {
    while (true) {
      yield await fetchOrders();
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  Future<List<CourierOrder>> fetchOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from('orders')
        .select()
        .order('created_at', ascending: false);

    final refusedOrderIds = await _fetchRefusedOrderIds(user.id);

    return rows
        .map<CourierOrder>((row) => CourierOrder.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .where((order) {
      if (order.courierId == user.id) return true;
      final available = order.courierId == null || order.courierId!.isEmpty;
      if (_isClosed(order.status)) return false;
      return available && !refusedOrderIds.contains(order.id);
    }).toList();
  }

  Future<Set<String>> _fetchRefusedOrderIds(String courierId) async {
    try {
      final rows = await _client
          .from('courier_order_responses')
          .select('order_id')
          .eq('courier_id', courierId)
          .eq('response', 'refused');
      return rows.map<String>((row) => '${row['order_id']}').toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<bool> acceptOrder(String orderId) async {
    final result = await _client.rpc(
      'accept_delivery_order',
      params: {'p_order_id': orderId},
    );

    if (result is bool) return result;
    if (result is Map && result['accepted'] is bool) {
      return result['accepted'] as bool;
    }
    return result != null;
  }

  Future<void> refuseOrder(String orderId) async {
    await _client.rpc(
      'refuse_delivery_order',
      params: {'p_order_id': orderId},
    );
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _client.from('orders').update({'status': status}).eq('id', orderId);
  }

  bool _isClosed(String status) {
    return status == 'delivered' || status == 'cancelled';
  }
}
