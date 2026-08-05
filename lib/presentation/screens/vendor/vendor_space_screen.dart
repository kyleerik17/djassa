import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

// Imports locaux
import '../../../core/theme/avatar_picker.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../../data/sources/remote/shop_service.dart';
import '../../../data/services/structure_service.dart';
import '../../../domain/entities/structure.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shared/logout_confirmation_sheet.dart';
import '../../widgets/vendor/vendor_scaffold.dart';
import '../shop/shop_data.dart';

// ============================================================================
// 🏗️ DATA CLASSES FOR CLEAN PARAMETER PASSING
// ============================================================================

class _ShopControllers {
  final TextEditingController name;
  final TextEditingController desc;
  final TextEditingController phone;
  final TextEditingController address;
  final TextEditingController fee;
  final TextEditingController minOrder;

  _ShopControllers({
    required this.name,
    required this.desc,
    required this.phone,
    required this.address,
    required this.fee,
    required this.minOrder,
  });
}

class _ShopSettings {
  String opening;
  String closing;
  bool active;
  final ValueChanged<String> setOpening;
  final ValueChanged<String> setClosing;
  final ValueChanged<bool> setActive;

  _ShopSettings({
    required this.opening,
    required this.closing,
    required this.active,
    required this.setOpening,
    required this.setClosing,
    required this.setActive,
  });
}

// ============================================================================
// 🏗️ VENDOR SPACE SCREEN
// ============================================================================

class VendorSpaceScreen extends ConsumerStatefulWidget {
  const VendorSpaceScreen({super.key, this.tabIndex = 0});
  final int tabIndex;

  @override
  ConsumerState<VendorSpaceScreen> createState() => _VendorSpaceScreenState();
}

class _VendorSpaceScreenState extends ConsumerState<VendorSpaceScreen> {
  // Controllers
  late _ShopControllers _controllers;

  // Settings State
  String _openingHour = '08:00';
  String _closingHour = '18:00';
  bool _isActive = true;

