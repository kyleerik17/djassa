/// Constantes de l'application Djassa.
class AppConstants {
  // API
  static const String baseUrl = 'https://wtfygkiuzjmndnirtevy.supabase.co';
  static const String apiVersion = '/v1';

  // Routes
  static const String splashRoute = '/';
  static const String onboardingRoute = '/onboarding';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String categoriesRoute = '/categories';
  static const String categoryDetailRoute = '/category/:name';
  static const String searchRoute = '/search';
  static const String cartRoute = '/cart';
  static const String favoritesRoute = '/favorites';
  static const String profileRoute = '/profile';
  static const String editProfileRoute = '/profile/edit';
  static const String ordersRoute = '/orders';
  static const String productDetailRoute = '/product/:id';
  static const String checkoutRoute = '/checkout';
  static const String paymentRoute = '/payment/:orderId';
  static const String notificationsRoute = '/notifications';
  static const String supportRoute = '/support';
  static const String adminRoute = '/admin';
  static const String courierRoute = '/courier';
  static const String vendorRoute = '/vendor';
  static const String vendorAccountRoute = '/vendor/account';
  static const String orderChatRoute = '/order-chat/:orderId';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String vendorOrderDetailsRoute = '/vendor/order-details/:orderId';

  // Assets
  static const String logoAsset = 'assets/icons/djassa_logo.png';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String cartKey = 'cart_items';
  static const String favoritesKey = 'favorites';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String notificationsEnabledKey = 'notifications_enabled';

  // Timeouts
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Messages d'erreur
  static const String errorNetwork =
      'Problème de connexion. Vérifiez votre réseau.';
  static const String errorServer =
      'Erreur serveur. Veuillez réessayer plus tard.';
  static const String errorUnauthorized =
      'Session expirée. Veuillez vous reconnecter.';
  static const String errorNotFound = 'Élément non trouvé.';
  static const String errorGeneric =
      'Une erreur est survenue. Veuillez réessayer.';

  // Messages de succès
  static const String successAddedToCart = 'Ajouté au panier avec succès';
  static const String successAddedToFavorites = 'Ajouté aux favoris';
  static const String successOrderPlaced = 'Commande passée avec succès';
  static const String successProfileUpdated = 'Profil mis à jour';

  static String categoryLocation(String name) {
    return '/category/${Uri.encodeComponent(name)}';
  }

  static String productLocation(String id) {
    return '/product/${Uri.encodeComponent(id)}';
  }

  static String vendorOrdersLocation() {
    return '$vendorRoute?tab=orders';
  }

  static String vendorOrderDetailsLocation(String orderId) {
    return '/vendor/order-details/${Uri.encodeComponent(orderId)}';
  }

  static String paymentLocation(
    String orderId, {
    int? amount,
    String? orderNumber,
  }) {
    final uri = Uri(
      path: '/payment/${Uri.encodeComponent(orderId)}',
      queryParameters: {
        if (amount != null) 'amount': '$amount',
        if (orderNumber != null && orderNumber.trim().isNotEmpty)
          'number': orderNumber.trim(),
      },
    );
    return uri.toString();
  }

  static String searchLocation({String? query, String? category}) {
    final params = <String, String>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
    };
    final uri = Uri(path: searchRoute, queryParameters: params);
    return uri.toString();
  }

  static String orderChatLocation(String orderId, {String? orderNumber}) {
    final uri = Uri(
      path: '/order-chat/${Uri.encodeComponent(orderId)}',
      queryParameters: orderNumber == null || orderNumber.isEmpty
          ? null
          : {'number': orderNumber},
    );
    return uri.toString();
  }
}
