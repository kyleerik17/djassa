/// Constantes de l'application Djassa
class AppConstants {
  // API
  static const String baseUrl = 'https://api.djassa.sn';
  static const String apiVersion = '/v1';
  
  // Routes
  static const String splashRoute = '/';
  static const String onboardingRoute = '/onboarding';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String categoriesRoute = '/categories';
  static const String searchRoute = '/search';
  static const String cartRoute = '/cart';
  static const String favoritesRoute = '/favorites';
  static const String profileRoute = '/profile';
  static const String ordersRoute = '/orders';
  static const String productDetailRoute = '/product/:id';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String cartKey = 'cart_items';
  static const String favoritesKey = 'favorites';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String notificationsEnabledKey = 'notifications_enabled';
  
  // Timeouts
  static const int connectionTimeout = 30000; // 30 secondes
  static const int receiveTimeout = 30000; // 30 secondes
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Categories
  static const List<String> mainCategories = [
    'Moteur',
    'Carrosserie',
    'Freins',
    'Suspension',
    'Électricité',
    'Pneus',
    'Accessoires',
  ];
  
  // Messages d'erreur
  static const String errorNetwork = 'Problème de connexion. Vérifiez votre réseau.';
  static const String errorServer = 'Erreur serveur. Veuillez réessayer plus tard.';
  static const String errorUnauthorized = 'Session expirée. Veuillez vous reconnecter.';
  static const String errorNotFound = 'Élément non trouvé.';
  static const String errorGeneric = 'Une erreur est survenue. Veuillez réessayer.';
  
  // Messages de succès
  static const String successAddedToCart = 'Ajouté au panier avec succès';
  static const String successAddedToFavorites = 'Ajouté aux favoris';
  static const String successOrderPlaced = 'Commande passée avec succès';
  static const String successProfileUpdated = 'Profil mis à jour';
}