  // UI State
  bool _isEditingShop = false;
  bool _isSaving = false;
  bool _isCreatingProduct = false;
  String? _deletingProductId;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _controllers = _ShopControllers(
      name: TextEditingController(),
      desc: TextEditingController(),
      phone: TextEditingController(),
      address: TextEditingController(),
      fee: TextEditingController(),
      minOrder: TextEditingController(),
    );
  }

  @override
  void dispose() {
    _controllers.name.dispose();
    _controllers.desc.dispose();
    _controllers.phone.dispose();
    _controllers.address.dispose();
    _controllers.fee.dispose();
    _controllers.minOrder.dispose();
    super.dispose();
  }

  // Synchronise les controllers avec la structure actuelle
  void _syncWithStructure(Structure? structure) {
    if (structure == null) return;
    _controllers.name.text = structure.name;
    _controllers.desc.text = structure.description;
    _controllers.phone.text = structure.phone;
    _controllers.address.text = structure.address;
    _controllers.fee.text = '${structure.deliveryFee}';
    _controllers.minOrder.text = '${structure.minimumOrder}';
    _openingHour = structure.openingHour;
    _closingHour = structure.closingHour;
    _isActive = structure.isActive;
  }

  Future<void> _saveShopConfig(Structure currentStructure) async {
    if (!_isFormValid()) return;
    setState(() => _isSaving = true);

    try {
      final updatedStructure = currentStructure.copyWith(
        name: _controllers.name.text.trim(),
        description: _controllers.desc.text.trim(),
        phone: _controllers.phone.text.trim(),
        address: _controllers.address.text.trim(),
        deliveryFee: int.tryParse(_controllers.fee.text.trim()) ?? 0,
        minimumOrder: int.tryParse(_controllers.minOrder.text.trim()) ?? 0,
        openingHour: _openingHour,
        closingHour: _closingHour,
        isActive: _isActive,
      );

      await ref.read(structureServiceProvider).save(updatedStructure);

      ref.invalidate(vendorStructureProvider);
      ref.invalidate(vendorOrdersProvider);
      if (updatedStructure.id.isNotEmpty) {
        ref.invalidate(vendorProductsProvider(updatedStructure.id));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Boutique mise à jour'),
              backgroundColor: Colors.green),
        );
        setState(() => _isEditingShop = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _isFormValid() {
    return _controllers.name.text.isNotEmpty &&
        _controllers.phone.text.isNotEmpty &&
        _controllers.address.text.isNotEmpty;
  }

  Future<void> _handleCreateProduct(Structure structure) async {
    if (structure.id.isEmpty) {
      setState(() => _isEditingShop = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurez d\'abord votre boutique.')),
      );
      return;
    }

    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune catégorie disponible.')));
      return;
    }

    final input = await showModalBottomSheet<VendorProductInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ProductFormSheet(categories: categories, structureId: structure.id),
    );

    if (input == null || !mounted) return;

    setState(() => _isCreatingProduct = true);
    try {
      await ref
          .read(shopServiceProvider)
          .createVendorProduct(structureId: structure.id, input: input);
      ref.invalidate(vendorProductsProvider(structure.id));
      ref.invalidate(productsProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Article ajouté !'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isCreatingProduct = false);
    }
  }

  Future<void> _handleDeleteProduct(
      Structure structure, ShopProduct product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet article ?'),
        content:
            Text('L\'article "${product.name}" sera retiré définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingProductId = product.id);
    try {
      await ref.read(shopServiceProvider).deleteVendorProduct(
          structureId: structure.id, productId: product.id);
      ref.invalidate(vendorProductsProvider(structure.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Article supprimé'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _deletingProductId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final structureAsync = ref.watch(vendorStructureProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);
    final navIndex = widget.tabIndex.clamp(0, 1);

    if (user == null) return _LoginPrompt();
    if (!user.isVendor) return _NotVendorPrompt();

    return VendorScaffold(
      currentIndex: navIndex,
      title: navIndex == 1 ? 'Commandes' : 'Ma Boutique',
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(vendorStructureProvider);
              ref.invalidate(vendorOrdersProvider);
              ref.invalidate(categoriesProvider);
            }),
        IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _logout(context)),
      ],
      body: navIndex == 1
          ? _OrdersTab(ordersAsync: ordersAsync)
          : structureAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (structure) {
                _syncWithStructure(structure);

                final settings = _ShopSettings(
                  opening: _openingHour,
                  closing: _closingHour,
                  active: _isActive,
                  setOpening: (v) => setState(() => _openingHour = v),
                  setClosing: (v) => setState(() => _closingHour = v),
                  setActive: (v) => setState(() => _isActive = v),
                );

                return _ShopTab(
                  structure: structure,
                  user: user,
                  isEditing: _isEditingShop,
                  onToggleEdit: () =>
                      setState(() => _isEditingShop = !_isEditingShop),
                  onSave: () => _saveShopConfig(structure),
                  isSaving: _isSaving,
                  controllers: _controllers,
                  settings: settings,
                  onCreateProduct: () => _handleCreateProduct(structure),
                  isCreatingProduct: _isCreatingProduct,
                  selectedCategoryId: _selectedCategoryId,
                  onCategorySelect: (id) =>
                      setState(() => _selectedCategoryId = id),
                  deletingProductId: _deletingProductId,
                  onDeleteProduct: (p) => _handleDeleteProduct(structure, p),
                );
              },
            ),
    );
  }

  void _logout(BuildContext context) {
    showLogoutConfirmationSheet(context, onConfirm: () async {
      await ref.read(authNotifierProvider.notifier).logoutUser();
      if (context.mounted) context.go(AppConstants.loginRoute);
    });
  }
}

// ============================================================================
// 🧩 TABS & SECTIONS
// ============================================================================

class _ShopTab extends ConsumerWidget {
  final Structure structure;
  final dynamic user;
  final bool isEditing;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final bool isSaving;
  final _ShopControllers controllers;
  final _ShopSettings settings;
  final VoidCallback onCreateProduct;
  final bool isCreatingProduct;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelect;
  final String? deletingProductId;
  final ValueChanged<ShopProduct> onDeleteProduct;

