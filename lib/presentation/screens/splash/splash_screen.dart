import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';

/// Écran de splash premium pour Djassa
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  bool _showFirstImage = false;
  bool _showSecondImage = false;
  bool _isBlackBackground = false;
  bool _showText = false;
  double _imageWidth = 40;
  double _imageHeight = 40;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Premier délai avant d'afficher le premier logo
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    setState(() => _showFirstImage = true);

    // Animation d'agrandissement
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    
    setState(() {
      _imageWidth = 200;
      _imageHeight = 60;
    });

    // Transition vers fond noir
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    
    setState(() => _isBlackBackground = true);

    // Transition vers deuxième logo
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    
    setState(() {
      _showFirstImage = false;
      _showSecondImage = true;
    });

    // Affichage du texte
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    
    setState(() => _showText = true);

    // Navigation vers onboarding ou home
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    // Vérifier si l'utilisateur est connecté via le provider d'authentification
    // Pour l'instant, on navigue vers login car pas encore authentifié
    context.go(AppConstants.loginRoute);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        color: _isBlackBackground ? DjassaTheme.backgroundDark : DjassaTheme.backgroundPrimary,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_showFirstImage)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      width: _imageWidth,
                      height: _imageHeight,
                      child: Image.asset(
                        'assets/icons/lgo.png',
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shopping_cart,
                          size: 60,
                          color: DjassaTheme.primaryBlack,
                        ),
                      ),
                    )
                      .animate(onPlay: (controller) => controller.repeat())
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0)),
                  
                  if (_showSecondImage)
                    Opacity(
                      opacity: _showSecondImage ? 1.0 : 0.0,
                      child: Image.asset(
                        'assets/icons/home.png',
                        height: 60,
                        width: 200,
                        errorBuilder: (_, __, ___) => const Text(
                          'DJASSA',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Hemi Head',
                            color: DjassaTheme.accentOrange,
                          ),
                        ),
                      ),
                    )
                      .animate()
                      .fadeIn(duration: 800.ms),
                ],
              ),
              
              if (_showText)
                Text(
                  'Djassa',
                  style: TextStyle(
                    color: _isBlackBackground ? DjassaTheme.primaryWhite : DjassaTheme.textPrimary,
                    fontWeight: FontWeight.w400,
                    fontSize: 50,
                    fontFamily: "Hemi Head",
                    letterSpacing: 0.05,
                  ),
                )
                  .animate(onPlay: (controller) => controller.forward())
                  .moveX(
                    begin: 200,
                    end: 0,
                    curve: Curves.easeOut,
                    duration: 800.ms,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    super.dispose();
  }
}
