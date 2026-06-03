import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/djassa_theme.dart';
import '../../../../data/sources/remote/admin_service.dart';
import '../../shop/shop_data.dart';
import 'shared_widgets.dart';

class AdminProductCard extends StatelessWidget {
  const AdminProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminProduct product;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: product.isActive
                ? DjassaTheme.borderMedium
                : Colors.red.withValues(alpha: .25)),
        boxShadow: DjassaTheme.shadowLight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: DjassaTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(20)),
            child: Icon(_iconFromName(product.iconName),
                color: DjassaTheme.primaryBlack, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 6, children: [
                  ChipWidget(
                      label: product.categoryName,
                      color: DjassaTheme.primaryBlack),
                  ChipWidget(
                      label: product.isActive ? 'En ligne' : 'Archivé',
                      color: product.isActive
                          ? DjassaTheme.accentGreen
                          : Colors.red),
                  if (product.badge.trim().isNotEmpty)
                    ChipWidget(
                        label: product.badge, color: DjassaTheme.accentOrange),
                ]),
                const SizedBox(height: 8),
                Text(product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                    product.compatibility.isEmpty
                        ? 'Compatibilité non renseignée'
                        : product.compatibility,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 9),
                Wrap(spacing: 12, runSpacing: 6, children: [
                  Text(formatPrice(product.price),
                      style: const TextStyle(
                          color: DjassaTheme.accentOrange,
                          fontWeight: FontWeight.w900)),
                  Text('${product.stock} en stock'),
                  Text('★ ${product.rating.toStringAsFixed(1)}'),
                ]),
                if (product.creatorName != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: DjassaTheme.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              DjassaTheme.accentOrange.withValues(alpha: 0.15),
                          backgroundImage: (product.creatorAvatarUrl != null &&
                                  product.creatorAvatarUrl!.isNotEmpty)
                              ? NetworkImage(product.creatorAvatarUrl!)
                              : null,
                          child: (product.creatorAvatarUrl == null ||
                                  product.creatorAvatarUrl!.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 14, color: DjassaTheme.accentOrange)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Par ${product.creatorName}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;
                case 'toggle':
                  onToggleActive();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(
                  value: 'toggle',
                  child:
                      Text(product.isActive ? 'Archiver' : 'Mettre en ligne')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 240.ms).slideX(begin: .03, end: 0);
  }

  IconData _iconFromName(String value) {
    switch (value) {
      case 'settings':
      case 'moteur':
        return Icons.settings;
      case 'brake':
        return Icons.motion_photos_pause;
      case 'car_repair':
        return Icons.car_repair;
      case 'electric_bolt':
      case 'battery':
        return Icons.electric_bolt;
      case 'oil':
        return Icons.opacity;
      case 'suspension':
        return Icons.vertical_align_center;
      case 'light':
        return Icons.light_mode;
      case 'tire':
        return Icons.trip_origin;
      default:
        return Icons.directions_car;
    }
  }
}