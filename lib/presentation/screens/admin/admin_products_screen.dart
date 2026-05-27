import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../data/services/admin_notification_service.dart';
import '../../../data/sources/remote/admin_service.dart';
import '../../providers/core_providers.dart';
import '../shop/shop_data.dart';

// ── Providers locaux notifications ────────────────────────────

final _notifServiceProvider = Provider((_) => AdminNotificationService());

final _notificationsProvider =
    FutureProvider.autoDispose<List<AdminNotification>>((ref) async {
  return ref.read(_notifServiceProvider).fetchAll();
});

final _notifUsersProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  return ref.read(_notifServiceProvider).fetchUsers();
});

// ── Écran principal ───────────────────────────────────────────

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return isAdmin.when(
      loading: () => const _AdminLoadingScaffold(),
      error: (error, _) => _AdminAccessDenied(message: '$error'),
      data: (allowed) {
        if (!allowed) {
          return const _AdminAccessDenied(
            message:
                'Connectez-vous avec un compte administrateur pour gérer les articles.',
          );
        }
        return _AdminTabView(
          tabController: _tabController,
          searchController: _searchController,
          query: _query,
          onCreate: _openCreateSheet,
          onEdit: _openEditSheet,
          onToggleActive: _toggleActive,
          onDelete: _deleteProduct,
          onSendNotif: _openNotifDialog,
          onDeleteNotif: _deleteNotif,
        );
      },
    );
  }

  // ── Notifications ─────────────────────────────────────────

  Future<void> _openNotifDialog() async {
    final users = await ref.read(_notifUsersProvider.future);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _CreateNotifDialog(
        users: users,
        onSubmit: (input) async {
          await ref.read(_notifServiceProvider).create(input);
          ref.invalidate(_notificationsProvider);
        },
      ),
    );
  }

  Future<void> _deleteNotif(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content:
            const Text('Cette notification sera supprimée définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(_notifServiceProvider).delete(id);
      ref.invalidate(_notificationsProvider);
    }
  }

  // ── Produits ──────────────────────────────────────────────

  Future<void> _openCreateSheet() async {
    final categories = await _loadCategories();
    if (!mounted || categories == null) return;

    final input = await showModalBottomSheet<AdminProductInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminProductFormSheet(categories: categories),
    );

    if (input == null) return;
    await _runMutation(
      successMessage: 'Article ajouté au catalogue.',
      action: () => ref.read(adminServiceProvider).createProduct(input),
    );
  }

  Future<void> _openEditSheet(AdminProduct product) async {
    final categories = await _loadCategories();
    if (!mounted || categories == null) return;

    final input = await showModalBottomSheet<AdminProductInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AdminProductFormSheet(product: product, categories: categories),
    );

    if (input == null) return;
    await _runMutation(
      successMessage: 'Article mis à jour.',
      action: () => ref
          .read(adminServiceProvider)
          .updateProduct(id: product.id, input: input),
    );
  }

  Future<List<AdminCategory>?> _loadCategories() async {
    try {
      final categories = await ref.read(adminCategoriesProvider.future);
      if (categories.isEmpty && mounted) {
        _showSnack(
          'Créez au moins un rayon dans Supabase avant d\'ajouter un article.',
          isError: true,
        );
        return null;
      }
      return categories.where((c) => c.isActive).toList();
    } catch (error) {
      if (mounted) {
        _showSnack('Impossible de charger les rayons: $error', isError: true);
      }
      return null;
    }
  }

  Future<void> _toggleActive(AdminProduct product) async {
    await _runMutation(
      successMessage:
          product.isActive ? 'Article archivé.' : 'Article remis en ligne.',
      action: () => ref.read(adminServiceProvider).setProductActive(
            id: product.id,
            isActive: !product.isActive,
          ),
    );
  }

  Future<void> _deleteProduct(AdminProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: Text(
          '"${product.name}" sera supprimé du catalogue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runMutation(
      successMessage: 'Article supprimé.',
      action: () => ref.read(adminServiceProvider).deleteProduct(product.id),
    );
  }

  Future<void> _runMutation({
    required String successMessage,
    required Future<dynamic> Function() action,
  }) async {
    try {
      await action();
      ref.invalidate(adminProductsProvider);
      ref.invalidate(productsProvider);
      if (mounted) _showSnack(successMessage);
    } catch (error) {
      if (!mounted) return;
      _showSnack('Action impossible: $error', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade700 : DjassaTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Vue avec onglets ──────────────────────────────────────────

class _AdminTabView extends ConsumerWidget {
  const _AdminTabView({
    required this.tabController,
    required this.searchController,
    required this.query,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onSendNotif,
    required this.onDeleteNotif,
  });

  final TabController tabController;
  final TextEditingController searchController;
  final String query;
  final VoidCallback onCreate;
  final ValueChanged<AdminProduct> onEdit;
  final ValueChanged<AdminProduct> onToggleActive;
  final ValueChanged<AdminProduct> onDelete;
  final VoidCallback onSendNotif;
  final ValueChanged<String> onDeleteNotif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(_notificationsProvider);
    final notifCount = notifsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar custom ─────────────────────────────
            Container(
              color: DjassaTheme.backgroundSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => context.go('/profile'),
                  ),
                  const Expanded(
                    child: Text(
                      'Backoffice',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualiser',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      ref.invalidate(adminProductsProvider);
                      ref.invalidate(_notificationsProvider);
                    },
                  ),
                ],
              ),
            ),

            // ── TabBar ────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                color: DjassaTheme.primaryWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DjassaTheme.borderMedium),
              ),
              child: TabBar(
                controller: tabController,
                indicator: BoxDecoration(
                  color: DjassaTheme.primaryBlack,
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: DjassaTheme.primaryWhite,
                unselectedLabelColor: DjassaTheme.primaryBlack,
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Catalogue',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_rounded, size: 16),
                        const SizedBox(width: 6),
                        const Text('Notifs',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        if (notifCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: DjassaTheme.accentOrange,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$notifCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Contenu ───────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  // Onglet Catalogue
                  _CatalogueTab(
                    searchController: searchController,
                    query: query,
                    onCreate: onCreate,
                    onEdit: onEdit,
                    onToggleActive: onToggleActive,
                    onDelete: onDelete,
                  ),

                  // Onglet Notifications
                  _NotificationsTab(
                    onSend: onSendNotif,
                    onDelete: onDeleteNotif,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // FAB contextuel selon l'onglet actif
      floatingActionButton: ListenableBuilder(
        listenable: tabController,
        builder: (_, __) {
          final isNotifTab = tabController.index == 1;
          return FloatingActionButton.extended(
            backgroundColor: DjassaTheme.accentOrange,
            onPressed: isNotifTab ? onSendNotif : onCreate,
            icon: Icon(isNotifTab ? Icons.send_rounded : Icons.add_rounded),
            label: Text(isNotifTab ? 'Envoyer' : 'Ajouter'),
          );
        },
      ),
    );
  }
}

// ── Onglet Catalogue ──────────────────────────────────────────

class _CatalogueTab extends ConsumerWidget {
  const _CatalogueTab({
    required this.searchController,
    required this.query,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final TextEditingController searchController;
  final String query;
  final VoidCallback onCreate;
  final ValueChanged<AdminProduct> onEdit;
  final ValueChanged<AdminProduct> onToggleActive;
  final ValueChanged<AdminProduct> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(adminProductsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminProductsProvider);
        await ref.read(adminProductsProvider.future);
      },
      child: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorCard(
          title: 'Backoffice indisponible',
          message: '$error',
        ),
        data: (products) {
          final filtered = query.isEmpty
              ? products
              : products.where((p) {
                  return p.name.toLowerCase().contains(query) ||
                      p.categoryName.toLowerCase().contains(query) ||
                      p.compatibility.toLowerCase().contains(query) ||
                      p.badge.toLowerCase().contains(query);
                }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              const SizedBox(height: 8),
              _HeroHeader(onCreate: onCreate),
              const SizedBox(height: 16),
              _StatsGrid(products: products),
              const SizedBox(height: 16),
              _SearchBar(controller: searchController),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${filtered.length} article${filtered.length > 1 ? 's' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    'Gestion catalogue',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                _EmptyAdminList(onCreate: onCreate)
              else
                ...filtered.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AdminProductCard(
                      product: product,
                      onEdit: () => onEdit(product),
                      onToggleActive: () => onToggleActive(product),
                      onDelete: () => onDelete(product),
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

// ── Onglet Notifications ──────────────────────────────────────

class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab({
    required this.onSend,
    required this.onDelete,
  });

  final VoidCallback onSend;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_notificationsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_notificationsProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (notifs) {
          if (notifs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Hero notifs
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
              // Hero
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
                  child: _NotifTile(
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

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif, required this.onDelete});

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

class _CreateNotifDialog extends StatefulWidget {
  const _CreateNotifDialog({
    required this.users,
    required this.onSubmit,
  });

  final List<Map<String, String>> users;
  final Future<void> Function(AdminNotificationInput) onSubmit;

  @override
  State<_CreateNotifDialog> createState() => _CreateNotifDialogState();
}

class _CreateNotifDialogState extends State<_CreateNotifDialog> {
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

// ── Widgets partagés ──────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(30),
        boxShadow: DjassaTheme.shadowHeavy,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -32,
            child: Icon(Icons.inventory_2_rounded,
                size: 142,
                color: DjassaTheme.primaryWhite.withValues(alpha: .07)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: DjassaTheme.accentOrange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Admin catalogue',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              const SizedBox(height: 18),
              Text(
                'Ajoutez vos articles sans ouvrir Supabase',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: DjassaTheme.primaryWhite, height: 1.06),
              ),
              const SizedBox(height: 8),
              Text(
                'Prix, stock, rayon, badge promo et publication se gèrent ici.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .72)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DjassaTheme.accentOrange,
                  foregroundColor: DjassaTheme.primaryWhite,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nouvel article'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: .04, end: 0);
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.products});
  final List<AdminProduct> products;

  @override
  Widget build(BuildContext context) {
    final active = products.where((p) => p.isActive).length;
    final lowStock = products.where((p) => p.isActive && p.stock <= 5).length;
    final stockValue =
        products.fold<int>(0, (sum, p) => sum + (p.price * p.stock));

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 680;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isWide ? 4 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isWide ? 1.75 : 1.45,
        children: [
          _StatCard(
              label: 'Articles',
              value: '${products.length}',
              icon: Icons.inventory_2_outlined),
          _StatCard(
              label: 'En ligne',
              value: '$active',
              icon: Icons.visibility_rounded),
          _StatCard(
              label: 'Stock faible',
              value: '$lowStock',
              icon: Icons.warning_amber_rounded,
              color: Colors.red),
          _StatCard(
              label: 'Valeur stock',
              value: formatPrice(stockValue),
              icon: Icons.payments_outlined),
        ],
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = DjassaTheme.accentOrange,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DjassaTheme.borderMedium),
        boxShadow: DjassaTheme.shadowLight,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color)),
        const Spacer(),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Rechercher un article, rayon, compatibilité...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: controller.clear),
        filled: true,
        fillColor: DjassaTheme.primaryWhite,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: DjassaTheme.borderMedium)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: DjassaTheme.borderMedium)),
      ),
    );
  }
}

