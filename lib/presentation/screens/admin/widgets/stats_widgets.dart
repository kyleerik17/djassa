import 'package:flutter/material.dart';

import '../../../../core/theme/djassa_theme.dart';
import '../../../../data/sources/remote/admin_service.dart';
import '../../shop/shop_data.dart';

class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.products});
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
          StatCard(
              label: 'Articles',
              value: '${products.length}',
              icon: Icons.inventory_2_outlined),
          StatCard(
              label: 'En ligne',
              value: '$active',
              icon: Icons.visibility_rounded),
          StatCard(
              label: 'Stock faible',
              value: '$lowStock',
              icon: Icons.warning_amber_rounded,
              color: Colors.red),
          StatCard(
              label: 'Valeur stock',
              value: formatPrice(stockValue),
              icon: Icons.payments_outlined),
        ],
      );
    });
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
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