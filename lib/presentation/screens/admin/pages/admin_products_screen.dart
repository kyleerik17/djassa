import 'package:djassa/presentation/screens/admin/widgets/admin_tab_view.dart';
import 'package:djassa/presentation/screens/admin/widgets/category_form_sheet.dart';
import 'package:djassa/presentation/screens/admin/widgets/notifications_tab.dart';
import 'package:djassa/presentation/screens/admin/widgets/product_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ 1. Import des modèles avec préfixe pour éviter les conflits de nom (AdminCategory/AdminProduct)
import '../../../../data/services/admin_notification_service.dart' as remote show AdminNotification;
import '../../../../data/sources/remote/admin_service.dart' as remote;

// ✅ 2. Import des providers ET du service depuis core_providers (sans préfixe)
import '../../../providers/core_providers.dart';

import '../../../../core/theme/djassa_theme.dart';
import '../../../../data/services/admin_notification_service.dart';
import '../widgets/error_widgets.dart';

// ── Helpers de conversion vers Map (pour Supabase) ──────────
extension ToMapExtension on remote.AdminProduct {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'stock': stock,
        'category_id': categoryId,
        'image_url': imageUrl,
        'is_active': isActive,
        'badge': badge,
      };
}

extension CategoryToMapExtension on remote.AdminCategory {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'icon_name': iconName,
        'sort_order': sortOrder,
        'is_active': isActive,
      };
}

// ── Providers locaux notifications ────────────────────────────

final notifServiceProvider = Provider((_) => AdminNotificationService());

final notificationsProvider =
    FutureProvider.autoDispose<List<remote.AdminNotification>>((ref) async {
  return ref.read(notifServiceProvider).fetchAll();
});

final notifUsersProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  return ref.read(notifServiceProvider).fetchUsers();
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
    _tabController = TabController(length: 3, vsync: this);
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
      loading: () => const AdminLoadingScaffold(),
      error: (error, _) => AdminAccessDenied(message: '$error'),
      data: (allowed) {
        if (!allowed) {
          return const AdminAccessDenied(
            message:
                'Connectez-vous avec un compte administrateur pour gérer les articles.',
          );
        }
        return AdminTabView(
          tabController: _tabController,
          searchController: _searchController,
          query: _query,
          onCreateProduct: () => _openCreateSheet(),
          onEdit: (product) => _openEditSheet(product),
          onToggleActive: (product) => _toggleActive(product),
          onDelete: (product) => _deleteProduct(product),
          onCreateCategory: () => _openCreateCategorySheet(),
          onEditCategory: (category) => _openEditCategorySheet(category),
          onToggleCategoryActive: (category) => _toggleCategoryActive(category),
          onDeleteCategory: (category) => _deleteCategory(category),
          onSendNotif: () => _openNotifDialog(),
          onDeleteNotif: (id) => _deleteNotif(id),
        );
      },
    );
  }

  // ── Notifications ─────────────────────────────────────────

  Future<void> _openNotifDialog() async {
    final users = await ref.read(notifUsersProvider.future);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => CreateNotifDialog(
        users: users,
        onSubmit: (input) async {
          await ref.read(notifServiceProvider).create(input);
          ref.invalidate(notificationsProvider);
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
      await ref.read(notifServiceProvider).delete(id);
      ref.invalidate(notificationsProvider);
    }
  }

  // ── Produits (SUPABASE DIRECT) ──────────────

  Future<void> _openCreateSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminProductFormSheet(),
    );

    if (result == true) {
      ref.invalidate(adminProductsProvider);
      ref.invalidate(productsProvider);
    }
  }

  Future<void> _openEditSheet(remote.AdminProduct product) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminProductFormSheet(product: product.toMap()),
    );

    if (result == true) {
      ref.invalidate(adminProductsProvider);
      ref.invalidate(productsProvider);
    }
  }

  Future<void> _toggleActive(remote.AdminProduct product) async {
    await _runMutation(
      successMessage:
          product.isActive ? 'Article archivé.' : 'Article remis en ligne.',
      // ✅ Pas de préfixe 'remote' ici car adminServiceProvider vient de core_providers
      action: () => ref.read(adminServiceProvider).setProductActive(
            id: product.id,
            isActive: !product.isActive,
          ),
    );
  }

  Future<void> _deleteProduct(remote.AdminProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: Text('"${product.name}" sera supprimé du catalogue.'),
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

  // ── Rayons (SUPABASE DIRECT) ───────────────

  Future<void> _openCreateCategorySheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminCategoryFormSheet(),
    );

    if (result == true) {
      ref.invalidate(adminCategoriesProvider);
      ref.invalidate(categoriesProvider);
    }
  }

  Future<void> _openEditCategorySheet(remote.AdminCategory category) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminCategoryFormSheet(category: category.toMap()),
    );

    if (result == true) {
      ref.invalidate(adminCategoriesProvider);
      ref.invalidate(categoriesProvider);
    }
  }

  Future<void> _toggleCategoryActive(remote.AdminCategory category) async {
    await _runMutation(
      successMessage:
          category.isActive ? 'Rayon archivé.' : 'Rayon remis en ligne.',
      action: () => ref.read(adminServiceProvider).setCategoryActive(
            id: category.id,
            isActive: !category.isActive,
          ),
    );
  }

  Future<void> _deleteCategory(remote.AdminCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: Text(
          '"${category.name}" sera supprimé. Les articles liés passeront en sans rayon.',
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
      successMessage: 'Rayon supprimé.',
      action: () => ref.read(adminServiceProvider).deleteCategory(category.id),
    );
  }

  Future<void> _runMutation({
    required String successMessage,
    required Future<dynamic> Function() action,
  }) async {
    try {
      await action();
      ref.invalidate(adminCategoriesProvider);
      ref.invalidate(categoriesProvider);
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