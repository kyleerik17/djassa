import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../domain/order_progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/order_progress_celebration.dart';
import '../../widgets/shop/order_progress_tracker.dart';
import '../../widgets/shop/payment_ui.dart';
import '../../widgets/shop/shop_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _lastCelebratedStatus;

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
    final isAdmin = ref.watch(isAdminProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );
    final user = authState.user;

    if (user != null && !user.isClient) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasAvatar =
        user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty;
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

    return ShopScaffold(
      currentIndex: 4,
      title: 'Profil',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Carte profil ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: DjassaTheme.primaryBlack,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor:
                      DjassaTheme.accentOrange.withValues(alpha: .18),
                  backgroundImage:
                      hasAvatar ? NetworkImage(user.avatarUrl!) : null,
                  child: hasAvatar
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          color: DjassaTheme.accentOrange,
                          size: 34,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName.trim().isNotEmpty == true
                            ? user!.fullName
                            : user?.roleLabel ?? 'Client Djassa',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: DjassaTheme.primaryWhite),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.roleLabel ?? 'Client',
                        style: TextStyle(
                          color: DjassaTheme.accentOrange.withValues(alpha: .9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.phone ?? user?.email ?? 'Compte e-commerce',
                        style: TextStyle(
                          color:
                              DjassaTheme.primaryWhite.withValues(alpha: .72),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: DjassaTheme.accentOrange,
                  ),
                  onPressed: () => context.go('/profile/edit'),
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
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

          const SectionTitle(title: 'Mon espace client'),
          const SizedBox(height: 12),
          if (isAdmin)
            _ProfileAction(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Backoffice articles',
              subtitle: 'Ajouter, modifier et publier le catalogue',
              onTap: () => context.go('/admin'),
            ),
          _ProfileAction(
              icon: Icons.payments_rounded,
              title: 'Moyen de paiement',
              subtitle: savedPayment != null && savedPayment.isConfigured
                  ? '${paymentProviderLabel(savedPayment.provider)} · ${savedPayment.phone}'
                  : 'Enregistrer votre Mobile Money par défaut',
              onTap: () => _configurePaymentMethod(context),
            ),
            _ProfileAction(
              icon: Icons.receipt_long_rounded,
              title: 'Mes commandes',
              subtitle: 'Suivi, paiement des commandes en attente',
              onTap: () => context.go('/orders'),
            ),
            _ProfileAction(
              icon: Icons.location_on_outlined,
              title: 'Adresse de livraison',
              subtitle:
                  savedAddress?.label ?? 'Enregistrer le point de livraison',
              onTap: () => _showDeliveryAddressDialog(context),
            ),
            _ProfileAction(
              icon: Icons.favorite_border_rounded,
              title: 'Favoris',
              subtitle: 'Articles sauvegardés',
            onTap: () => context.go('/favorites'),
          ),
          _ProfileAction(
            icon: Icons.code_rounded,
            title: 'Dev: Ange Erik',
            subtitle: 'Portfolio et CV',
            onTap: () => _showDeveloperPreview(context),
          ),
          _ProfileAction(
            icon: Icons.support_agent_rounded,
            title: 'Assistance',
            subtitle: 'Aide pour choisir un article',
            onTap: () => context.go('/support'),
          ),
          const SizedBox(height: 16),

          // ── Bouton déconnexion ────────────────────────────────
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
              label: const Text('Déconnexion'),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  // ── Sheets ────────────────────────────────────────────────────────────────

  void _showLogoutSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => _LogoutSheet(
        onConfirm: () async {
          Navigator.of(ctx).pop();
          await ref.read(authNotifierProvider.notifier).logoutUser();
          if (context.mounted) context.go('/login');
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showDeveloperPreview(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(28),
          boxShadow: DjassaTheme.shadowHeavy,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      DjassaTheme.accentOrange.withValues(alpha: .12),
                  child: const Icon(
                    Icons.code_rounded,
                    color: DjassaTheme.accentOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ange Erik',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Portfolio et CV seront branchés ici dans la prochaine étape.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.language_rounded),
                    label: const Text('Portfolio'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('CV'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configurePaymentMethod(BuildContext context) async {
    final user = ref.read(authNotifierProvider).user;
    final saved = ref.read(savedPaymentMethodProvider);
    final result = await showMobileMoneyPaymentDialog(
      context,
      prefilledPhone: saved?.phone ?? user?.phone,
      initialProvider: saved?.provider ?? 'wave',
    );
    if (result == null || !context.mounted) return;

    await ref.read(savedPaymentMethodProvider.notifier).save(
          provider: result['provider']!,
          phone: result['phone']!,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Moyen de paiement enregistré.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeliveryAddressDialog(BuildContext context) {
    final savedAddress = ref.read(savedDeliveryAddressProvider);
    String? selectedCity = savedAddress?.city;
    String? selectedCommune = savedAddress?.commune;
    bool showError = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          final communes = selectedCity == null
              ? <String>[]
              : deliveryCitiesCommunes[selectedCity!] ?? <String>[];

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      DjassaTheme.accentOrange.withValues(alpha: .12),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: DjassaTheme.accentOrange,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Adresse de livraison')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enregistrez votre adresse pour la réutiliser directement au moment de commander.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCity,
                  decoration: InputDecoration(
                    labelText: 'Ville',
                    prefixIcon: const Icon(Icons.location_city_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: deliveryCitiesCommunes.keys
                      .map(
                        (city) => DropdownMenuItem(
                          value: city,
                          child: Text(city),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedCity = value;
                      selectedCommune = null;
                      showError = false;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: communes.contains(selectedCommune)
                      ? selectedCommune
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Commune',
                    prefixIcon: const Icon(Icons.map_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  hint: Text(
                    selectedCity == null
                        ? 'Choisir une ville d’abord'
                        : 'Sélectionner une commune',
                  ),
                  items: communes
                      .map(
                        (commune) => DropdownMenuItem(
                          value: commune,
                          child: Text(commune),
                        ),
                      )
                      .toList(),
                  onChanged: selectedCity == null
                      ? null
                      : (value) {
                          setStateDialog(() {
                            selectedCommune = value;
                            showError = false;
                          });
                        },
                ),
                if (showError) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Veuillez sélectionner une ville et une commune.',
                    style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: DjassaTheme.accentOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (selectedCity == null || selectedCommune == null) {
                    setStateDialog(() => showError = true);
                    return;
                  }
                  await ref
                      .read(savedDeliveryAddressProvider.notifier)
                      .save(selectedCity!, selectedCommune!);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Adresse de livraison enregistrée.'),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Logout Sheet ──────────────────────────────────────────────────────────────

class _LogoutSheet extends StatefulWidget {
  const _LogoutSheet({
    required this.onConfirm,
    required this.onCancel,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<_LogoutSheet> createState() => _LogoutSheetState();
}

class _LogoutSheetState extends State<_LogoutSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: DjassaTheme.primaryWhite,
            borderRadius: BorderRadius.circular(28),
            boxShadow: DjassaTheme.shadowHeavy,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: DjassaTheme.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icône
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.red.withValues(alpha: .10),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Se déconnecter ?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous devrez vous reconnecter pour\naccéder à votre compte.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DjassaTheme.primaryBlack.withValues(alpha: .55),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: widget.onCancel,
                      child: const Text('Rester connecté'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: widget.onConfirm,
                      child: const Text('Déconnexion'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile Action ────────────────────────────────────────────────────────────

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
              CircleAvatar(
                backgroundColor:
                    DjassaTheme.accentOrange.withValues(alpha: .12),
                child: Icon(icon, color: DjassaTheme.accentOrange),
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
