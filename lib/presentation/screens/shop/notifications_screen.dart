import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../widgets/shop/shop_widgets.dart';
import '../../../data/services/admin_notification_service.dart';

// ── Provider ─────────────────────────────────────────────────

final userNotificationsProvider =
    FutureProvider<List<AdminNotification>>((ref) async {
  final user = SupabaseService.client.auth.currentUser;
  if (user == null) return [];

  final rows = await SupabaseService.client
      .from('notifications')
      .select()
      .order('created_at', ascending: false);

  return rows
      .map<AdminNotification>(
          (r) => AdminNotification.fromJson(Map<String, dynamic>.from(r)))
      .toList();
});

// ── Écran ─────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String name) {
    switch (name) {
      case 'local_offer':
        return Icons.local_offer_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'tips_and_updates':
        return Icons.tips_and_updates_rounded;
      case 'warning_amber':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userNotificationsProvider);

    return ShopScaffold(
      currentIndex: 0,
      title: 'Notifications',
      showBackButton: true,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (notifs) {
          if (notifs.isEmpty) {
            return Column(
              children: [
                const SizedBox(height: 60),
                Icon(Icons.notifications_none_rounded,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Aucune notification',
                    style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Retour à l\'accueil'),
                ),
              ],
            );
          }

          return Column(
            children: [
              for (final n in notifs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DjassaTheme.primaryWhite,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: DjassaTheme.borderMedium),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              DjassaTheme.accentOrange.withValues(alpha: .12),
                          child: Icon(
                            _icon(n.iconName),
                            color: DjassaTheme.accentOrange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (n.body.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(n.body),
                              ],
                              if (n.createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(n.createdAt),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Retour à l\'accueil'),
              ),
              const SizedBox(height: 88),
            ],
          );
        },
      ),
    );
  }
}
