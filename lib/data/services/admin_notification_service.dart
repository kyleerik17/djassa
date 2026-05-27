// lib/data/services/admin_notification_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.iconName,
    required this.userId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String iconName;
  final String? userId;   // null = broadcast
  final bool isRead;
  final DateTime? createdAt;

  bool get isBroadcast => userId == null;

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    return AdminNotification(
      id:        '${json['id'] ?? ''}',
      title:     '${json['title'] ?? ''}',
      body:      '${json['body'] ?? ''}',
      iconName:  '${json['icon_name'] ?? 'notifications_active'}',
      userId:    json['user_id'] == null ? null : '${json['user_id']}',
      isRead:    json['is_read'] == true,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}

class AdminNotificationInput {
  const AdminNotificationInput({
    required this.title,
    required this.body,
    required this.iconName,
    this.userId,  // null = broadcast
  });

  final String title;
  final String body;
  final String iconName;
  final String? userId;

  Map<String, dynamic> toJson() => {
        'title':     title.trim(),
        'body':      body.trim(),
        'icon_name': iconName,
        if (userId != null && userId!.isNotEmpty) 'user_id': userId,
      };
}

class AdminNotificationService {
  AdminNotificationService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<AdminNotification>> fetchAll() async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false);

    return rows
        .map<AdminNotification>(
          (r) => AdminNotification.fromJson(Map<String, dynamic>.from(r)),
        )
        .toList();
  }

  Future<AdminNotification> create(AdminNotificationInput input) async {
    final row = await _client
        .from('notifications')
        .insert(input.toJson())
        .select()
        .single();

    return AdminNotification.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> delete(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }

  /// Récupère les users (id + email) pour le dropdown de ciblage
  Future<List<Map<String, String>>> fetchUsers() async {
    final rows = await _client
        .from('profiles')
        .select('id, name, surname, phone')
        .order('name');

    return rows.map<Map<String, String>>((r) {
      return {
        'id':    '${r['id'] ?? ''}',
        'label': '${r['name'] ?? ''} ${r['surname'] ?? ''} · ${r['phone'] ?? ''}',
      };
    }).toList();
  }
}