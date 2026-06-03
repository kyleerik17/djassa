import 'package:djassa/presentation/screens/admin/pages/admin_products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/djassa_theme.dart';
import '../../../../data/services/admin_notification_service.dart';

import '../widgets/shared_widgets.dart';

class NotificationsTab extends ConsumerWidget {
  const NotificationsTab({
    super.key,
    required this.onSend,
    required this.onDelete,
  });

  final VoidCallback onSend;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(notificationsProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (notifs) {
          if (notifs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: DjassaTheme.primaryBlack,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: DjassaTheme.accentOrange,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Notifications push',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Envoyez des messages à vos clients',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Promos, livraisons, conseils — ciblés ou pour tous.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .7)),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: DjassaTheme.accentOrange,
                        ),
                        onPressed: onSend,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Envoyer une notification'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Icon(Icons.notifications_none_rounded,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Aucune notification envoyée',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: DjassaTheme.primaryBlack,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${notifs.length} notification${notifs.length > 1 ? 's' : ''}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          Text(
                            'Broadcast + ciblées',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .6),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: DjassaTheme.accentOrange),
                      onPressed: onSend,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nouvelle'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...notifs.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NotifTile(
                    notif: n,
                    onDelete: () => onDelete(n.id),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Tuile notification ────────────────────────────────────────

class NotifTile extends StatelessWidget {
  const NotifTile({super.key, required this.notif, required this.onDelete});

  final AdminNotification notif;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: notif.isBroadcast
                ? DjassaTheme.accentOrange.withValues(alpha: .12)
                : Colors.blue.shade50,
            child: Icon(
              notif.isBroadcast ? Icons.campaign_rounded : Icons.person_rounded,
              color: notif.isBroadcast
                  ? DjassaTheme.accentOrange
                  : Colors.blue.shade400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: notif.isBroadcast
                            ? DjassaTheme.accentOrange.withValues(alpha: .1)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        notif.isBroadcast ? 'Tous' : 'Ciblée',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: notif.isBroadcast
                              ? DjassaTheme.accentOrange
                              : Colors.blue.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (notif.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(notif.body,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
                if (notif.createdAt != null)
                  Text(
                    _fmt(notif.createdAt!),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Dialog création notification ──────────────────────────────

class CreateNotifDialog extends StatefulWidget {
  const CreateNotifDialog({
    super.key,
    required this.users,
    required this.onSubmit,
  });

  final List<Map<String, String>> users;
  final Future<void> Function(AdminNotificationInput) onSubmit;

  @override
  State<CreateNotifDialog> createState() => _CreateNotifDialogState();
}

class _CreateNotifDialogState extends State<CreateNotifDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String? _selectedUserId;
  String _iconName = 'notifications_active';
  bool _loading = false;

  final _icons = const [
    {'value': 'notifications_active', 'label': '🔔 Notification'},
    {'value': 'local_offer', 'label': '🏷️ Promo'},
    {'value': 'local_shipping', 'label': '🚚 Livraison'},
    {'value': 'tips_and_updates', 'label': '💡 Conseil'},
    {'value': 'warning_amber', 'label': '⚠️ Alerte'},
  ];

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.onSubmit(
        AdminNotificationInput(
          title: _titleCtrl.text,
          body: _bodyCtrl.text,
          iconName: _iconName,
          userId: _selectedUserId,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .12),
            child:
                const Icon(Icons.send_rounded, color: DjassaTheme.accentOrange),
          ),
          const SizedBox(width: 12),
          const Text('Nouvelle notification'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Titre *',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _iconName,
              decoration: InputDecoration(
                labelText: 'Icône',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: _icons
                  .map((ic) => DropdownMenuItem(
                        value: ic['value'],
                        child: Text(ic['label']!),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _iconName = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _selectedUserId,
              decoration: InputDecoration(
                labelText: 'Destinataire',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('📢 Tous les utilisateurs'),
                ),
                ...widget.users.map((u) => DropdownMenuItem<String?>(
                      value: u['id'],
                      child: Text(u['label']!, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedUserId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: DjassaTheme.accentOrange,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded),
          label: const Text('Envoyer'),
        ),
      ],
    );
  }
}