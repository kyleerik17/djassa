import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class OrderNotificationService {
  OrderNotificationService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  RealtimeChannel? _channel;
  String? _listeningUserId;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const android = AndroidInitializationSettings('@drawable/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> watchUser(String? userId) async {
    if (kIsWeb) return;
    await initialize();

    if (userId == null || userId.isEmpty) {
      await stop();
      return;
    }

    if (_listeningUserId == userId && _channel != null) return;

    await stop();
    _listeningUserId = userId;

    _channel = _client
        .channel('order-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            unawaited(_handleNotification(payload.newRecord));
          },
        )
        .subscribe();
  }

  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    _listeningUserId = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  Future<void> _handleNotification(Map<String, dynamic> record) async {
    if (!_isOrderRelated(record)) return;

    final title = '${record['title'] ?? 'Commande Djassa'}'.trim();
    final body = '${record['body'] ?? ''}'.trim();
    final id =
        (record['id'] ?? DateTime.now().millisecondsSinceEpoch).hashCode.abs();

    await _plugin.show(
      id,
      title.isEmpty ? 'Commande Djassa' : title,
      body.isEmpty ? 'Mise a jour de votre commande.' : body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'djassa_order_updates',
          'Commandes Djassa',
          channelDescription:
              'Alertes liees aux commandes, paiements et livraisons.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  bool _isOrderRelated(Map<String, dynamic> record) {
    final text = [
      record['title'],
      record['body'],
      record['icon_name'],
    ].join(' ').toLowerCase();

    return text.contains('commande') ||
        text.contains('livraison') ||
        text.contains('livreur') ||
        text.contains('paiement') ||
        text.contains('payment') ||
        text.contains('shipping') ||
        text.contains('local_shipping') ||
        text.contains('order');
  }
}
