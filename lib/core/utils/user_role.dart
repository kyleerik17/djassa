import '../../domain/entities/user.dart';
import 'constants.dart';

/// Rôles alignés sur `profiles.role` (Supabase).
abstract final class UserRole {
  static const client = 'client';
  static const courier = 'courier';
  static const vendor = 'vendor';
  static const admin = 'admin';

  static const all = [client, courier, vendor, admin];

  static String label(String role) => switch (role) {
        courier => 'Livreur',
        vendor => 'Vendeur',
        admin => 'Administrateur',
        _ => 'Client',
      };

  /// Route d'accueil après connexion / inscription.
  static String homeRoute(User user) {
    if (user.isCourier) return AppConstants.courierRoute;
    if (user.isVendor) return AppConstants.vendorRoute;
    return AppConstants.homeRoute;
  }

  /// Routes réservées à l'e-commerce client (interdites aux vendeurs).
  static bool isClientShopPath(String path) {
    if (path.startsWith('/payment/')) return true;
    if (path.startsWith('/product/')) return true;
    const exact = {
      AppConstants.homeRoute,
      AppConstants.categoriesRoute,
      AppConstants.cartRoute,
      AppConstants.favoritesRoute,
      AppConstants.profileRoute,
      AppConstants.editProfileRoute,
      AppConstants.ordersRoute,
      AppConstants.checkoutRoute,
      AppConstants.searchRoute,
      AppConstants.notificationsRoute,
      AppConstants.supportRoute,
    };
    return exact.contains(path);
  }

  static bool isVendorPath(String path) {
    return path == AppConstants.vendorRoute ||
        path == AppConstants.vendorAccountRoute;
  }
}

/// Colonnes d'identité uniquement (pas les champs livreur).
const String kProfileIdentitySelect =
    'id, name, surname, phone, email, avatar_url, is_verified, role, created_at';
