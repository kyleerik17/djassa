import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/user_role.dart';
import '../../../presentation/providers/auth_provider.dart';

/// Splash aligné sur DjassaTheme : noir premium, orange accent, transition vers le fond clair.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _exitController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _exitFade;
  late final Animation<Color?> _bgLighten;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _runSequence();
  }

  void _initAnimations() {
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _ringScale = Tween<double>(begin: 0.85, end: 1.08).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _ringOpacity = Tween<double>(begin: 0.0, end: 0.35).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
      ),
    );

    _exitFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );
    _bgLighten = ColorTween(
      begin: DjassaTheme.backgroundDark,
      end: DjassaTheme.backgroundSecondary,
    ).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    _introController.forward();

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    _exitController.forward();
    await Future.delayed(const Duration(milliseconds: 480));
    if (!mounted) return;

    await _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone =
        prefs.getBool(AppConstants.onboardingCompleteKey) ?? false;
    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);

    if (authState.isAuthenticated) {
      final user = authState.user;
      context.go(
        user != null ? UserRole.homeRoute(user) : AppConstants.homeRoute,
      );
    } else if (!onboardingDone) {
      context.go(AppConstants.onboardingRoute);
    } else {
      context.go(AppConstants.loginRoute);
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _exitController.isAnimating &&
                _exitController.value > 0.4
            ? Brightness.dark
            : Brightness.light,
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _exitController]),
      builder: (context, child) {
        final exiting = _exitController.value > 0;
        final bgColor = exiting
            ? _bgLighten.value ?? DjassaTheme.backgroundDark
            : DjassaTheme.backgroundDark;

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (!exiting)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.1,
                      colors: [
                        DjassaTheme.secondaryBlack,
                        DjassaTheme.backgroundDark,
                      ],
                    ),
                  ),
                ),
              FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0).animate(_exitFade),
                child: child,
              ),
              if (exiting)
                FadeTransition(
                  opacity: _exitFade,
                  child: ColoredBox(color: DjassaTheme.backgroundSecondary),
                ),
            ],
          ),
        );
      },
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            AnimatedBuilder(
              animation: _introController,
              builder: (context, _) => Transform.scale(
                scale: _logoScale.value,
                child: Opacity(
                  opacity: _logoOpacity.value,
                  child: SizedBox(
                    width: 180,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: _ringScale.value,
                          child: Opacity(
                            opacity: _ringOpacity.value,
                            child: Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: DjassaTheme.accentOrange
                                      .withValues(alpha: 0.45),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 164,
                          height: 72,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: DjassaTheme.primaryWhite,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: DjassaTheme.shadowMedium,
                          ),
                          child: Image.asset(
                            AppConstants.logoAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Column(
                  children: [
                    Text(
                      'Votre marché, livré',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DjassaTheme.primaryWhite
                                .withValues(alpha: 0.72),
                            letterSpacing: 1.2,
                            fontFamily: 'Cabin',
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 4),
            FadeTransition(
              opacity: _textOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(64, 0, 64, 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor:
                        DjassaTheme.primaryWhite.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      DjassaTheme.accentOrange,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