class _AdminProductCard extends StatelessWidget {
  const _AdminProductCard({
    required this.product,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });
  final AdminProduct product;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: product.isActive
                ? DjassaTheme.borderMedium
                : Colors.red.withValues(alpha: .25)),
        boxShadow: DjassaTheme.shadowLight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: DjassaTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(20)),
            child: Icon(_iconFromName(product.iconName),
                color: DjassaTheme.primaryBlack, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _Chip(
                      label: product.categoryName,
                      color: DjassaTheme.primaryBlack),
                  _Chip(
                      label: product.isActive ? 'En ligne' : 'Archivé',
                      color: product.isActive
                          ? DjassaTheme.accentGreen
                          : Colors.red),
                  if (product.badge.trim().isNotEmpty)
                    _Chip(
                        label: product.badge, color: DjassaTheme.accentOrange),
                ]),
                const SizedBox(height: 8),
                Text(product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                    product.compatibility.isEmpty
                        ? 'Compatibilité non renseignée'
                        : product.compatibility,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 9),
                Wrap(spacing: 12, runSpacing: 6, children: [
                  Text(formatPrice(product.price),
                      style: const TextStyle(
                          color: DjassaTheme.accentOrange,
                          fontWeight: FontWeight.w900)),
                  Text('${product.stock} en stock'),
                  Text('★ ${product.rating.toStringAsFixed(1)}'),
                ]),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;
                case 'toggle':
                  onToggleActive();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(
                  value: 'toggle',
                  child:
                      Text(product.isActive ? 'Archiver' : 'Mettre en ligne')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 240.ms).slideX(begin: .03, end: 0);
  }

  IconData _iconFromName(String value) {
    switch (value) {
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
      default:
        return Icons.directions_car;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyAdminList extends StatelessWidget {
  const _EmptyAdminList({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: DjassaTheme.borderMedium)),
      child: Column(children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFFFF0E3),
          child: Icon(Icons.inventory_2_outlined,
              color: DjassaTheme.accentOrange, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Aucun article', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('Ajoutez votre premier article au catalogue.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer un article')),
      ]),
    );
  }
}

