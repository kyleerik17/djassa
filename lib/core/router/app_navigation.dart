import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/constants.dart';

class AppNavigation {
  const AppNavigation._();

  static const splash = AppConstants.splashRoute;
  static const onboarding = AppConstants.onboardingRoute;
  static const login = AppConstants.loginRoute;
  static const register = AppConstants.registerRoute;
  static const forgotPassword = AppConstants.forgotPasswordRoute;
  static const home = AppConstants.homeRoute;
  static const categories = AppConstants.categoriesRoute;
  static const search = AppConstants.searchRoute;
  static const cart = AppConstants.cartRoute;
  static const favorites = AppConstants.favoritesRoute;
  static const profile = AppConstants.profileRoute;
  static const editProfile = AppConstants.editProfileRoute;
  static const orders = AppConstants.ordersRoute;
  static const checkout = AppConstants.checkoutRoute;
  static const notifications = AppConstants.notificationsRoute;
  static const support = AppConstants.supportRoute;
  static const admin = AppConstants.adminRoute;
  static const courier = AppConstants.courierRoute;
  static const vendor = AppConstants.vendorRoute;
  static const vendorAccount = AppConstants.vendorAccountRoute;

  static String category(String name) => AppConstants.categoryLocation(name);
  static String product(String id) => AppConstants.productLocation(id);
  static String searchFor({String? query, String? category}) =>
      AppConstants.searchLocation(query: query, category: category);
  static String orderChat(String orderId, {String? orderNumber}) =>
      AppConstants.orderChatLocation(orderId, orderNumber: orderNumber);
  static String payment(String orderId, {int? amount, String? orderNumber}) =>
      AppConstants.paymentLocation(
        orderId,
        amount: amount,
        orderNumber: orderNumber,
      );
  static String vendorOrders() => AppConstants.vendorOrdersLocation();
  static String vendorOrderDetails(String orderId) =>
      AppConstants.vendorOrderDetailsLocation(orderId);
}

extension AppNavigationContext on BuildContext {
  void backOr(String fallbackRoute) {
    if (canPop()) {
      pop();
      return;
    }
    go(fallbackRoute);
  }

  void backOrHome() => backOr(AppNavigation.home);

  void toLogin() => go(AppNavigation.login);
  void toRegister() => go(AppNavigation.register);
  void toForgotPassword() => push(AppNavigation.forgotPassword);
  void toHome() => go(AppNavigation.home);
  void toSearch({String? query, String? category, bool replace = false}) {
    final location = AppNavigation.searchFor(query: query, category: category);
    replace ? this.replace(location) : push(location);
  }

  void toCategories() => push(AppNavigation.categories);
  void toProduct(String id) => push(AppNavigation.product(id));
  void toCart({bool replaceStack = false}) =>
      replaceStack ? go(AppNavigation.cart) : push(AppNavigation.cart);
  void toFavorites() => push(AppNavigation.favorites);
  void toProfile() => push(AppNavigation.profile);
  void toEditProfile() => push(AppNavigation.editProfile);
  void toOrders({bool replaceStack = false}) =>
      replaceStack ? go(AppNavigation.orders) : push(AppNavigation.orders);
  void toSupport() => push(AppNavigation.support);
  void toNotifications() => go(AppNavigation.notifications);
  void toVendor() => go(AppNavigation.vendor);
  void toVendorOrders() => go(AppNavigation.vendorOrders());
  void toVendorAccount() => go(AppNavigation.vendorAccount);
  void toCourier() => go(AppNavigation.courier);
  void toAdmin() => push(AppNavigation.admin);
  void toOrderChat(String orderId, {String? orderNumber}) {
    go(AppNavigation.orderChat(orderId, orderNumber: orderNumber));
  }

  void toVendorOrderDetails(String orderId) {
    go(AppNavigation.vendorOrderDetails(orderId));
  }
}
