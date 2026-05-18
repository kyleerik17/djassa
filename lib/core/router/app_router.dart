import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../utils/constants.dart';

/// Configuration du routeur GoRouter pour l'application Djassa
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppConstants.splashRoute,
    debugLogDiagnostics: true,
    routes: [
      // Route de splash
      GoRoute(
        path: AppConstants.splashRoute,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Routes d'authentification
      GoRoute(
        path: AppConstants.loginRoute,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppConstants.registerRoute,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // Route principale - Home
      GoRoute(
        path: AppConstants.homeRoute,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // Catégories
      GoRoute(
        path: AppConstants.categoriesRoute,
        name: 'categories',
        builder: (context, state) => _buildPlaceholder('Catégories'),
      ),
      
      // Recherche
      GoRoute(
        path: AppConstants.searchRoute,
        name: 'search',
        builder: (context, state) => _buildPlaceholder('Recherche'),
      ),
      
      // Panier
      GoRoute(
        path: AppConstants.cartRoute,
        name: 'cart',
        builder: (context, state) => _buildPlaceholder('Panier'),
      ),
      
      // Favoris
      GoRoute(
        path: AppConstants.favoritesRoute,
        name: 'favorites',
        builder: (context, state) => _buildPlaceholder('Favoris'),
      ),
      
      // Profil
      GoRoute(
        path: AppConstants.profileRoute,
        name: 'profile',
        builder: (context, state) => _buildPlaceholder('Profil'),
      ),
      
      // Commandes
      GoRoute(
        path: AppConstants.ordersRoute,
        name: 'orders',
        builder: (context, state) => _buildPlaceholder('Commandes'),
      ),
      
      // Détail produit (avec paramètre)
      GoRoute(
        path: AppConstants.productDetailRoute,
        name: 'product-detail',
        builder: (context, state) {
          final productId = state.pathParameters['id'];
          return _buildPlaceholder('Détail Produit: $productId');
        },
      ),
    ],
    
    // Gestion des erreurs de route
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page non trouvée',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Le chemin ${state.uri.path} n\'existe pas',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ),
    
    // Observateur de navigation pour le débogage
    observers: [
      NavigatorObserver(
        didPush: (route, previousRoute) {
          debugPrint('🔵 Navigation PUSH: ${route.settings.name}');
        },
        didPop: (route, previousRoute) {
          debugPrint('🔴 Navigation POP: ${route.settings.name}');
        },
        didReplace: (newRoute, oldRoute) {
          debugPrint('🟡 Navigation REPLACE: ${newRoute.settings.name}');
        },
      ),
    ],
  );
  
  /// Widget placeholder temporaire
  static Widget _buildPlaceholder(String title) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'En construction...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