  const _ShopTab({
    required this.structure,
    required this.user,
    required this.isEditing,
    required this.onToggleEdit,
    required this.onSave,
    required this.isSaving,
    required this.controllers,
    required this.settings,
    required this.onCreateProduct,
    required this.isCreatingProduct,
    required this.selectedCategoryId,
    required this.onCategorySelect,
    required this.deletingProductId,
    required this.onDeleteProduct,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(vendorProductsProvider(structure.id));
    final categoriesAsync = ref.watch(categoriesProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _VendorHeader(user: user, structure: structure),
        const SizedBox(height: 16),
        productsAsync.when(
          data: (products) => ordersAsync.when(
            data: (orders) => _VendorOverviewStrip(
              productsCount: products.length,
              totalStock: products.fold<int>(0, (sum, p) => sum + p.stock),
              ordersCount: orders.length,
              revenue: orders.fold<int>(0, (sum, o) => sum + o.total),
            ),
            loading: () => _VendorOverviewStrip(
              productsCount: products.length,
              totalStock: products.fold<int>(0, (sum, p) => sum + p.stock),
              ordersCount: 0,
              revenue: 0,
            ),
            error: (_, __) => _VendorOverviewStrip(
              productsCount: products.length,
              totalStock: products.fold<int>(0, (sum, p) => sum + p.stock),
              ordersCount: 0,
              revenue: 0,
            ),
          ),
          loading: () => const _VendorOverviewSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        if (isEditing)
          _ShopConfigForm(
            controllers: controllers,
            settings: settings,
            isSaving: isSaving,
            onSave: onSave,
            onCancel: onToggleEdit,
          )
        else
          _ShopSummaryCard(structure: structure, onEdit: onToggleEdit),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: DjassaTheme.vendorPrimary.withValues(alpha: .12))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mes Articles',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: DjassaTheme.vendorPrimary),
                    onPressed: isCreatingProduct ? null : onCreateProduct,
                    icon: isCreatingProduct
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add),
                    label: Text(isCreatingProduct ? '...' : 'Ajouter'),
                  )
                ],
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                data: (cats) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Chip(
                          label: 'Tous',
                          selected: selectedCategoryId == null,
                          onTap: () => onCategorySelect(null)),
                      const SizedBox(width: 8),
                      ...cats.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _Chip(
                                label: c.name,
                                selected: selectedCategoryId == c.id,
                                onTap: () => onCategorySelect(c.id)),
                          )),
                    ],
                  ),
                ),
                loading: () => const SizedBox(
                    height: 40,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              productsAsync.when(
                data: (products) {
                  final filtered = selectedCategoryId == null
                      ? products
                      : products
                          .where((p) => p.categoryId == selectedCategoryId)
                          .toList();

                  if (filtered.isEmpty) {
                    return _EmptyState(onAdd: onCreateProduct);
                  }

                  final grouped = <String, List<ShopProduct>>{};
                  for (var p in filtered) {
                    grouped.putIfAbsent(p.category, () => []).add(p);
                  }

                  // ✅ CORRECTION: Utilisation simple de map sans expand complexe
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: grouped.entries
                        .map((e) => _ProductGroup(
                              categoryName: e.key,
                              products: e.value,
                              deletingId: deletingProductId,
                              onDelete: onDeleteProduct,
                            ))
                        .toList(),
                  );
                },
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator())),
                error: (e, _) => Text('Erreur chargement: $e'),
              )
            ],
          ),
        )
      ],
    );
  }
}

class _OrdersTab extends StatelessWidget {
  final AsyncValue<List<VendorOrder>> ordersAsync;
  const _OrdersTab({required this.ordersAsync});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200)),
          child: ordersAsync.when(
            data: (orders) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historique Commandes',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _VendorOrderSummary(orders: orders),
                const SizedBox(height: 16),
                if (orders.isEmpty)
                  _EmptyOrdersState()
                else
                  ...orders.map((o) => _OrderCard(order: o)).toList(),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erreur: $e'),
          ),
        )
      ],
    );
  }
}

class _VendorOrderSummary extends StatelessWidget {
  const _VendorOrderSummary({required this.orders});

  final List<VendorOrder> orders;

  @override
  Widget build(BuildContext context) {
    final revenue = orders.fold<int>(0, (sum, order) => sum + order.total);
    final items = orders.fold<int>(0, (sum, order) => sum + order.itemsCount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.vendorDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _OrderSummaryItem(label: 'Commandes', value: '${orders.length}'),
          _OrderSummaryItem(label: 'Articles', value: '$items'),
          _OrderSummaryItem(label: 'Total', value: formatPrice(revenue)),
        ],
      ),
    );
  }
}

class _OrderSummaryItem extends StatelessWidget {
  const _OrderSummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .64), fontSize: 11)),
        ],
      ),
    );
  }
}

// ============================================================================
// UI WIDGETS
// ============================================================================

