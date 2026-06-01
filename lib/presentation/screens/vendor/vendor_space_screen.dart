import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/avatar_picker.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../../data/sources/remote/shop_service.dart';
import '../../../data/services/structure_service.dart';
import '../../../domain/entities/structure.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/vendor/vendor_scaffold.dart';
import '../shop/shop_data.dart';

/// Espace vendeur : boutique (articles par catégorie) + commandes.
class VendorSpaceScreen extends ConsumerStatefulWidget {
  const VendorSpaceScreen({super.key, this.tabIndex = 0});

  /// 0 = boutique (articles), 1 = commandes reçues
  final int tabIndex;

  @override
  ConsumerState<VendorSpaceScreen> createState() => _VendorSpaceScreenState();
}

class _VendorSpaceScreenState extends ConsumerState<VendorSpaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _minimumOrderController = TextEditingController();
  String _openingHour = '08:00';
  String _closingHour = '18:00';
  bool _isActive = true;
  bool _initialized = false;
  bool _saving = false;
  bool _creatingProduct = false;

  // ✅ Contrôle l'affichage du formulaire de configuration
  bool _formVisible = false;

  // Categorie selectionnee pour filtrer les articles.
  String? _selectedCategoryId;

  Structure? _structure;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _deliveryFeeController.dispose();
    _minimumOrderController.dispose();
    super.dispose();
  }

  void _bindStructure(Structure structure) {
    if (_initialized) return;
    _structure = structure;
    _nameController.text = structure.name;
    _descriptionController.text = structure.description;
    _phoneController.text = structure.phone;
    _addressController.text = structure.address;
    _deliveryFeeController.text = '${structure.deliveryFee}';
    _minimumOrderController.text = '${structure.minimumOrder}';
    _openingHour = structure.openingHour;
    _closingHour = structure.closingHour;
    _isActive = structure.isActive;
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final current = _structure ?? Structure.empty;
      final saved = await ref.read(structureServiceProvider).save(
            current.copyWith(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              phone: _phoneController.text.trim(),
              address: _addressController.text.trim(),
              deliveryFee:
                  int.tryParse(_deliveryFeeController.text.trim()) ?? 0,
              minimumOrder:
                  int.tryParse(_minimumOrderController.text.trim()) ?? 0,
              openingHour: _openingHour,
              closingHour: _closingHour,
              isActive: _isActive,
            ),
          );
      _structure = saved;
      ref.invalidate(vendorStructureProvider);
      ref.invalidate(vendorOrdersProvider);
      if (saved.id.isNotEmpty) {
        ref.invalidate(vendorProductsProvider(saved.id));
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Boutique enregistrée.'),
        ),
      );

      // ✅ Masquer le formulaire après sauvegarde
      setState(() => _formVisible = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCreateProduct(Structure structure) async {
    if (structure.id.isEmpty) {
      setState(() => _formVisible = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enregistrez votre boutique avant de creer un article.',
          ),
        ),
      );
      return;
    }

    List<ShopCategory> categories;
    try {
      categories = await ref.read(categoriesProvider.future);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger les categories: $error')),
      );
      return;
    }

    if (!mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune categorie active disponible.'),
        ),
      );
      return;
    }

    final input = await showModalBottomSheet<VendorProductInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VendorProductFormSheet(categories: categories),
    );
    if (input == null) return;

    setState(() => _creatingProduct = true);
    try {
      await ref.read(shopServiceProvider).createVendorProduct(
            structureId: structure.id,
            input: input,
          );
      ref.invalidate(vendorProductsProvider(structure.id));
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Article ajoute a votre boutique.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Creation impossible: $error')),
      );
    } finally {
      if (mounted) setState(() => _creatingProduct = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await ref.read(authNotifierProvider.notifier).logoutUser();
    if (context.mounted) context.go(AppConstants.loginRoute);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final structureAsync = ref.watch(vendorStructureProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go(AppConstants.loginRoute),
            child: const Text('Se connecter'),
          ),
        ),
      );
    }

    if (!user.isVendor) {
      return Scaffold(
        appBar: AppBar(title: const Text('Espace vendeur')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_rounded, size: 72),
                const SizedBox(height: 16),
                const Text(
                  "Ce compte n'est pas un profil vendeur",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(AppConstants.homeRoute),
                  child: const Text('Retour accueil'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final navIndex = widget.tabIndex.clamp(0, 1);

    return VendorScaffold(
      currentIndex: navIndex,
      title: navIndex == 1 ? 'Commandes boutique' : 'Ma boutique',
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          onPressed: () {
            ref.invalidate(vendorStructureProvider);
            ref.invalidate(vendorOrdersProvider);
            ref.invalidate(categoriesProvider);
            ref.invalidate(productsProvider);
            final structureId = _structure?.id ?? '';
            if (structureId.isNotEmpty) {
              ref.invalidate(vendorProductsProvider(structureId));
            }
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Déconnexion',
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      body: navIndex == 1
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _VendorOrdersSection(ordersAsync: ordersAsync),
              ],
            )
          : structureAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (structure) {
                _bindStructure(structure);
                final complete = structure.isProfileComplete;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _VendorIdentityCard(
                      name: user.fullName.trim().isEmpty
                          ? 'Vendeur Djassa'
                          : user.fullName,
                      phone: user.phone,
                      email: user.email,
                      roleLabel: user.roleLabel,
                      avatarUrl: user.avatarUrl,
                      shopComplete: complete,
                      isActive: _isActive,
                    ),
                    if (!complete) ...[
                      const SizedBox(height: 12),
                      _IncompleteShopBanner(),
                    ],
                    const SizedBox(height: 18),

                    // ✅ Section Articles par Catégorie OU Formulaire
                    if (_formVisible)
                      Form(
                        key: _formKey,
                        child: _buildShopForm(context),
                      )
                    else
                      _buildProductsByCategorySection(context, structure),
                  ],
                );
              },
            ),
    );
  }

  /// ✅ Section : Articles organisés par catégorie (données Supabase)
  Widget _buildProductsByCategorySection(
      BuildContext context, Structure structure) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(vendorProductsProvider(structure.id));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mes articles',
                  style: Theme.of(context).textTheme.titleLarge),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _formVisible = true),
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: 'Configurer la boutique',
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _creatingProduct
                        ? null
                        : () => _openCreateProduct(structure),
                    icon: _creatingProduct
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(_creatingProduct ? 'Ajout...' : 'Ajouter'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ✅ Chips de catégories depuis Supabase
          categoriesAsync.when(
            loading: () => const SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => Text(
              'Erreur: $error',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CategoryChip(
                      label: 'Tous',
                      isSelected: _selectedCategoryId == null,
                      onTap: () => setState(() => _selectedCategoryId = null),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CategoryChip(
                            label: cat.name,
                            isSelected: _selectedCategoryId == cat.id,
                            onTap: () => setState(
                              () => _selectedCategoryId =
                                  _selectedCategoryId == cat.id ? null : cat.id,
                            ),
                          ),
                        )),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // ✅ Produits filtrés par catégorie
          productsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade700, size: 48),
                  const SizedBox(height: 12),
                  Text('Erreur: $error',
                      style: TextStyle(color: Colors.red.shade700)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(categoriesProvider);
                      ref.invalidate(vendorProductsProvider(structure.id));
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
            data: (products) {
              // Filtrage par identifiant de categorie.
              final filtered = _selectedCategoryId == null
                  ? products
                  : products
                      .where((p) => p.categoryId == _selectedCategoryId)
                      .toList();

              if (filtered.isEmpty) {
                return _EmptyProductsState(
                  message: _selectedCategoryId == null
                      ? 'Aucun article dans votre boutique pour le moment.'
                      : 'Aucun article dans cette catégorie.',
                  onAdd: () => _openCreateProduct(structure),
                );
              }

              // Groupement par categorie si "Tous" est selectionne.
              if (_selectedCategoryId == null) {
                final grouped = <String, List<ShopProduct>>{};
                for (final product in filtered) {
                  final categoryName = product.category.trim().isEmpty
                      ? 'Sans categorie'
                      : product.category;
                  grouped.putIfAbsent(categoryName, () => []).add(product);
                }

                return Column(
                  children: grouped.entries
                      .map(
                        (entry) => _ProductsByCategoryGroup(
                          categoryName: entry.key,
                          products: entry.value,
                        ),
                      )
                      .toList(),
                );
              } else {
                // Affichage simple si une catégorie est filtrée
                return _ProductsList(products: filtered);
              }
            },
          ),
        ],
      ),
    );
  }

  /// ✅ Chip de catégorie filtrable
  Widget _CategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: DjassaTheme.backgroundSecondary,
      selectedColor: DjassaTheme.accentOrange.withValues(alpha: .15),
      checkmarkColor: DjassaTheme.accentOrange,
      labelStyle: TextStyle(
        color: isSelected ? DjassaTheme.accentOrange : DjassaTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  /// ✅ Formulaire de configuration de la boutique
  Widget _buildShopForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ma boutique',
                  style: Theme.of(context).textTheme.titleLarge),
              TextButton.icon(
                onPressed: () => setState(() => _formVisible = false),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Fermer'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            title: const Text('Boutique active'),
            subtitle: const Text(
              'Visible pour les clients lorsqu\'elle est active',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom de la boutique *',
              prefixIcon: Icon(Icons.store_rounded),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone boutique *',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Adresse *',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _deliveryFeeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Frais livraison (FCFA)',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _minimumOrderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Commande min. (FCFA)',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _openingHour,
                  decoration: const InputDecoration(labelText: 'Ouverture'),
                  items: _hourOptions
                      .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _openingHour = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _closingHour,
                  decoration: const InputDecoration(labelText: 'Fermeture'),
                  items: _hourOptions
                      .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _closingHour = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: DjassaTheme.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }

  static const _hourOptions = [
    '06:00',
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '12:00',
    '18:00',
    '20:00',
    '22:00',
  ];
}

