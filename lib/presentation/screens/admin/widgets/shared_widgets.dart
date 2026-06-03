import 'package:flutter/material.dart';

import '../../../../core/theme/djassa_theme.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({super.key, required this.controller});
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

class ChipWidget extends StatelessWidget {
  const ChipWidget({super.key, required this.label, required this.color});
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

class EmptyAdminList extends StatelessWidget {
  const EmptyAdminList({super.key, required this.onCreate});
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

class EmptyCategoryList extends StatelessWidget {
  const EmptyCategoryList({super.key, required this.onCreate});
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
          child: Icon(Icons.grid_view_outlined,
              color: DjassaTheme.accentOrange, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Aucun rayon', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          "Créez votre première catégorie avant d'ajouter des articles.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer un rayon')),
      ]),
    );
  }
}