class _VendorHeader extends StatelessWidget {
  final dynamic user;
  final Structure structure;
  const _VendorHeader({required this.user, required this.structure});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DjassaTheme.vendorDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          AvatarPicker(
            currentUrl: user.avatarUrl,
            radius: 30,
            fallbackIcon: Icons.storefront,
            fallbackColor: DjassaTheme.vendorPrimary,
            backgroundColor: DjassaTheme.vendorPrimary.withValues(alpha: 0.18),
            onUpdated: (_) {},
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp)),
                Text(
                    structure.name.isEmpty
                        ? 'Boutique non configurée'
                        : structure.name,
                    style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: structure.isActive
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(structure.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                          color:
                              structure.isActive ? Colors.green : Colors.orange,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.insights_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _VendorOverviewStrip extends StatelessWidget {
  const _VendorOverviewStrip({
    required this.productsCount,
    required this.totalStock,
    required this.ordersCount,
    required this.revenue,
  });

  final int productsCount;
  final int totalStock;
  final int ordersCount;
  final int revenue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _VendorMetricCard(
          icon: Icons.inventory_2_rounded,
          label: 'Articles',
          value: '$productsCount',
        ),
        const SizedBox(width: 10),
        _VendorMetricCard(
          icon: Icons.warehouse_rounded,
          label: 'Stock',
          value: '$totalStock',
        ),
        const SizedBox(width: 10),
        _VendorMetricCard(
          icon: Icons.receipt_long_rounded,
          label: 'Ventes',
          value: '$ordersCount',
        ),
        const SizedBox(width: 10),
        _VendorMetricCard(
          icon: Icons.payments_rounded,
          label: 'CA',
          value: formatPrice(revenue),
        ),
      ],
    );
  }
}

class _VendorMetricCard extends StatelessWidget {
  const _VendorMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DjassaTheme.vendorSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: DjassaTheme.vendorPrimary.withValues(alpha: .12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: DjassaTheme.vendorPrimary, size: 18),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: DjassaTheme.vendorDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            Text(label,
                style: const TextStyle(
                    color: DjassaTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _VendorOverviewSkeleton extends StatelessWidget {
  const _VendorOverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        4,
        (index) => Expanded(
          child: Container(
            height: 86,
            margin: EdgeInsets.only(right: index == 3 ? 0 : 10),
            decoration: BoxDecoration(
              color: DjassaTheme.vendorSoft.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopConfigForm extends StatelessWidget {
  final _ShopControllers controllers;
  final _ShopSettings settings;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _ShopConfigForm(
      {required this.controllers,
      required this.settings,
      required this.isSaving,
      required this.onSave,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Configuration Boutique',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
            IconButton(icon: const Icon(Icons.close), onPressed: onCancel)
          ]),
          const SizedBox(height: 16),
          _Field(
              label: 'Nom',
              controller: controllers.name,
              validator: (v) => v!.isEmpty ? 'Requis' : null),
          _Field(
              label: 'Description', controller: controllers.desc, maxLines: 3),
          _Field(
              label: 'Téléphone',
              controller: controllers.phone,
              keyboardType: TextInputType.phone),
          _Field(
              label: 'Adresse', controller: controllers.address, maxLines: 2),
          Row(children: [
            Expanded(
                child: _Field(
                    label: 'Frais Livraison',
                    controller: controllers.fee,
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(
                child: _Field(
                    label: 'Min. Commande',
                    controller: controllers.minOrder,
                    keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 16),
          SwitchListTile(
              title: const Text('Boutique Active'),
              value: settings.active,
              onChanged: settings.setActive,
              contentPadding: EdgeInsets.zero),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: isSaving ? null : onSave,
                  child: isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Enregistrer')))
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _Field(
      {required this.label,
      required this.controller,
      this.maxLines = 1,
      this.keyboardType = TextInputType.text,
      this.validator});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        validator: validator,
      ),
    );
  }
}

class _ShopSummaryCard extends StatelessWidget {
  final Structure structure;
  final VoidCallback onEdit;
  const _ShopSummaryCard({required this.structure, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            const Icon(Icons.store, color: DjassaTheme.vendorPrimary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      structure.name.isEmpty
                          ? 'Configurer ma boutique'
                          : structure.name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16.sp)),
                  Text(
                      structure.address.isEmpty
                          ? 'Adresse non renseignée'
                          : structure.address,
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.edit, color: Colors.grey)
          ],
        ),
      ),
    );
  }
}

class _ProductGroup extends StatelessWidget {
  final String categoryName;
  final List<ShopProduct> products;
  final String? deletingId;
  final ValueChanged<ShopProduct> onDelete;

  const _ProductGroup(
      {required this.categoryName,
      required this.products,
      required this.deletingId,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(categoryName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: DjassaTheme.vendorPrimary))),
        ...products.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ProductItem(
                  product: p,
                  isDeleting: deletingId == p.id,
                  onDelete: () => onDelete(p)),
            )),
        const SizedBox(height: 12)
      ],
    );
  }
}

