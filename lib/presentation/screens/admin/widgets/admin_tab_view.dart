import 'package:djassa/core/theme/djassa_theme.dart';
import 'package:djassa/data/sources/remote/admin_service.dart';
import 'package:djassa/presentation/providers/core_providers.dart';
import 'package:djassa/presentation/screens/admin/pages/admin_products_screen.dart';
import 'package:djassa/presentation/screens/admin/widgets/catalogue_tab.dart';
import 'package:djassa/presentation/screens/admin/widgets/categories_tab.dart';
import 'package:djassa/presentation/screens/admin/widgets/notifications_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminTabView extends ConsumerWidget {
  const AdminTabView({
    super.key,
    required this.tabController,
    required this.searchController,
    required this.query,
    required this.onCreateProduct,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onCreateCategory,
    required this.onEditCategory,
    required this.onToggleCategoryActive,
    required this.onDeleteCategory,
    required this.onSendNotif,
    required this.onDeleteNotif,
  });

  final TabController tabController;
  final TextEditingController searchController;
  final String query;
  final VoidCallback onCreateProduct;
  final ValueChanged<AdminProduct> onEdit;
  final ValueChanged<AdminProduct> onToggleActive;
  final ValueChanged<AdminProduct> onDelete;
  final VoidCallback onCreateCategory;
  final ValueChanged<AdminCategory> onEditCategory;
  final ValueChanged<AdminCategory> onToggleCategoryActive;
  final ValueChanged<AdminCategory> onDeleteCategory;
  final VoidCallback onSendNotif;
  final ValueChanged<String> onDeleteNotif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);
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
                      ref.invalidate(adminCategoriesProvider);
                      ref.invalidate(adminProductsProvider);
                      ref.invalidate(categoriesProvider);
                      ref.invalidate(productsProvider);
                      ref.invalidate(notificationsProvider);
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
                        Text('Articles',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Rayons',
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
                  CatalogueTab(
                    searchController: searchController,
                    query: query,
                    onCreate: onCreateProduct,
                    onEdit: onEdit,
                    onToggleActive: onToggleActive,
                    onDelete: onDelete,
                  ),
                  CategoriesTab(
                    onCreate: onCreateCategory,
                    onEdit: onEditCategory,
                    onToggleActive: onToggleCategoryActive,
                    onDelete: onDeleteCategory,
                  ),
                  NotificationsTab(
                    onSend: onSendNotif,
                    onDelete: onDeleteNotif,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: tabController,
        builder: (_, __) {
          final isCategoryTab = tabController.index == 1;
          final isNotifTab = tabController.index == 2;
          return FloatingActionButton.extended(
            backgroundColor: DjassaTheme.accentOrange,
            onPressed: isNotifTab
                ? onSendNotif
                : isCategoryTab
                    ? onCreateCategory
                    : onCreateProduct,
            icon: Icon(isNotifTab
                ? Icons.send_rounded
                : isCategoryTab
                    ? Icons.grid_view_rounded
                    : Icons.add_rounded),
            label: Text(isNotifTab
                ? 'Envoyer'
                : isCategoryTab
                    ? 'Rayon'
                    : 'Article'),
          );
        },
      ),
    );
  }
}