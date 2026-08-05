import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Import Supabase

import '../../../../core/theme/djassa_theme.dart';
import 'form_widgets.dart';

class AdminCategoryFormSheet extends StatefulWidget {
  const AdminCategoryFormSheet({
    super.key,
    this.category,
  });

  final Map<String, dynamic>? category; // ✅ On accepte une Map venant de Supabase

  @override
  State<AdminCategoryFormSheet> createState() => _AdminCategoryFormSheetState();
}

class _AdminCategoryFormSheetState extends State<AdminCategoryFormSheet> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _sortOrderController;
  String _iconName = 'category';
  bool _isActive = true;
  bool _isSubmitting = false; // ✅ État de chargement

  static const _icons = [
    'category', 'devices', 'home', 'checkroom', 'spa', 'sports_soccer',
    'car_repair', 'settings', 'electric_bolt', 'oil', 'tire',
  ];

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?['name'] ?? '');
    _subtitleController = TextEditingController(text: category?['subtitle'] ?? '');
    _sortOrderController = TextEditingController(
      text: category == null ? '0' : '${category['sort_order']}',
    );
    _iconName = _icons.contains(category?['icon_name']) 
        ? category!['icon_name'] 
        : 'category';
    _isActive = category?['is_active'] ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.category != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .58,
        maxChildSize: .9,
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
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Modifier le rayon' : 'Nouveau rayon',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(height: 1.05),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Sauvegarde directe dans Supabase.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 18),
                FormSection(title: 'Informations du rayon', children: [
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nom du rayon',
                      prefixIcon: Icon(Icons.grid_view_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nom obligatoire'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subtitleController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description courte',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: NumberField(
                        controller: _sortOrderController,
                        label: 'Ordre',
                        requiredField: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _iconName,
                        decoration: const InputDecoration(
                          labelText: 'Icône',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _icons
                            .map((icon) => DropdownMenuItem(
                                  value: icon,
                                  child: Text(icon),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _iconName = value ?? 'category'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publier dans la boutique'),
                    subtitle: Text(_isActive
                        ? 'Le rayon est visible par les clients'
                        : 'Le rayon reste archivé'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ]),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      backgroundColor: _isSubmitting ? Colors.grey : DjassaTheme.accentOrange,
                    ),
                    onPressed: _isSubmitting ? null : _submitToSupabase,
                    icon: _isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isEditing ? Icons.save_rounded : Icons.add_rounded),
                    label: Text(_isSubmitting ? 'Sauvegarde...' : (isEditing ? 'Enregistrer' : 'Ajouter le rayon')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitToSupabase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'name': _nameController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
        'icon_name': _iconName,
        'sort_order': int.parse(_sortOrderController.text),
        'is_active': _isActive,
        'slug': _nameController.text.trim().toLowerCase().replaceAll(' ', '-'),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.category != null) {
        // UPDATE
        await _supabase
            .from('categories')
            .update(payload)
            .eq('id', widget.category!['id']);
      } else {
        // INSERT
        payload['created_at'] = DateTime.now().toIso8601String();
        await _supabase.from('categories').insert(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.category != null ? 'Rayon mis à jour !' : 'Rayon créé !'), backgroundColor: Colors.green)
        );
        Navigator.of(context).pop(true); // Retourne true pour rafraîchir la liste
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}