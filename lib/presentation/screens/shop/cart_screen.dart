import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';
import 'shop_data.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const int _delivery = 2500;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    final cart = ref.read(cartProvider.notifier);
    
    final subtotal = lines.fold<int>(
      0,
      (sum, line) => sum + line.product.price * line.quantity,
    );
    final total = subtotal + _delivery;

    return ShopScaffold(
      currentIndex: 2,
      showSellButton: false,
      title: 'Panier',
      actions: [
        TextButton(
          onPressed: () => context.go(AppConstants.searchRoute),
          child: const Text('Ajouter'),
        ),
        const SizedBox(width: 8),
      ],
      // ✅ CORRECTION WEB : SingleChildScrollView au lieu de CustomScrollView
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lines.isEmpty)
              EmptyStateCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Votre panier est vide',
                message: 'Ajoutez vos articles depuis la recherche ou les rayons.',
                buttonLabel: 'Découvrir',
                onPressed: () => context.go(AppConstants.categoriesRoute),
              )
            else ...[
              SectionTitle(title: '${lines.length} articles sélectionnés'),
              const SizedBox(height: 12),
              
              // ✅ Liste shrinkWrap pour s'intégrer dans le SingleChildScrollView
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final line = lines[index];
                  return _CartLineCard(
                    line: line,
                    onAdd: () => cart.increment(line.product.id),
                    onRemoveOne: () => cart.decrement(line.product.id),
                    onDelete: () {
                      final removedLine = line;
                      cart.remove(line.product.id);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('« ${removedLine.product.name} » retiré du panier'),
                            action: SnackBarAction(
                              label: 'Annuler',
                              onPressed: () => cart.add(
                                removedLine.product,
                                quantity: removedLine.quantity,
                              ),
                            ),
                          ),
                        );
                    },
                  );
                },
              ),
              
              const SizedBox(height: 18),
              _SummaryCard(
                subtotal: subtotal,
                delivery: _delivery,
                total: total,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: DjassaTheme.accentOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => context.go(AppConstants.checkoutRoute),
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('Valider la commande'),
                ),
              ),
            ],
            // Espace pour la barre de navigation en bas sur Web/Mobile
            const SizedBox(height: 88), 
          ],
        ),
      ),
    );
  }
}

// Le reste de vos widgets (_CartLineCard, _QtyButton, _SummaryCard, _SummaryRow) 
// restent IDENTIQUES car ils n'ont pas de problème de Flex/Expanded.
// Vous pouvez les copier-coller tels quels depuis votre fichier original.

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.onAdd,
    required this.onRemoveOne,
    required this.onDelete,
  });

  final CartLine line;
  final VoidCallback onAdd;
  final VoidCallback onRemoveOne;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
        boxShadow: DjassaTheme.shadowLight,
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: DjassaTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(line.product.icon, color: DjassaTheme.primaryBlack),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(formatPrice(line.product.price)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onPressed: line.quantity <= 1 ? null : onRemoveOne,
                    ),
                    Container(
                      width: 42,
                      alignment: Alignment.center,
                      child: Text(
                        '${line.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onPressed: line.product.stock > 0 &&
                              line.quantity >= line.product.stock
                          ? null
                          : onAdd,
                    ),
                    const Spacer(),
                    Text(
                      formatPrice(line.product.price * line.quantity),
                      style: const TextStyle(
                        color: DjassaTheme.accentOrange,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton.filledTonal(
        style: IconButton.styleFrom(
          backgroundColor: DjassaTheme.backgroundSecondary,
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.subtotal, required this.delivery, required this.total});
  final int subtotal;
  final int delivery;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Sous-total', value: formatPrice(subtotal)),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Livraison', value: formatPrice(delivery)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24),
          ),
          _SummaryRow(label: 'Total', value: formatPrice(total), emphasized: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasized = false});
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: DjassaTheme.primaryWhite,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
      fontSize: emphasized ? 18 : 14,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}