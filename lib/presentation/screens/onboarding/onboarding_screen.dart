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

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.shopping_bag_rounded,
      badge: '1 min pour d?marrer',
      title: 'Commandez la bonne pi?ce sans stress',
      subtitle:
          'Recherchez, comparez et ajoutez vos articles auto au panier avec un parcours clair.',
      color: DjassaTheme.accentOrange,
      highlights: ['Catalogue fiable', 'Prix visible', 'Panier rapide'],
    ),
    _OnboardingPageData(
      icon: Icons.location_on_rounded,
      badge: 'Adresse r?utilisable',
      title: 'D?finissez votre point de livraison',
      subtitle:
          'Choisissez la ville et la commune, puis Djassa garde votre adresse pour les prochaines commandes.',
      color: Colors.green,
      highlights: ['Ville', 'Commune', 'GPS client'],
    ),
    _OnboardingPageData(
      icon: Icons.inventory_2_rounded,
      badge: 'Apr?s paiement',
      title: 'Vos articles sont pr?par?s puis remis au livreur',
      subtitle:
          'L??quipe v?rifie la commande, rassemble les pi?ces, emballe le colis et le confie au livreur.',
      color: Colors.deepPurple,
      highlights: ['V?rification', 'Pr?paration', 'Remise colis'],
    ),
    _OnboardingPageData(
      icon: Icons.map_rounded,
      badge: 'Suivi temps r?el',
      title: 'Suivez la livraison sur une vraie carte',
      subtitle:
          'Votre GPS et celui du livreur se synchronisent sur OpenStreetMap pendant la livraison.',
      color: Colors.blue,
      highlights: ['OpenStreetMap', 'GPS live', 'Livreur + client'],
    ),
  ];

  Future<void> _finish() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(AppConstants.onboardingCompleteKey, true);
    if (mounted) context.go(AppConstants.loginRoute);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Djassa',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontFamily: 'Hemi Head',
                                  color: DjassaTheme.primaryBlack,
                                ),
                      ),
                      Text(
                        'Votre assistant livraison auto',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DjassaTheme.primaryBlack
                                  .withValues(alpha: .55),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Passer'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    return _OnboardingPage(data: _pages[index]);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: _index == i ? 30 : 9,
                    height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _index == i
                          ? DjassaTheme.accentOrange
                          : DjassaTheme.borderMedium,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: DjassaTheme.primaryBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    if (isLast) {
                      _finish();
                      return;
                    }
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  icon: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  ),
                  label: Text(isLast ? 'Commencer Djassa' : 'Continuer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DjassaTheme.primaryBlack,
              borderRadius: BorderRadius.circular(34),
              boxShadow: DjassaTheme.shadowHeavy,
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -34,
                  bottom: -24,
                  child: Icon(
                    data.icon,
                    size: 190,
                    color: DjassaTheme.primaryWhite.withValues(alpha: .06),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: data.color.withValues(alpha: .28)),
                    ),
                    child: Text(
                      data.badge,
                      style: TextStyle(
                        color: data.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 172,
                    height: 172,
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(data.icon, size: 88, color: data.color),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(
                        duration: 1800.ms,
                        color: DjassaTheme.primaryWhite.withValues(alpha: .18),
                      )
                      .scale(
                        begin: const Offset(.96, .96),
                        end: const Offset(1.02, 1.02),
                        duration: 1100.ms,
                      ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: data.highlights
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: DjassaTheme.primaryWhite
                                  .withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: DjassaTheme.primaryWhite
                                    .withValues(alpha: .12),
                              ),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: DjassaTheme.primaryWhite,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: DjassaTheme.primaryBlack,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: .08, end: 0),
        const SizedBox(height: 12),
        Text(
          data.subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: DjassaTheme.primaryBlack.withValues(alpha: .62),
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.highlights,
  });

  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;
  final Color color;
  final List<String> highlights;
}