class _ProductItem extends StatelessWidget {
  final ShopProduct product;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _ProductItem(
      {required this.product,
      required this.isDeleting,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.image, color: Colors.grey.shade300)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${product.price} FCFA',
                    style: const TextStyle(
                        color: DjassaTheme.vendorPrimary,
                        fontWeight: FontWeight.bold)),
                Text('Stock: ${product.stock}',
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey))
              ],
            ),
          ),
          isDeleting
              ? const CircularProgressIndicator(strokeWidth: 2)
              : IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete)
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final VendorOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    '${order.itemsCount} articles • ${formatPrice(order.total)}',
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(order.statusLabel,
                  style: TextStyle(
                      color: DjassaTheme.vendorPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp)),
              const SizedBox(height: 4),
              Text(
                  order.createdAt != null
                      ? '${order.createdAt!.day}/${order.createdAt!.month}'
                      : '-',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? DjassaTheme.vendorPrimary : DjassaTheme.vendorSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Aucun article', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un article'))
        ],
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Aucune commande pour le moment',
                style: TextStyle(color: Colors.grey))));
  }
}

class _LoginPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Se connecter'))));
  }
}

class _NotVendorPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.storefront, size: 48),
      const Text('Compte non vendeur'),
      FilledButton(
          onPressed: () => context.go('/home'), child: const Text('Retour'))
    ])));
  }
}

// ============================================================================
// 📝 PRODUCT FORM SHEET
// ============================================================================

class _ProductFormSheet extends StatefulWidget {
  final List<ShopCategory> categories;
  final String structureId;
  const _ProductFormSheet(
      {required this.categories, required this.structureId});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  String? _catId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) _catId = widget.categories.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Nouvel Article',
                    style: TextStyle(
                        fontSize: 20.sp, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v!.isEmpty ? 'Requis' : null),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _catId,
                  items: widget.categories
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _catId = v),
                  decoration: InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: 'Prix',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextFormField(
                          controller: _stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: 'Stock',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))))),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Text('Créer')))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 1)); // Simule upload
    if (mounted) {
      Navigator.pop(
          context,
          VendorProductInput(
            categoryId: _catId!,
            name: _nameCtrl.text,
            description: '',
            compatibility: '',
            price: int.parse(_priceCtrl.text),
            oldPrice: 0,
            stock: int.parse(_stockCtrl.text),
            badge: '',
            iconName: '',
            imageUrl: '',
            isActive: true,
          ));
    }
  }
}

class VendorOrderDetailsScreen extends ConsumerWidget {
  const VendorOrderDetailsScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(vendorOrdersProvider);

    // Recherche de la commande dans la liste déjà chargée
    final order = ordersAsync.valueOrNull?.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Commande non trouvée'),
    );

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail commande')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Commande ${order.orderNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Discuter',
            onPressed: () => context.go(
              '/order-chat/${order.id}?number=${Uri.encodeComponent(order.orderNumber)}',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Statut & Date ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DjassaTheme.vendorSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: DjassaTheme.vendorPrimary.withValues(alpha: .2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statut',
                      style: TextStyle(
                        fontSize: 12,
                        color: DjassaTheme.textSecondary,
                      ),
                    ),
                    Text(
                      order.statusLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: DjassaTheme.vendorPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: DjassaTheme.textSecondary,
                      ),
                    ),
                    Text(
                      order.createdAt != null
                          ? '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}'
                          : '-',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Articles commandés ─────────────────────────────
          Text(
            'Articles commandés',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...order.items.map((item) {
            // Récupération dynamique du prix unitaire
            final int itemPrice =
                (item as dynamic).unitPrice ?? (item as dynamic).price ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DjassaTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${item.quantity} x ${formatPrice(itemPrice)}',
                    style: const TextStyle(color: DjassaTheme.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatPrice(itemPrice * item.quantity),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 32),

          // ── Total ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total de la commande',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                formatPrice(order.total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: DjassaTheme.vendorPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Adresse de livraison ───────────────────────────
          Text(
            'Adresse de livraison',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DjassaTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: DjassaTheme.vendorPrimary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
