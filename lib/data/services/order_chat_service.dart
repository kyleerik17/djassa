import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

class OrderConversation {
  const OrderConversation({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.clientId,
    required this.vendorId,
  });

  final String id;
  final String orderId;
  final String orderNumber;
  final String clientId;
  final String vendorId;
}

class OrderChatMessage {
  const OrderChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
}

class OrderChatService {
  OrderChatService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<OrderConversation> ensureClientVendorConversation({
    required String orderId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Connectez-vous avant de discuter.');
    }

    final cleanOrderId = orderId.trim();
    if (cleanOrderId.isEmpty) throw Exception('Commande introuvable.');

    try {
      final orderRow = await _client
          .from('orders')
          .select('id,user_id,order_number')
          .eq('id', cleanOrderId)
          .maybeSingle();
      if (orderRow == null) throw Exception('Commande introuvable.');

      final orderJson = Map<String, dynamic>.from(orderRow);
      final clientId = '${orderJson['user_id'] ?? ''}';
      final orderNumber =
          '${orderJson['order_number'] ?? 'DJ-${cleanOrderId.substring(0, 6)}'}';
      final vendorId = await _fetchVendorIdForOrder(cleanOrderId);

      if (clientId.isEmpty || vendorId.isEmpty) {
        throw Exception('Vendeur introuvable pour cette commande.');
      }
      if (user.id != clientId && user.id != vendorId) {
        throw Exception('Vous ne pouvez pas ouvrir cette discussion.');
      }

      final existing = await _client
          .from('conversations')
          .select()
          .eq('order_id', cleanOrderId)
          .eq('client_id', clientId)
          .eq('vendor_id', vendorId)
          .eq('type', 'client_vendor')
          .maybeSingle();

      if (existing != null) {
        return _conversationFromRow(
          existing,
          orderNumber: orderNumber,
        );
      }

      final row = await _client
          .from('conversations')
          .insert({
            'order_id': cleanOrderId,
            'client_id': clientId,
            'vendor_id': vendorId,
            'type': 'client_vendor',
          })
          .select()
          .single();

      return _conversationFromRow(row, orderNumber: orderNumber);
    } on PostgrestException catch (e) {
      final text = '${e.code} ${e.message}'.toLowerCase();
      if (text.contains('conversations') || text.contains('messages')) {
        throw Exception(
          'Messagerie non installee. Executez supabase/order_chat.sql.',
        );
      }
      rethrow;
    }
  }

  Stream<List<OrderChatMessage>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => _messageFromRow(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Connectez-vous avant d envoyer un message.');
    }

    final text = body.trim();
    if (text.isEmpty) return;

    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'body': text,
    });

    await _client
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()}).eq(
      'id',
      conversationId,
    );
  }

  Future<String> _fetchVendorIdForOrder(String orderId) async {
    final rows = await _client
        .from('order_items')
        .select('products(structures(owner_id))')
        .eq('order_id', orderId)
        .limit(1);
    if (rows.isEmpty) return '';

    final row = Map<String, dynamic>.from(rows.first);
    final product = row['products'] is Map
        ? Map<String, dynamic>.from(row['products'])
        : <String, dynamic>{};
    final structure = product['structures'] is Map
        ? Map<String, dynamic>.from(product['structures'])
        : <String, dynamic>{};
    return '${structure['owner_id'] ?? ''}';
  }

  OrderConversation _conversationFromRow(
    dynamic row, {
    required String orderNumber,
  }) {
    final json = Map<String, dynamic>.from(row as Map);
    return OrderConversation(
      id: '${json['id'] ?? ''}',
      orderId: '${json['order_id'] ?? ''}',
      orderNumber: orderNumber,
      clientId: '${json['client_id'] ?? ''}',
      vendorId: '${json['vendor_id'] ?? ''}',
    );
  }

  OrderChatMessage _messageFromRow(Map<String, dynamic> json) {
    return OrderChatMessage(
      id: '${json['id'] ?? ''}',
      conversationId: '${json['conversation_id'] ?? ''}',
      senderId: '${json['sender_id'] ?? ''}',
      body: '${json['body'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
    );
  }
}
