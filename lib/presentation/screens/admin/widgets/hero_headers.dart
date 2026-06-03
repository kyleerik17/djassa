import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/djassa_theme.dart';

class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(30),
        boxShadow: DjassaTheme.shadowHeavy,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -32,
            child: Icon(Icons.inventory_2_rounded,
                size: 142,
                color: DjassaTheme.primaryWhite.withValues(alpha: .07)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: DjassaTheme.accentOrange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Admin catalogue',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              const SizedBox(height: 18),
              Text(
                'Ajoutez vos articles sans ouvrir Supabase',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: DjassaTheme.primaryWhite, height: 1.06),
              ),
              const SizedBox(height: 8),
              Text(
                'Prix, stock, rayon, badge promo et publication se gèrent ici.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .72)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DjassaTheme.accentOrange,
                  foregroundColor: DjassaTheme.primaryWhite,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nouvel article'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: .04, end: 0);
  }
}

class CategoryHeroHeader extends StatelessWidget {
  const CategoryHeroHeader({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(30),
        boxShadow: DjassaTheme.shadowHeavy,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -34,
            child: Icon(
              Icons.grid_view_rounded,
              size: 136,
              color: DjassaTheme.primaryWhite.withValues(alpha: .07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: DjassaTheme.accentOrange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Admin rayons',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Créez vos catégories depuis l'app",
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: DjassaTheme.primaryWhite, height: 1.06),
              ),
              const SizedBox(height: 8),
              Text(
                "Les rayons publiés s'affichent directement dans la boutique.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .72)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DjassaTheme.accentOrange,
                  foregroundColor: DjassaTheme.primaryWhite,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nouveau rayon'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: .04, end: 0);
  }
}