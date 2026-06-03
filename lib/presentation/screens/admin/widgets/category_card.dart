import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/djassa_theme.dart';
import '../../../../data/sources/remote/admin_service.dart';
import 'shared_widgets.dart';

class AdminCategoryCard extends StatelessWidget {
  const AdminCategoryCard({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminCategory category;
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
          color: category.isActive
              ? DjassaTheme.borderMedium
              : Colors.red.withValues(alpha: .25),
        ),
        boxShadow: DjassaTheme.shadowLight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DjassaTheme.accentOrange.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _categoryIconFromName(category.iconName),
              color: DjassaTheme.accentOrange,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChipWidget(
                      label: category.isActive ? 'En ligne' : 'Archivé',
                      color: category.isActive
                          ? DjassaTheme.accentGreen
                          : Colors.red,
                    ),
                    ChipWidget(
                      label: 'Ordre ${category.sortOrder}',
                      color: DjassaTheme.primaryBlack,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (category.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    category.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
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
                child: Text(
                  category.isActive ? 'Archiver' : 'Mettre en ligne',
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 240.ms).slideX(begin: .03, end: 0);
  }

  IconData _categoryIconFromName(String value) {
    switch (value) {
      case 'devices':
        return Icons.devices_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'checkroom':
        return Icons.checkroom_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'sports_soccer':
        return Icons.sports_soccer_rounded;
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
      case 'category':
      default:
        return Icons.category_rounded;
    }
  }
}