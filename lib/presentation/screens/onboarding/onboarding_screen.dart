import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../providers/core_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _isAnimating = false;

  // Données optimisées avec des couleurs cohérentes avec la marque
  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      // Image générique e-commerce propre
      imageUrl:
          'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&q=80',
      badge: 'Catalogue Illimité',
      title: 'Tout ce dont vous avez besoin',
      subtitle:
          'Mode, high-tech, maison... Explorez des milliers de produits vérifiés et sélectionnés pour vous.',
      icon: Icons.shopping_bag_rounded,
      accentColor: DjassaTheme.accentOrange,
    ),
    _OnboardingPageData(
      // Image livraison/professionnel
      imageUrl:
          'https://images.unsplash.com/photo-1556740758-90de374c12ad?w=800&q=80',
      badge: 'Simplicité Absolue',
      title: 'Commandez en un clin d\'œil',
      subtitle:
          'Vos adresses et paiements sont sauvegardés. Plus jamais de formulaires interminables à remplir.',
      icon: Icons.flash_on_rounded,
      accentColor: Colors.blueAccent,
    ),
    _OnboardingPageData(
      // Image qualité/colis
      imageUrl:
          'https://images.unsplash.com/photo-1580674285054-bed31e145f59?w=800&q=80',
      badge: 'Qualité Garantie',
      title: 'Emballé avec soin',
      subtitle:
          'Chaque commande passe par un contrôle rigoureux avant d\'être confiée à nos livreurs partenaires.',
      icon: Icons.verified_user_rounded,
      accentColor: Colors.green,
    ),
    _OnboardingPageData(
      // Image tracking/map
      imageUrl:
          'https://images.unsplash.com/photo-1566576912321-d58ddd7a6088?w=800&q=80',
      badge: 'Suivi en Temps Réel',
      title: 'Votre colis, sous vos yeux',
      subtitle:
          'Suivez votre livreur sur la carte en direct. Recevez des notifications à chaque étape clé.',
      icon: Icons.location_on_rounded,
      accentColor: Colors.deepPurple,
    ),
  ];

  Future<void> _finish() async {
    if (_isAnimating) return;
    _isAnimating = true;

    try {
      await ref.read(sharedPreferencesProvider).setBool(
            AppConstants.onboardingCompleteKey,
            true,
          );
      if (mounted) context.go(AppConstants.loginRoute);
    } catch (e) {
      _isAnimating = false;
    }
  }

  void _nextPage() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: DjassaMotion.normal,
        curve: DjassaMotion.emphasized,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo + Tagline
                  Row(
                    children: [
                      Image.asset(
                        AppConstants.logoAsset,
                        width: 100,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bienvenue',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: DjassaMotion.slow),

                  // Bouton Passer
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      'Passer',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: DjassaMotion.slow, delay: 120.ms),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- CONTENU PRINCIPAL (PAGEVIEW) ---
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  return _OnboardingPage(
                    data: _pages[index],
                    isActive: _index == index,
                  );
                },
              ),
            ),

            // --- FOOTER CONTROLS ---
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Indicateurs (Dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: DjassaMotion.fast,
                        curve: DjassaMotion.emphasized,
                        width: _index == i ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _index == i
                              ? DjassaTheme.accentOrange
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bouton d'action principal
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: DjassaTheme.primaryBlack,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: DjassaTheme.accentOrange.withOpacity(0.3),
                      ),
                      onPressed: _nextPage,
                      icon: Icon(
                        isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 20,
                      ),
                      label: Text(
                        isLast ? 'Commencer l\'aventure' : 'Continuer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 180.ms, duration: DjassaMotion.normal)
                      .scale(
                        begin: const Offset(.96, .96),
                        delay: 180.ms,
                        duration: DjassaMotion.normal,
                        curve: DjassaMotion.emphasized,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.isActive});

  final _OnboardingPageData data;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // --- CARD VISUELLE ---
          Container(
            width: double.infinity,
            height: 320, // Hauteur fixe pour la stabilité
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: data.accentColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image de fond
                  Image.network(
                    data.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey.shade100,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: data.accentColor,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: Icon(data.icon,
                          size: 80, color: Colors.grey.shade400),
                    ),
                  ),

                  // Overlay Dégradé pour lisibilité
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),

                  // Contenu flottant (Badge + Icon)
                  Positioned(
                    top: 24,
                    left: 24,
                    right: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge Glassmorphism
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            data.badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        // Icone principale dans un cercle
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(data.icon,
                              color: data.accentColor, size: 28),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate(target: isActive ? 1 : 0)
              .fadeIn(duration: DjassaMotion.slow)
              .slideX(
                begin: 0.12,
                end: 0,
                duration: DjassaMotion.slow,
                curve: DjassaMotion.emphasized,
              ),

          const SizedBox(height: 32),

          // --- TEXTE DESCRIPTIF ---
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: DjassaTheme.primaryBlack,
                  height: 1.2,
                ),
          )
              .animate(target: isActive ? 1 : 0)
              .fadeIn(delay: 120.ms, duration: DjassaMotion.normal)
              .slideY(
                begin: 0.12,
                end: 0,
                duration: DjassaMotion.normal,
                curve: DjassaMotion.emphasized,
              ),

          const SizedBox(height: 16),

          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.5,
                  fontSize: 16,
                ),
          )
              .animate(target: isActive ? 1 : 0)
              .fadeIn(delay: 180.ms, duration: DjassaMotion.normal)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: DjassaMotion.normal,
                curve: DjassaMotion.emphasized,
              ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.imageUrl,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String imageUrl;
  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
}
