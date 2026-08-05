import 'package:djassa/core/theme/djassa_theme.dart';
import 'package:djassa/core/utils/constants.dart';
import 'package:djassa/domain/order_progress.dart';
import 'package:djassa/presentation/providers/auth_provider.dart';
import 'package:djassa/presentation/providers/core_providers.dart';
import 'package:djassa/presentation/screens/profile/widgets/adresse_profile.dart';
import 'package:djassa/presentation/screens/profile/widgets/app_version_footer.dart';
import 'package:djassa/presentation/screens/profile/widgets/hearder_profile.dart';
import 'package:djassa/presentation/screens/profile/widgets/helper.dart';
import 'package:djassa/presentation/screens/profile/widgets/logout_profile.dart';
import 'package:djassa/presentation/screens/profile/widgets/profile_string.dart';
import 'package:djassa/presentation/widgets/shop/order_progress_celebration.dart';
import 'package:djassa/presentation/widgets/shop/order_progress_tracker.dart';
import 'package:djassa/presentation/widgets/shop/payment_ui.dart';
import 'package:djassa/presentation/widgets/shop/shop_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _lastCelebratedStatus;

  // ✅ Évite de déclencher context.go() à chaque rebuild pendant que le
  // spinner de redirection est affiché (sinon on empile des navigations).
  bool _hasRedirectedForRole = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).refreshUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isAdminAsync = ref.watch(isAdminProvider);
    final user = authState.user;
    final isUserLoading = user == null;

    // Cet écran est réservé aux comptes CLIENT. Un coursier ou un vendeur
    // qui atterrit ici (ex: routing, deep link, ancien onglet) doit être
    // renvoyé vers son propre écran — pas rester bloqué sur un spinner
    // qui ne mène nulle part.
    if (user != null && !user.isClient) {
      if (!_hasRedirectedForRole) {
        _hasRedirectedForRole = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final targetRoute = switch (user.role) {
            'courier' => AppConstants.courierRoute,
            'vendor' => AppConstants.vendorAccountRoute,
            'admin' => AppConstants.adminRoute,
            _ => AppConstants.homeRoute, // filet de sécurité si rôle inconnu
          };
          context.go(targetRoute);
        });
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Le rôle a pu changer (ex: nouveau login client après un logout) :
    // on réarme la garde pour un futur changement de rôle.
    if (_hasRedirectedForRole) {
      _hasRedirectedForRole = false;
    }

    final savedAddress = ref.watch(savedDeliveryAddressProvider);
    final savedPayment = ref.watch(savedPaymentMethodProvider);
    final activeOrderAsync = ref.watch(activeClientOrderProvider);

    ref.listen(activeClientOrderProvider, (previous, next) {
      final order = next.valueOrNull;
      if (order == null || !mounted) return;
      final prevStatus = previous?.valueOrNull?.status;
      if (!OrderProgressInfo.isProgressForward(prevStatus, order.status)) {
        return;
      }
      if (_lastCelebratedStatus == order.status) return;
      _lastCelebratedStatus = order.status;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showOrderProgressCelebration(context, status: order.status);
      });
    });

    // Badge "paiement en attente" sur l'action commandes.
    // Statut confirmé par domain/order_progress.dart (OrderProgressInfo) :
    // 'pending_payment' est bien la valeur utilisée avant 'paid'.
    final hasPendingPayment = activeOrderAsync.valueOrNull?.status ==
        'pending_payment';

    // Pendant le chargement de isAdmin, on ne veut ni afficher ni cacher le
    // bouton à tort (ça évite le flash). On l'affiche seulement une fois la
    // valeur résolue.
    final isAdmin = isAdminAsync.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );
    final isAdminResolved = isAdminAsync.hasValue;

    return ShopScaffold(
      currentIndex: 4,
      showSellButton: false,
      title: ProfileStrings.title,
      onRefresh: () => ref.read(authNotifierProvider.notifier).refreshUser(),
      // Le badge de notification est supporté par ShopScaffold via
      // `unreadNotificationsCount`. Reste à brancher un vrai provider de
      // notifications non lues :
      // unreadNotificationsCount: ref.watch(unreadNotificationsCountProvider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileHeaderCard(
            isLoading: isUserLoading,
            fullName: user?.fullName.trim().isNotEmpty == true
                ? user!.fullName
                : (user?.roleLabel ?? ProfileStrings.defaultRoleLabel),
            roleLabel: user?.roleLabel ?? ProfileStrings.defaultRole,
            phoneOrEmail:
                user?.phone ?? user?.email ?? ProfileStrings.defaultAccount,
            avatarUrl: user?.avatarUrl,
            onEdit: () => context.push(AppConstants.editProfileRoute),
          ),
          const SizedBox(height: 22),

          if (activeOrderAsync.hasValue && activeOrderAsync.value != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: OrderProgressTracker(
                order: activeOrderAsync.value!,
                onStepCelebration: (status) {
                  if (_lastCelebratedStatus == status) return;
                  _lastCelebratedStatus = status;
                  showOrderProgressCelebration(context, status: status);
                },
              ),
            ),

          const SectionTitle(title: ProfileStrings.sectionTitle),
          const SizedBox(height: 12),
          if (isAdminResolved && isAdmin)
            _ProfileAction(
              icon: Icons.admin_panel_settings_rounded,
              title: ProfileStrings.backofficeTitle,
              subtitle: ProfileStrings.backofficeSubtitle,
              onTap: () => context.push(AppConstants.adminRoute),
            ),
          _ProfileAction(
            icon: Icons.payments_rounded,
            title: ProfileStrings.paymentTitle,
            subtitle: savedPayment != null && savedPayment.isConfigured
                ? '${paymentProviderLabel(savedPayment.provider)} · ${savedPayment.phone}'
                : ProfileStrings.paymentSubtitleEmpty,
            onTap: () => _configurePaymentMethod(context),
          ),
          _ProfileAction(
            icon: Icons.receipt_long_rounded,
            title: ProfileStrings.ordersTitle,
            subtitle: hasPendingPayment
                ? ProfileStrings.ordersSubtitlePending
                : ProfileStrings.ordersSubtitle,
            showDot: hasPendingPayment,
            onTap: () => context.push(AppConstants.ordersRoute),
          ),
          _ProfileAction(
            icon: Icons.location_on_outlined,
            title: ProfileStrings.addressTitle,
            subtitle:
                savedAddress?.label ?? ProfileStrings.addressSubtitleEmpty,
            onTap: () => _showDeliveryAddressDialog(context),
          ),
          _ProfileAction(
            icon: Icons.support_agent_rounded,
            title: ProfileStrings.supportTitle,
            subtitle: ProfileStrings.supportSubtitle,
            onTap: () => context.push(AppConstants.supportRoute),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () => _showLogoutSheet(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(ProfileStrings.logout),
            ),
          ),
          const SizedBox(height: 12),

          // Lien développeur retiré de la liste d'actions (pas pro dans le
          // profil d'un client). Il reste accessible en easter egg : un
          // appui long sur le numéro de version ci-dessous ouvre la sheet
          // portfolio/GitHub. Invisible sauf si on sait où chercher.
          const AppVersionFooter(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _showLogoutSheet(BuildContext context) {
    showLogoutSheet(
      context,
      onConfirm: () async {
        await ref.read(authNotifierProvider.notifier).logoutUser();
        // NOTE : context.go() est volontairement conservé ici. Après une
        // déconnexion on veut vider toute la pile de navigation (pas
        // empiler l'écran login par-dessus le profil), sinon un "retour"
        // depuis login ramènerait vers un profil qui n'est plus valide.
        if (context.mounted) context.go(AppConstants.loginRoute);
      },
    );
  }

  Future<void> _configurePaymentMethod(BuildContext context) async {
    // Garde explicite si la session a expiré / l'utilisateur s'est
    // déconnecté entre-temps.
    final user = ref.read(authNotifierProvider).user;
    if (user == null) {
      AppSnackbar.error(context, ProfileStrings.paymentNoSession);
      return;
    }

    final saved = ref.read(savedPaymentMethodProvider);
    final result = await showMobileMoneyPaymentDialog(
      context,
      prefilledPhone: saved?.phone ?? user.phone,
      initialProvider: saved?.provider ?? 'wave',
    );
    if (result == null || !context.mounted) return;

    await ref.read(savedPaymentMethodProvider.notifier).save(
          provider: result['provider']!,
          phone: result['phone']!,
        );

    if (context.mounted) {
      AppSnackbar.success(context, ProfileStrings.paymentSaved);
    }
  }

  void _showDeliveryAddressDialog(BuildContext context) async {
    final savedAddress = ref.read(savedDeliveryAddressProvider);
    final saved = await showDeliveryAddressDialog(
      context,
      initialCity: savedAddress?.city,
      initialCommune: savedAddress?.commune,
      onSave: (city, commune) => ref
          .read(savedDeliveryAddressProvider.notifier)
          .save(city, commune),
    );
    if (saved && context.mounted) {
      AppSnackbar.success(context, ProfileStrings.addressSaved);
    }
  }
}

// ── Profile Action ──────────────────────────────────────────────────────────

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DjassaTheme.primaryWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: DjassaTheme.borderMedium),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor:
                        DjassaTheme.accentOrange.withValues(alpha: .12),
                    child: Icon(icon, color: DjassaTheme.accentOrange),
                  ),
                  if (showDot)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DjassaTheme.primaryWhite,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}