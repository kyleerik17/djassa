import 'package:flutter/material.dart';

import '../../../../core/theme/djassa_theme.dart';

class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.children});
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

class NumberField extends StatelessWidget {
  const NumberField(
      {super.key,
      required this.controller,
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