class _AdminLoadingScaffold extends StatelessWidget {
  const _AdminLoadingScaffold();
  @override
  Widget build(BuildContext context) => const Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      body: Center(child: CircularProgressIndicator()));
}

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      appBar: AppBar(
          title: const Text('Backoffice'),
          backgroundColor: DjassaTheme.backgroundSecondary),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: _ErrorCard(
              title: 'Accès administrateur requis',
              message: message,
              actionLabel: 'Retour profil',
              onAction: () => context.go('/profile')),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: DjassaTheme.primaryWhite,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: DjassaTheme.borderMedium)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.admin_panel_settings_outlined,
              size: 58, color: DjassaTheme.accentOrange),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}

// Widgets de formulaire produit (inchangés)
class AdminProductFormSheet extends StatefulWidget {
  const AdminProductFormSheet({
    super.key,
    required this.categories,
    this.product,
  });
  final List<AdminCategory> categories;
  final AdminProduct? product;

  @override
  State<AdminProductFormSheet> createState() => _AdminProductFormSheetState();
}

class _AdminProductFormSheetState extends State<AdminProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _compatibilityController;
  late final TextEditingController _priceController;
  late final TextEditingController _oldPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _ratingController;
  late final TextEditingController _badgeController;
  late final TextEditingController _imageUrlController;
  String? _categoryId;
  String _iconName = 'car';
  bool _isActive = true;

  static const _icons = [
    'car',
    'settings',
    'brake',
    'car_repair',
    'electric_bolt',
    'battery',
    'oil',
    'suspension',
    'light',
    'tire'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _compatibilityController =
        TextEditingController(text: p?.compatibility ?? '');
    _priceController =
        TextEditingController(text: p == null ? '' : '${p.price}');
    _oldPriceController = TextEditingController(
        text: p == null || p.oldPrice == 0 ? '' : '${p.oldPrice}');
    _stockController =
        TextEditingController(text: p == null ? '' : '${p.stock}');
    _ratingController = TextEditingController(
        text: p == null ? '4.5' : p.rating.toStringAsFixed(1));
    _badgeController = TextEditingController(text: p?.badge ?? 'Top');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');
    _categoryId = p?.categoryId;
    _iconName = _icons.contains(p?.iconName) ? p!.iconName : 'car';
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _compatibilityController.dispose();
    _priceController.dispose();
    _oldPriceController.dispose();
    _stockController.dispose();
    _ratingController.dispose();
    _badgeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.product != null;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .92,
        minChildSize: .72,
        maxChildSize: .96,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: DjassaTheme.backgroundSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Center(
                    child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                            color: DjassaTheme.borderLight,
                            borderRadius: BorderRadius.circular(999)))),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            isEditing
                                ? 'Modifier l\'article'
                                : 'Nouvel article',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(height: 1.05)),
                        const SizedBox(height: 5),
                        Text(
                            'Les clients verront ces informations dans la boutique.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ])),
                  IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 18),
                _FormSection(title: 'Informations principales', children: [
                  TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: 'Nom de l\'article',
                          prefixIcon: Icon(Icons.sell_outlined)),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nom obligatoire'
                          : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      initialValue:
                          widget.categories.any((c) => c.id == _categoryId)
                              ? _categoryId
                              : null,
                      decoration: const InputDecoration(
                          labelText: 'Rayon',
                          prefixIcon: Icon(Icons.grid_view_rounded)),
                      items: widget.categories
                          .map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) =>
                          v == null ? 'Choisissez un rayon' : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                          labelText: 'Description', alignLabelWithHint: true)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _compatibilityController,
                      decoration: const InputDecoration(
                          labelText: 'Compatibilité',
                          hintText: 'Toyota, Hyundai, Kia...',
                          prefixIcon: Icon(Icons.car_repair_rounded))),
                ]),
                const SizedBox(height: 14),
                _FormSection(title: 'Prix & stock', children: [
                  Row(children: [
                    Expanded(
                        child: _NumberField(
                            controller: _priceController,
                            label: 'Prix FCFA',
                            requiredField: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _NumberField(
                            controller: _oldPriceController,
                            label: 'Ancien prix')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _NumberField(
                            controller: _stockController,
                            label: 'Stock',
                            requiredField: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextFormField(
                            controller: _ratingController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Note',
                                prefixIcon: Icon(Icons.star_rounded)),
                            validator: (v) {
                              final r = double.tryParse(
                                  v?.replaceAll(',', '.') ?? '');
                              if (r == null || r < 0 || r > 5) return '0 à 5';
                              return null;
                            })),
                  ]),
                ]),
                const SizedBox(height: 14),
                _FormSection(title: 'Merchandising', children: [
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                            controller: _badgeController,
                            decoration: const InputDecoration(
                                labelText: 'Badge',
                                hintText: 'Top, Promo, -20%',
                                prefixIcon: Icon(Icons.local_offer_outlined)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            initialValue: _iconName,
                            decoration: const InputDecoration(
                                labelText: 'Icône',
                                prefixIcon: Icon(Icons.category_outlined)),
                            items: _icons
                                .map((i) =>
                                    DropdownMenuItem(value: i, child: Text(i)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _iconName = v ?? 'car'))),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _imageUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                          labelText: 'Image URL optionnelle',
                          prefixIcon: Icon(Icons.image_outlined))),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Publier dans la boutique'),
                      subtitle: Text(_isActive
                          ? 'L\'article est visible par les clients'
                          : 'L\'article reste brouillon / archivé'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v)),
                ]),
                const SizedBox(height: 18),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18))),
                        onPressed: _submit,
                        icon: Icon(
                            isEditing ? Icons.save_rounded : Icons.add_rounded),
                        label: Text(
                            isEditing ? 'Enregistrer' : 'Ajouter l\'article'))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(AdminProductInput(
      categoryId: _categoryId!,
      name: _nameController.text,
      description: _descriptionController.text,
      compatibility: _compatibilityController.text,
      price: int.parse(_priceController.text),
      oldPrice: int.tryParse(_oldPriceController.text) ?? 0,
      stock: int.parse(_stockController.text),
      rating: double.parse(_ratingController.text.replaceAll(',', '.')),
      badge: _badgeController.text,
      iconName: _iconName,
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text,
      isActive: _isActive,
    ));
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: DjassaTheme.borderMedium)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField(
      {required this.controller,
      required this.label,
      this.requiredField = false});
  final TextEditingController controller;
  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (!requiredField && (v == null || v.trim().isEmpty)) return null;
        final n = int.tryParse(v ?? '');
        if (n == null || n < 0) return 'Nombre invalide';
        return null;
      },
    );
  }
}
