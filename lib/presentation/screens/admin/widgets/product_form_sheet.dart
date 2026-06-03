import 'package:flutter/material.dart';

import '../../../../core/theme/djassa_theme.dart';
import '../../../../data/sources/remote/admin_service.dart';
import 'form_widgets.dart';

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
                FormSection(title: 'Informations principales', children: [
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
                FormSection(title: 'Prix & stock', children: [
                  Row(children: [
                    Expanded(
                        child: NumberField(
                            controller: _priceController,
                            label: 'Prix FCFA',
                            requiredField: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: NumberField(
                            controller: _oldPriceController,
                            label: 'Ancien prix')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: NumberField(
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
                FormSection(title: 'Merchandising', children: [
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