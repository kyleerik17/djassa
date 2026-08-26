import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/constants.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/user_role.dart';
import '../../../presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _shimmerAnimation; // Effet de brillance

  bool _hasNavigated = false;

  // 🎨 PALETTE DE COULEURS DJASSA (Refonte Premium)
  static const Color _primaryRed = Color(0xFFB61D03);
  static const Color _deepRed = Color(0xFF8A1200); // Pour le dégradé
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 1800), // Un peu plus long pour l'élégance
    );

    // 1. Fade In doux
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // 2. Scale avec rebond (Elastic effect)
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.78, curve: DjassaMotion.emphasized),
      ),
    );

    // 3. Shimmer (Brillance qui passe sur le logo)
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.36, 0.9, curve: DjassaMotion.soft),
      ),
    );

    _controller.forward();
    _prepareNavigation();
  }

  Future<void> _prepareNavigation() async {
    // Temps laissé à l'utilisateur pour admirer le branding
    await Future.delayed(const Duration(milliseconds: 2200));

    if (!mounted || _hasNavigated) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone =
        prefs.getBool(AppConstants.onboardingCompleteKey) ?? false;
    final authState = ref.read(authNotifierProvider);

    String nextRoute;

    if (authState.isAuthenticated && authState.user != null) {
      nextRoute = UserRole.homeRoute(authState.user!);
    } else if (!onboardingDone) {
      nextRoute = AppConstants.onboardingRoute;
    } else {
      nextRoute = AppConstants.loginRoute;
    }

    _navigateTo(nextRoute);
  }

  Future<void> _navigateTo(String route) async {
    setState(() => _hasNavigated = true);

    // Petite animation de sortie (Fade out rapide)
    await _controller.reverse(from: 0.8);

    if (!mounted) return;
    context.go(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        // 🎨 FOND DÉGRADÉ PREMIUM
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryRed, _deepRed],
              stops: [0.3, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- LOGO AVEC EFFET SHIMMER ---
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Logo de base
                              Image.asset(
                                AppConstants.logoAsset,
                                width: 140,
                                height: 140,
                                fit: BoxFit.contain,
                                color: Colors.white,
                                colorBlendMode: BlendMode.srcIn,
                              ),

                              // Effet de brillance (Shimmer)
                              Positioned.fill(
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    widthFactor:
                                        _shimmerAnimation.value.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white
                                                .withOpacity(0.4), // Brillance
                                            Colors.white.withOpacity(0.0),
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // --- TYPOGRAPHIE ÉLÉGANTE ---
                          Text(
                            'DJASSA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight:
                                  FontWeight.w300, // Light pour l'élégance
                              letterSpacing: 6.0, // Tracking large = Luxe
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                  color: Colors.black.withOpacity(0.3),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Tagline subtile
                          Text(
                            'LIVRAISON & SERVICES',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
