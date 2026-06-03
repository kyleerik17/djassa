import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/admin/pages/admin_products_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/delivery/courier_orders_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/shop/cart_screen.dart';
import '../../presentation/screens/shop/categories_screen.dart';
import '../../presentation/screens/shop/checkout_screen.dart';
import '../../presentation/screens/shop/edit_profile_screen.dart';
import '../../presentation/screens/shop/favorites_screen.dart';
import '../../presentation/screens/shop/notifications_screen.dart';
import '../../presentation/screens/shop/order_chat_screen.dart';
import '../../presentation/screens/shop/orders_screen.dart';
import '../../presentation/screens/shop/payment_screen.dart';
import '../../presentation/screens/shop/product_detail_screen.dart';
import '../../presentation/screens/shop/profile_screen.dart';
import '../../presentation/screens/shop/search_screen.dart';
import '../../presentation/screens/shop/support_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/vendor/vendor_account_screen.dart';
import '../../presentation/screens/vendor/vendor_space_screen.dart';
import '../theme/djassa_theme.dart';
import '../utils/constants.dart';
import '../utils/user_role.dart';

class NavigationLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    debugPrint('Navigation PUSH: ${route.settings.name ?? route}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    debugPrint('Navigation POP: ${route.settings.name ?? route}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    debugPrint('Navigation REPLACE: ${newRoute?.settings.name ?? newRoute}');
  }
}

class AppRouter {
  static final NavigationLogger _navigationLogger = NavigationLogger();

  static GoRouter createRouter({
    required Ref ref,
    required Listenable refreshListenable,
  }) {
    return GoRouter(
      initialLocation: AppConstants.splashRoute,
      debugLogDiagnostics: true,
      refreshListenable: refreshListenable,
      redirect: (context, state) {
        final user = ref.read(authNotifierProvider).user;
        final path = state.uri.path;

        if (user?.isVendor == true) {
          if (UserRole.isClientShopPath(path)) {
            if (path == AppConstants.profileRoute ||
                path == AppConstants.editProfileRoute) {
              return AppConstants.vendorAccountRoute;
            }
            return AppConstants.vendorRoute;
          }
        }

        if (user != null && !user.isVendor && UserRole.isVendorPath(path)) {
          return UserRole.homeRoute(user);
        }

        if (user?.isCourier == true && UserRole.isVendorPath(path)) {
          return AppConstants.courierRoute;
        }

        return null;
      },
      routes: [
        _route(
          path: AppConstants.splashRoute,
          name: 'splash',
          child: const SplashScreen(),
        ),
        _route(
          path: AppConstants.loginRoute,
          name: 'login',
          child: const LoginScreen(),
        ),
        _route(
          path: AppConstants.onboardingRoute,
          name: 'onboarding',
          child: const OnboardingScreen(),
        ),
        _route(
          path: AppConstants.registerRoute,
          name: 'register',
          child: const RegisterScreen(),
        ),
        _route(
          path: AppConstants.homeRoute,
          name: 'home',
          child: const HomeScreen(),
        ),
        _route(
          path: AppConstants.categoriesRoute,
          name: 'categories',
          child: const CategoriesScreen(),
        ),
        GoRoute(
          path: AppConstants.searchRoute,
          name: 'search',
          pageBuilder: (context, state) => _page(
            state,
            SearchScreen(
              initialQuery: state.uri.queryParameters['q'],
              category: state.uri.queryParameters['category'],
            ),
          ),
        ),
        _route(
          path: AppConstants.cartRoute,
          name: 'cart',
          child: const CartScreen(),
        ),
        _route(
          path: AppConstants.favoritesRoute,
          name: 'favorites',
          child: const FavoritesScreen(),
        ),
        _route(
          path: AppConstants.profileRoute,
          name: 'profile',
          child: const ProfileScreen(),
        ),
        _route(
          path: AppConstants.editProfileRoute,
          name: 'edit-profile',
          child: const EditProfileScreen(),
        ),
        _route(
          path: AppConstants.ordersRoute,
          name: 'orders',
          child: const OrdersScreen(),
        ),
        GoRoute(
          path: AppConstants.orderChatRoute,
          name: 'order-chat',
          pageBuilder: (context, state) => _page(
            state,
            OrderChatScreen(
              orderId: state.pathParameters['orderId'] ?? '',
              orderNumber: state.uri.queryParameters['number'],
            ),
          ),
        ),
        GoRoute(
          path: AppConstants.productDetailRoute,
          name: 'product-detail',
          pageBuilder: (context, state) => _page(
            state,
            ProductDetailScreen(productId: state.pathParameters['id']),
          ),
        ),
        _route(
          path: AppConstants.checkoutRoute,
          name: 'checkout',
          child: const CheckoutScreen(),
        ),
        GoRoute(
          path: AppConstants.paymentRoute,
          name: 'payment',
          pageBuilder: (context, state) => _page(
            state,
            PaymentScreen(
              orderId: state.pathParameters['orderId'] ?? '',
              amount:
                  int.tryParse(state.uri.queryParameters['amount'] ?? '') ?? 0,
              orderNumber: state.uri.queryParameters['number'],
            ),
          ),
        ),
        _route(
          path: AppConstants.notificationsRoute,
          name: 'notifications',
          child: const NotificationsScreen(),
        ),
        _route(
          path: AppConstants.supportRoute,
          name: 'support',
          child: const SupportScreen(),
        ),
        _route(
          path: AppConstants.adminRoute,
          name: 'admin',
          child: const AdminProductsScreen(),
        ),
        _route(
          path: AppConstants.courierRoute,
          name: 'courier',
          child: const CourierOrdersScreen(),
        ),
        GoRoute(
          path: AppConstants.vendorRoute,
          name: 'vendor',
          pageBuilder: (context, state) {
            final tab = state.uri.queryParameters['tab'];
            return _page(
              state,
              VendorSpaceScreen(tabIndex: tab == 'orders' ? 1 : 0),
            );
          },
        ),
        _route(
          path: AppConstants.vendorAccountRoute,
          name: 'vendor-account',
          child: const VendorAccountScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        backgroundColor: DjassaTheme.backgroundSecondary,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 72,
                  color: DjassaTheme.accentOrange,
                ),
                const SizedBox(height: 18),
                Text(
                  'Page non trouvée',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Le chemin ${state.uri.path} n’existe pas.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.go(AppConstants.homeRoute),
                  child: const Text('Retour accueil'),
                ),
              ],
            ),
          ),
        ),
      ),
      observers: [
        _navigationLogger,
        HeroController(),
      ],
    );
  }

  static GoRoute _route({
    required String path,
    required String name,
    required Widget child,
  }) {
    return GoRoute(
      path: path,
      name: name,
      pageBuilder: (context, state) => _page(state, child),
    );
  }

  static CustomTransitionPage<dynamic> _page(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<dynamic>(
      key: state.pageKey,
      name: state.name,
      arguments: state.extra,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.04, .02),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}