class _VendorProductFormSheet extends StatefulWidget {
  const _VendorProductFormSheet({required this.categories});

  final List<ShopCategory> categories;

  @override
  State<_VendorProductFormSheet> createState() =>
      _VendorProductFormSheetState();
}

class _VendorProductFormSheetState extends State<_VendorProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _compatibilityController = TextEditingController();
  final _priceController = TextEditingController();
  final _oldPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _badgeController = TextEditingController(text: 'Top');

  String? _categoryId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.isEmpty ? null : widget.categories.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _compatibilityController.dispose();
    _priceController.dispose();
    _oldPriceController.dispose();
    _stockController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        minChildSize: .68,
        maxChildSize: .95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: DjassaTheme.backgroundSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nouvel article',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(height: 1.05),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _VendorFormSection(
                  title: 'Informations',
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'article',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nom obligatoire'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Categorie',
                        prefixIcon: Icon(Icons.grid_view_rounded),
                      ),
                      items: widget.categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _categoryId = value),
                      validator: (value) =>
                          value == null ? 'Choisissez une categorie' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _compatibilityController,
                      decoration: const InputDecoration(
                        labelText: 'Compatibilite',
                        hintText: 'Toyota, Hyundai, Kia...',
                        prefixIcon: Icon(Icons.car_repair_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _VendorFormSection(
                  title: 'Prix et stock',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _VendorNumberField(
                            controller: _priceController,
                            label: 'Prix FCFA',
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _VendorNumberField(
                            controller: _oldPriceController,
                            label: 'Ancien prix',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _VendorNumberField(
                            controller: _stockController,
                            label: 'Stock',
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _badgeController,
                            decoration: const InputDecoration(
                              labelText: 'Badge',
                              hintText: 'Top, Promo',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Publier dans la boutique'),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _submit,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Creer l\'article'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final selectedCategory = widget.categories.firstWhere(
      (category) => category.id == _categoryId,
      orElse: () => widget.categories.first,
    );

    Navigator.of(context).pop(
      VendorProductInput(
        categoryId: _categoryId!,
        name: _nameController.text,
        description: _descriptionController.text,
        compatibility: _compatibilityController.text,
        price: int.parse(_priceController.text),
        oldPrice: int.tryParse(_oldPriceController.text) ?? 0,
        stock: int.parse(_stockController.text),
        badge: _badgeController.text,
        iconName: selectedCategory.iconName,
        isActive: _isActive,
      ),
    );
  }
}

class _VendorFormSection extends StatelessWidget {
  const _VendorFormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _VendorNumberField extends StatelessWidget {
  const _VendorNumberField({
    required this.controller,
    required this.label,
    this.requiredField = false,
  });

  final TextEditingController controller;
  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (!requiredField && (value == null || value.trim().isEmpty)) {
          return null;
        }
        final number = int.tryParse(value ?? '');
        if (number == null || number < 0) return 'Nombre invalide';
        return null;
      },
    );
  }
}

// ============================================================================
// 🧩 WIDGETS UTILITAIRES
// ============================================================================

/// ✅ Groupe d'articles par catégorie
class _ProductsByCategoryGroup extends StatelessWidget {
  const _ProductsByCategoryGroup({
    required this.categoryName,
    required this.products,
  });

  final String categoryName;
  final List<ShopProduct> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: DjassaTheme.accentOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                categoryName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                '${products.length} article${products.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: DjassaTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        ...products.map((product) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VendorProductCard(product: product),
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// ✅ Liste simple d'articles (catégorie filtrée)
class _ProductsList extends StatelessWidget {
  const _ProductsList({required this.products});

  final List<ShopProduct> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: products
          .map((product) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VendorProductCard(product: product),
              ))
          .toList(),
    );
  }
}

/// ✅ Carte d'article pour vendeur
class _VendorProductCard extends StatelessWidget {
  const _VendorProductCard({required this.product});

  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DjassaTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DjassaTheme.borderLight),
      ),
      child: Row(
        children: [
          // Icone produit
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: DjassaTheme.primaryWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(product.icon, color: DjassaTheme.accentOrange, size: 36),
          ),
          const SizedBox(width: 14),

          // Infos produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (product.badge.isNotEmpty && product.badge != 'Top')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              DjassaTheme.accentOrange.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.badge,
                          style: const TextStyle(
                            color: DjassaTheme.accentOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.compatibility,
                  style: TextStyle(
                    color: DjassaTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      formatPrice(product.price),
                      style: const TextStyle(
                        color: DjassaTheme.accentOrange,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (product.oldPrice > product.price) ...[
                      const SizedBox(width: 6),
                      Text(
                        formatPrice(product.oldPrice),
                        style: TextStyle(
                          color: DjassaTheme.textSecondary,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Stock indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: product.stock > 0
                            ? Colors.green.withValues(alpha: .12)
                            : Colors.red.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.stock > 0
                            ? 'Stock ${product.stock}'
                            : 'Rupture',
                        style: TextStyle(
                          color: product.stock > 0 ? Colors.green : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ État vide pour la liste des produits
class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState({required this.message, this.onAdd});

  final String message;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DjassaTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 48, color: DjassaTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: DjassaTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (onAdd != null)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter mon premier article'),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🧩 WIDGETS EXISTANTS (inchangés)
// ============================================================================

class _VendorIdentityCard extends ConsumerWidget {
  const _VendorIdentityCard({
    required this.name,
    required this.phone,
    required this.email,
    required this.roleLabel,
    required this.shopComplete,
    required this.isActive,
    this.avatarUrl,
  });

  final String name;
  final String phone;
  final String? email;
  final String roleLabel;
  final bool shopComplete;
  final bool isActive;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          AvatarPicker(
            currentUrl: avatarUrl,
            radius: 32,
            fallbackIcon: Icons.storefront_rounded,
            fallbackColor: DjassaTheme.accentOrange,
            backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .16),
            onUpdated: (_) {
              ref.read(authNotifierProvider.notifier).refreshUser();
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DjassaTheme.primaryWhite,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email == null || email!.isEmpty ? phone : email!,
                  style: TextStyle(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .68),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$roleLabel · ${isActive ? 'Boutique active' : 'Boutique inactive'}',
                  style: TextStyle(
                    color:
                        shopComplete ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorOrdersSection extends ConsumerWidget {
  const _VendorOrdersSection({required this.ordersAsync});

  final AsyncValue<List<VendorOrder>> ordersAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: ordersAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mes commandes',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              '$error',
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(vendorOrdersProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
        data: (orders) {
          final total = orders.fold<int>(0, (sum, order) => sum + order.total);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mes commandes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    formatPrice(total),
                    style: const TextStyle(
                      color: DjassaTheme.accentOrange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Aucun profil client n\'est affiché ici.',
                style: TextStyle(
                  color: DjassaTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              if (orders.isEmpty)
                const _NoVendorOrders()
              else
                ...orders.take(6).map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _VendorOrderCard(order: order),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _NoVendorOrders extends StatelessWidget {
  const _NoVendorOrders();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: DjassaTheme.accentOrange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aucune commande liée à votre boutique pour le moment.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorOrderCard extends StatelessWidget {
  const _VendorOrderCard({required this.order});

  final VendorOrder order;

  @override
  Widget build(BuildContext context) {
    final date = order.createdAt == null
        ? ''
        : '${order.createdAt!.day.toString().padLeft(2, '0')}/'
            '${order.createdAt!.month.toString().padLeft(2, '0')}/'
            '${order.createdAt!.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DjassaTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DjassaTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _OrderStatusChip(label: order.statusLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (date.isNotEmpty) date,
              '${order.itemsCount} article(s)',
              formatPrice(order.total),
            ].join(' · '),
            style: const TextStyle(color: DjassaTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ...order.items.take(3).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'x${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: DjassaTheme.accentOrange.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: DjassaTheme.accentOrange,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IncompleteShopBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withValues(alpha: .35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Complétez le nom, le téléphone et l\'adresse de votre boutique.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
