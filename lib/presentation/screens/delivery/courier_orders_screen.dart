import 'dart:async';
import 'package:djassa/core/theme/avatar_picker.dart';
import 'package:djassa/presentation/screens/delivery/model/courier_assignment.dart';
import 'package:djassa/presentation/screens/delivery/providers/assignment_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../data/services/courier_order_service.dart';
import '../../../data/services/courier_profile_service.dart';
import '../../../data/services/delivery_tracking_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

import '../../screens/shop/shop_data.dart';
import '../../widgets/shop/delivery_tracking_widgets.dart';
import '../../widgets/shared/logout_confirmation_sheet.dart';

// ---------------------------------------------------------------------------
// Design tokens locaux
// ---------------------------------------------------------------------------

class _Radius {
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 28.0;
}

class _Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

class _Semantic {
  static const success = Color(0xFF1FA463);
  static const successBg = Color(0xFFE7F7EF);
  static const warning = Color(0xFFE89B17);
  static const warningBg = Color(0xFFFDEDE0);
  static const danger = Color(0xFFE0453C);
  static const dangerBg = Color(0xFFFCEAE9);
  static const info = Color(0xFF3E7BFA);
}

enum _SnackType { success, error, info }

void _showSnack(BuildContext context, String message,
    {_SnackType type = _SnackType.info}) {
  final color = switch (type) {
    _SnackType.success => _Semantic.success,
    _SnackType.error => _Semantic.danger,
    _SnackType.info => DjassaTheme.courierDark,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_Radius.sm)),
      content: Text(message, style: const TextStyle(color: Colors.white)),
    ),
  );
}

class CourierOrdersScreen extends ConsumerStatefulWidget {
  const CourierOrdersScreen({super.key});

  @override
  ConsumerState<CourierOrdersScreen> createState() =>
      _CourierOrdersScreenState();
}

class _CourierOrdersScreenState extends ConsumerState<CourierOrdersScreen> {
  int _index = 0;

  void _goToProfile() => setState(() => _index = 3);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    // On garde ordersAsync pour l'historique et les livraisons actives déjà acceptées
    final ordersAsync = ref.watch(courierOrdersProvider);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Se connecter'),
          ),
        ),
      );
    }

    if (!user.isCourier) {
      return Scaffold(
        appBar: AppBar(title: const Text('Espace livreur')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(_Gap.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delivery_dining_rounded, size: 72),
                const SizedBox(height: _Gap.lg),
                const Text(
                  "Ce compte n'est pas un profil livreur",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: _Gap.lg),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Retour accueil'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: DjassaTheme.backgroundSecondary,
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(courierOrdersProvider);
              ref.invalidate(courierProfileProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ordersAsync.when(
          loading: () => const _CourierLoading(),
          error: (error, _) => _CourierError(message: '$error'),
          data: (orders) => IndexedStack(
            index: _index,
            children: [
              _CourierHomeTab(
                userId: user.id,
                orders: orders,
                onGoToProfile: _goToProfile,
              ),
              _CourierOrdersTab(
                userId: user.id,
                orders: orders,
                onGoToProfile: _goToProfile,
              ),
              _CourierHistoryTab(userId: user.id, orders: orders),
              _CourierProfileTab(
                onLogout: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: DjassaTheme.primaryWhite,
          indicatorColor: DjassaTheme.courierSoft,
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? DjassaTheme.courierPrimary
                  : DjassaTheme.textSecondary,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? DjassaTheme.courierPrimary
                  : DjassaTheme.textSecondary,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: 'Courses',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(Icons.history_toggle_off_rounded),
              label: 'Historique',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  String get _title => switch (_index) {
        0 => 'Accueil livreur',
        1 => 'Commandes',
        2 => 'Historique',
        _ => 'Profil livreur',
      };

  void _logout(BuildContext context) {
    showLogoutConfirmationSheet(
      context,
      onConfirm: () async {
        await ref.read(authNotifierProvider.notifier).logoutUser();
        if (context.mounted) context.go('/login');
      },
    );
  }
}

// ---------------------------------------------------------------------------
// État de chargement
// ---------------------------------------------------------------------------

class _CourierLoading extends StatelessWidget {
  const _CourierLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(_Gap.xxl),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(_Radius.lg),
          border: Border.all(color: DjassaTheme.borderMedium),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: DjassaTheme.courierPrimary,
              ),
            ),
            SizedBox(height: _Gap.md),
            Text(
              'Chargement...',
              style: TextStyle(
                color: DjassaTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Accueil
// ---------------------------------------------------------------------------

class _CourierHomeTab extends ConsumerWidget {
  const _CourierHomeTab({
    required this.userId,
    required this.orders,
    required this.onGoToProfile,
  });

  final String userId;
  final List<CourierOrder> orders;
  final VoidCallback onGoToProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = orders
        .where((o) => o.courierId == userId && !_isClosed(o.status))
        .toList();
    final completed = orders
        .where((o) => o.courierId == userId && o.status == 'delivered')
        .length;
    final current = active.isEmpty ? null : active.first;
    final profile = ref.watch(courierProfileProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const CourierProfile(),
        );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(courierOrdersProvider);
        ref.invalidate(courierProfileProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(_Gap.lg, _Gap.md, _Gap.lg, _Gap.xxl),
        children: [
          if (!profile.isProfileComplete)
            _IncompleteProfileBanner(
              missing: profile.missingFields,
              onGoToProfile: onGoToProfile,
            ),
          _CourierDashboardHeader(
            isAvailable: profile.isAvailable,
            activeCount: active.length,
            availableCount: 0, // Plus de liste globale disponible
            completedCount: completed,
            onToggleAvailability: (value) async {
              await ref
                  .read(courierProfileServiceProvider)
                  .setAvailability(value);
              ref.invalidate(courierProfileProvider);
            },
          ),
          const SizedBox(height: _Gap.md),
          _CourierFocusPanel(
            isAvailable: profile.isAvailable,
            activeCount: active.length,
            completedCount: completed,
          ),
          const SizedBox(height: _Gap.xl),
          if (current == null)
            _EmptyState(
              icon: Icons.radar_rounded,
              title: 'En attente de courses',
              message:
                  "Assurez-vous d'être disponible. Les commandes vous seront envoyées automatiquement selon votre position.",
            )
          else
            _ActiveDeliveryMapCard(order: current),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Courses (REFONDU : Système d'attribution Push)
// ---------------------------------------------------------------------------

class _CourierOrdersTab extends ConsumerWidget {
  const _CourierOrdersTab({
    required this.userId,
    required this.orders,
    required this.onGoToProfile,
  });

  final String userId;
  final List<CourierOrder> orders;
  final VoidCallback onGoToProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(courierProfileProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const CourierProfile(),
        );

    // Écouteur principal du nouveau système d'attribution
    final assignmentAsync = ref.watch(activeAssignmentStreamProvider);

    // Mes commandes déjà acceptées (pour suivi)
    final mine = orders
        .where((o) => o.courierId == userId && !_isClosed(o.status))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(courierOrdersProvider);
        ref.invalidate(courierProfileProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(_Gap.lg, _Gap.md, _Gap.lg, _Gap.xxl),
        children: [
          if (!profile.isProfileComplete)
            _IncompleteProfileBanner(
              missing: profile.missingFields,
              onGoToProfile: onGoToProfile,
            ),

          // Header de statut de recherche
          Container(
            padding: const EdgeInsets.all(_Gap.lg),
            decoration: BoxDecoration(
              color: DjassaTheme.courierDark,
              borderRadius: BorderRadius.circular(_Radius.lg),
            ),
            child: Row(
              children: [
                Icon(Icons.radar_rounded, color: DjassaTheme.courierPrimary),
                const SizedBox(width: _Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recherche active...',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Les offres apparaîtront ici automatiquement.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _Gap.xl),

          // Zone d'affichage de l'offre active (Push)
          assignmentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erreur de connexion: $e'),
            data: (assignment) {
              if (assignment == null) {
                return const _EmptyState(
                  icon: Icons.notifications_active_outlined,
                  title: 'Aucune offre pour le moment',
                  message:
                      'Restez proche des zones de forte demande pour recevoir plus d\'offres.',
                );
              } else {
                // Une offre est reçue !
                return _ActiveOfferCard(assignment: assignment);
              }
            },
          ),

          const SizedBox(height: _Gap.xl),

          // Section Mes Livraisons en cours
          if (mine.isNotEmpty) ...[
            const _SectionTitle(title: 'Mes livraisons en cours'),
            const SizedBox(height: _Gap.sm),
            ...mine.map((order) => _CourierOrderCard(
                  order: order,
                  accepted: true,
                  profileComplete: true,
                )),
          ]
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte d'Offre Active (Nouveau Widget Clé)
// ---------------------------------------------------------------------------

class _ActiveOfferCard extends ConsumerStatefulWidget {
  final CourierAssignment assignment;

  const _ActiveOfferCard({required this.assignment});

  @override
  ConsumerState<_ActiveOfferCard> createState() => _ActiveOfferCardState();
}

class _ActiveOfferCardState extends ConsumerState<_ActiveOfferCard> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 20; // Temps de réponse imparti
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        // Si le temps est écoulé, on pourrait appeler un refus automatique
        // ou simplement laisser l'UI se mettre à jour via le stream
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final success = await ref.read(assignmentServiceProvider).acceptAssignment(
          widget.assignment.id,
          widget.assignment.orderId,
        );

    if (!mounted) return;

    if (success) {
      _showSnack(context, 'Course acceptée ! Direction le restaurant.',
          type: _SnackType.success);
      // Le stream se mettra à jour et retirera cette carte
    } else {
      setState(() => _isProcessing = false);
      _showSnack(
          context, 'Cette course vient d\'être attribuée à un autre livreur.',
          type: _SnackType.error);
    }
  }

  Future<void> _handleRefuse() async {
    await ref
        .read(assignmentServiceProvider)
        .refuseAssignment(widget.assignment.id);
    if (mounted) {
      _showSnack(context, 'Offre refusée.', type: _SnackType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remainingSeconds / 20.0;
    final color =
        _remainingSeconds < 5 ? _Semantic.danger : DjassaTheme.courierPrimary;

    return Container(
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.xl),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                label: const Text('NOUVELLE OFFRE',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: color,
                padding: EdgeInsets.zero,
              ),
              Text(
                '$_remainingSeconds s',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: _Gap.md),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: _Gap.lg),
          Text(
            'Course #${widget.assignment.orderId.substring(0, 8)}...',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: _Gap.sm),
          Row(
            children: [
              Icon(Icons.location_on,
                  size: 16, color: DjassaTheme.textSecondary),
              const SizedBox(width: 4),
              Text('${widget.assignment.distanceMeters} m du point de retrait'),
            ],
          ),
          const SizedBox(height: _Gap.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _Semantic.danger),
                    foregroundColor: _Semantic.danger,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_Radius.sm)),
                  ),
                  onPressed: _isProcessing ? null : _handleRefuse,
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: _Gap.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_Radius.sm)),
                  ),
                  onPressed: _isProcessing ? null : _handleAccept,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('ACCEPTER MAINTENANT',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bannière profil incomplet
// ---------------------------------------------------------------------------

class _IncompleteProfileBanner extends StatelessWidget {
  const _IncompleteProfileBanner({
    required this.missing,
    required this.onGoToProfile,
  });

  final List<String> missing;
  final VoidCallback onGoToProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: _Gap.md),
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: _Semantic.warningBg,
        borderRadius: BorderRadius.circular(_Radius.md),
        border: Border.all(color: _Semantic.warning.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _Semantic.warning),
              SizedBox(width: _Gap.sm),
              Expanded(
                child: Text(
                  'Profil incomplet — acceptation bloquée',
                  style: TextStyle(
                    color: _Semantic.warning,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _Gap.sm),
          ...missing.map(
            (field) => Padding(
              padding: const EdgeInsets.only(top: _Gap.xs),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: _Semantic.warning),
                  const SizedBox(width: _Gap.sm),
                  Text(
                    field,
                    style: const TextStyle(
                      color: _Semantic.warning,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _Gap.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _Semantic.warning,
                side: const BorderSide(color: _Semantic.warning),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_Radius.sm),
                ),
              ),
              onPressed: onGoToProfile,
              icon: const Icon(Icons.person_rounded, size: 18),
              label: const Text('Compléter mon profil'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Historique
// ---------------------------------------------------------------------------

class _CourierHistoryTab extends StatelessWidget {
  const _CourierHistoryTab({required this.userId, required this.orders});

  final String userId;
  final List<CourierOrder> orders;

  @override
  Widget build(BuildContext context) {
    final history = orders
        .where((o) => o.courierId == userId && _isClosed(o.status))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(_Gap.lg, _Gap.md, _Gap.lg, _Gap.xxl),
      children: [
        _HistorySummary(
          completedCount: history.where((o) => o.status == 'delivered').length,
        ),
        const SizedBox(height: _Gap.xl),
        const _SectionTitle(title: 'Livraisons terminées'),
        const SizedBox(height: _Gap.sm),
        if (history.isEmpty)
          const _EmptyState(
            icon: Icons.history_rounded,
            title: 'Aucun historique',
            message: 'Les livraisons terminées apparaîtront ici.',
          )
        else
          ...history.map(
            (order) => _CourierOrderCard(
              order: order,
              accepted: true,
              profileComplete: true,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Profil
// ---------------------------------------------------------------------------

class _CourierProfileTab extends ConsumerStatefulWidget {
  const _CourierProfileTab({
    required this.onLogout,
  });

  final VoidCallback onLogout;

  @override
  ConsumerState<_CourierProfileTab> createState() => _CourierProfileTabState();
}

class _CourierProfileTabState extends ConsumerState<_CourierProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumber = TextEditingController();
  final _vehiclePlate = TextEditingController();
  final _emergencyPhone = TextEditingController();
  String _licenseType = 'A';
  String _vehicleType = 'Moto';
  String _licensePhotoUrl = '';
  bool _isAvailable = true;
  bool _initialized = false;
  bool _editingProfile = false;
  bool _saving = false;

  @override
  void dispose() {
    _licenseNumber.dispose();
    _vehiclePlate.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final profileAsync = ref.watch(courierProfileProvider);

    return profileAsync.when(
      loading: () => const _CourierLoading(),
      error: (error, _) => _CourierError(message: '$error'),
      data: (profile) {
        if (!_initialized) {
          _licenseNumber.text = profile.licenseNumber;
          _vehiclePlate.text = profile.vehiclePlate;
          _emergencyPhone.text = profile.emergencyPhone;
          _licenseType =
              profile.licenseType.isEmpty ? 'A' : profile.licenseType;
          _vehicleType =
              profile.vehicleType.isEmpty ? 'Moto' : profile.vehicleType;
          _licensePhotoUrl = profile.licensePhotoUrl;
          _isAvailable = profile.isAvailable;
          _editingProfile = !profile.isProfileComplete;
          _initialized = true;
        }

        return ListView(
          padding:
              const EdgeInsets.fromLTRB(_Gap.lg, _Gap.md, _Gap.lg, _Gap.xxl),
          children: [
            _CourierIdentityCard(
              name: user?.fullName ?? 'Livreur Djassa',
              phone: user?.phone ?? user?.email ?? '',
              available: _isAvailable,
              profileComplete: profile.isProfileComplete,
              avatarUrl: user?.avatarUrl,
            ),
            const SizedBox(height: _Gap.xl),
            if (_editingProfile)
              Form(
                key: _formKey,
                child: _CourierProfileForm(
                  licenseNumber: _licenseNumber,
                  vehiclePlate: _vehiclePlate,
                  emergencyPhone: _emergencyPhone,
                  licenseType: _licenseType,
                  vehicleType: _vehicleType,
                  licensePhotoUrl: _licensePhotoUrl,
                  isAvailable: _isAvailable,
                  saving: _saving,
                  onLicenseTypeChanged: (v) => setState(() => _licenseType = v),
                  onVehicleTypeChanged: (v) => setState(() => _vehicleType = v),
                  onAvailabilityChanged: (v) =>
                      setState(() => _isAvailable = v),
                  onPhotoUrlChanged: (v) =>
                      setState(() => _licensePhotoUrl = v),
                  onSave: _save,
                ),
              )
            else
              _CourierProfileSavedCard(
                isAvailable: _isAvailable,
                licenseNumber: _licenseNumber.text,
                licenseType: _licenseType,
                vehicleType: _vehicleType,
                vehiclePlate: _vehiclePlate.text,
                emergencyPhone: _emergencyPhone.text,
                onEdit: () => setState(() => _editingProfile = true),
              ),
            const SizedBox(height: _Gap.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_Radius.sm),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Déconnexion'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(courierProfileServiceProvider).save(
            CourierProfile(
              licenseNumber: _licenseNumber.text,
              licenseType: _licenseType,
              licensePhotoUrl: _licensePhotoUrl,
              vehicleType: _vehicleType,
              vehiclePlate: _vehiclePlate.text,
              emergencyPhone: _emergencyPhone.text,
              isAvailable: _isAvailable,
            ),
          );
      ref.invalidate(courierProfileProvider);
      if (!mounted) return;
      setState(() => _editingProfile = false);
      _showSnack(context, 'Profil livreur enregistré.',
          type: _SnackType.success);
    } catch (e) {
      if (!mounted) return;
      _showSnack(context, 'Erreur profil : $e', type: _SnackType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Formulaire profil
// ---------------------------------------------------------------------------

class _CourierProfileForm extends StatelessWidget {
  const _CourierProfileForm({
    required this.licenseNumber,
    required this.vehiclePlate,
    required this.emergencyPhone,
    required this.licenseType,
    required this.vehicleType,
    required this.licensePhotoUrl,
    required this.isAvailable,
    required this.saving,
    required this.onLicenseTypeChanged,
    required this.onVehicleTypeChanged,
    required this.onAvailabilityChanged,
    required this.onPhotoUrlChanged,
    required this.onSave,
  });

  final TextEditingController licenseNumber;
  final TextEditingController vehiclePlate;
  final TextEditingController emergencyPhone;
  final String licenseType;
  final String vehicleType;
  final String licensePhotoUrl;
  final bool isAvailable;
  final bool saving;
  final ValueChanged<String> onLicenseTypeChanged;
  final ValueChanged<String> onVehicleTypeChanged;
  final ValueChanged<bool> onAvailabilityChanged;
  final ValueChanged<String> onPhotoUrlChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.lg),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations livreur',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: _Gap.xs),
          const Text(
            'Tous les champs sont obligatoires pour accepter des commandes.',
            style: TextStyle(color: DjassaTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: _Gap.lg),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: DjassaTheme.courierPrimary,
            value: isAvailable,
            onChanged: onAvailabilityChanged,
            title: const Text('Disponible pour livrer'),
            subtitle: const Text('Active ou suspend la réception des courses'),
          ),
          const SizedBox(height: _Gap.md),
          TextFormField(
            controller: licenseNumber,
            decoration: InputDecoration(
              labelText: 'Numéro du permis *',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_Radius.sm),
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: _Gap.md),
          DropdownButtonFormField<String>(
            initialValue: licenseType,
            decoration: InputDecoration(
              labelText: 'Type de permis *',
              prefixIcon: const Icon(Icons.card_membership_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_Radius.sm),
              ),
            ),
            items: const [
              'A',
              'B',
              'C',
              'D',
              'Toutes catégories',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (value) => onLicenseTypeChanged(value ?? 'A'),
          ),
          const SizedBox(height: _Gap.lg),
          Text(
            'Photo du permis *',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: _Gap.sm),
          _PhotoPickerField(
            currentUrl: licensePhotoUrl,
            onPicked: onPhotoUrlChanged,
          ),
          const SizedBox(height: _Gap.md),
          DropdownButtonFormField<String>(
            initialValue: vehicleType,
            decoration: InputDecoration(
              labelText: 'Véhicule *',
              prefixIcon: const Icon(Icons.two_wheeler_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_Radius.sm),
              ),
            ),
            items: const [
              'Moto',
              'Voiture',
              'Tricycle',
              'Camionnette',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (value) => onVehicleTypeChanged(value ?? 'Moto'),
          ),
          const SizedBox(height: _Gap.md),
          TextFormField(
            controller: vehiclePlate,
            decoration: InputDecoration(
              labelText: 'Immatriculation *',
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_Radius.sm),
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: _Gap.md),
          TextFormField(
            controller: emergencyPhone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Contact urgence *',
              prefixIcon: const Icon(Icons.emergency_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_Radius.sm),
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: _Gap.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: DjassaTheme.courierPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_Radius.sm),
                ),
              ),
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte profil enregistré
// ---------------------------------------------------------------------------

class _CourierProfileSavedCard extends StatelessWidget {
  const _CourierProfileSavedCard({
    required this.isAvailable,
    required this.licenseNumber,
    required this.licenseType,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.emergencyPhone,
    required this.onEdit,
  });

  final bool isAvailable;
  final String licenseNumber;
  final String licenseType;
  final String vehicleType;
  final String vehiclePlate;
  final String emergencyPhone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.lg),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: _Semantic.successBg,
                child: Icon(
                  Icons.verified_user_rounded,
                  color: _Semantic.success,
                ),
              ),
              const SizedBox(width: _Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profil livreur enregistré',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: _Gap.xs),
                    Text(
                      isAvailable
                          ? 'Vous êtes disponible pour les livraisons.'
                          : 'Vous êtes actuellement indisponible.',
                      style: const TextStyle(
                        color: DjassaTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _Gap.lg),
          Container(
            padding: const EdgeInsets.all(_Gap.md),
            decoration: BoxDecoration(
              color: DjassaTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(_Radius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(
                  icon: Icons.badge_outlined,
                  text: 'Permis $licenseType — $licenseNumber',
                ),
                _InfoLine(
                  icon: Icons.two_wheeler_rounded,
                  text: '$vehicleType — $vehiclePlate',
                ),
                _InfoLine(
                  icon: Icons.emergency_rounded,
                  text: 'Urgence : $emergencyPhone',
                ),
              ],
            ),
          ),
          const SizedBox(height: _Gap.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_Radius.sm),
                ),
              ),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Modifier profil'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget photo picker
// ---------------------------------------------------------------------------

class _PhotoPickerField extends StatefulWidget {
  const _PhotoPickerField({required this.currentUrl, required this.onPicked});

  final String currentUrl;
  final ValueChanged<String> onPicked;

  @override
  State<_PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<_PhotoPickerField> {
  bool _uploading = false;

  Future<void> _pickFrom(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      final user = SupabaseService.client.auth.currentUser;

      if (user == null) {
        throw Exception('Utilisateur non authentifié');
      }

      const bucket = 'courier-documents';
      final contentType = ext == 'jpg' ? 'image/jpeg' : 'image/$ext';
      final path =
          '${user.id}/licenses/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await SupabaseService.client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
              cacheControl: '3600',
            ),
          );

      final url = await SupabaseService.client.storage
          .from(bucket)
          .createSignedUrl(path, 60 * 60 * 24 * 30);

      widget.onPicked(url);

      if (mounted) {
        _showSnack(
          context,
          'Photo du permis uploadée avec succès',
          type: _SnackType.success,
        );
      }
    } on StorageException catch (e) {
      final message = _getStorageErrorMessage(e);
      if (mounted) _showSnack(context, message, type: _SnackType.error);
    } catch (e) {
      if (mounted) {
        _showSnack(context, 'Erreur inattendue : $e', type: _SnackType.error);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _getStorageErrorMessage(StorageException e) {
    final code = e.statusCode;
    final message = e.message.toLowerCase();

    if (code == '404' ||
        message.contains('bucket') && message.contains('not found')) {
      return 'Bucket "courier-documents" introuvable. Contactez un administrateur pour créer le bucket.';
    }
    if (code == '401' || message.contains('unauthenticated')) {
      return 'Veuillez vous reconnecter pour uploader une photo.';
    }
    if (code == '403' ||
        message.contains('policy') ||
        message.contains('permission')) {
      return 'Permissions insuffisantes. Vérifiez les politiques RLS du bucket.';
    }
    if (message.contains('file size') || message.contains('too large')) {
      return 'Photo trop volumineuse. Veuillez sélectionner une image de moins de 5 Mo.';
    }
    if (message.contains('mime') || message.contains('content type')) {
      return 'Format d\'image non supporté. Utilisez PNG, JPG ou WebP.';
    }
    return 'Erreur upload : ${e.message}';
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_Radius.lg)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: _Gap.lg, horizontal: _Gap.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: _Gap.xl),
                decoration: BoxDecoration(
                  color: DjassaTheme.borderMedium,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Text(
                widget.currentUrl.isEmpty
                    ? 'Ajouter la photo du permis'
                    : 'Modifier la photo du permis',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: _Gap.xl),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.photo_library_rounded),
                ),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFrom(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.camera_alt_rounded),
                ),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFrom(ImageSource.camera);
                },
              ),
              if (widget.currentUrl.isNotEmpty)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: _Semantic.dangerBg,
                    child: Icon(Icons.delete_outline_rounded,
                        color: _Semantic.danger),
                  ),
                  title: const Text('Supprimer la photo',
                      style: TextStyle(
                        color: _Semantic.danger,
                        fontWeight: FontWeight.w700,
                      )),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPicked('');
                  },
                ),
              const SizedBox(height: _Gap.sm),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.currentUrl.isNotEmpty;

    return GestureDetector(
      onTap: _uploading ? null : () => _showSourcePicker(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 170,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasPhoto
              ? Colors.transparent
              : DjassaTheme.backgroundSecondary.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(_Radius.sm),
          border: Border.all(
            color: hasPhoto ? _Semantic.success : DjassaTheme.borderMedium,
            width: hasPhoto ? 2 : 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_Radius.sm),
          child: _uploading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: DjassaTheme.courierPrimary,
                      ),
                      SizedBox(height: _Gap.md),
                      Text(
                        'Upload en cours...',
                        style: TextStyle(color: DjassaTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : hasPhoto
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.currentUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: DjassaTheme.backgroundSecondary,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: DjassaTheme.courierPrimary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: DjassaTheme.backgroundSecondary,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, size: 48),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            color:
                                DjassaTheme.courierDark.withValues(alpha: .55),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Modifier',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _Gap.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _Semantic.success,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Photo ajoutée',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_rounded,
                          size: 38,
                          color: DjassaTheme.textSecondary,
                        ),
                        const SizedBox(height: _Gap.md),
                        const Text(
                          'Ajouter la photo du permis',
                          style: TextStyle(
                            color: DjassaTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: _Gap.xs),
                        Text(
                          'Galerie ou caméra',
                          style: TextStyle(
                            color:
                                DjassaTheme.textSecondary.withValues(alpha: .7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _StatusActionSpec {
  const _StatusActionSpec({
    required this.label,
    required this.icon,
    required this.color,
    required this.nextStatus,
    required this.successMessage,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String nextStatus;
  final String successMessage;
}

_StatusActionSpec? _nextActionFor(String status) {
  switch (status) {
    case 'courier_assigned':
      return const _StatusActionSpec(
        label: 'Préparation terminée',
        icon: Icons.inventory_2_rounded,
        color: DjassaTheme.courierPrimary,
        nextStatus: 'confirmed',
        successMessage: 'Préparation signalée au client.',
      );
    case 'confirmed':
      return const _StatusActionSpec(
        label: 'En cours de livraison',
        icon: Icons.delivery_dining_rounded,
        color: _Semantic.info,
        nextStatus: 'shipping',
        successMessage: 'Livraison en cours — le client est notifié.',
      );
    case 'shipping':
      return const _StatusActionSpec(
        label: 'Livré',
        icon: Icons.verified_rounded,
        color: _Semantic.success,
        nextStatus: 'delivered',
        successMessage: 'Livraison terminée.',
      );
    default:
      return null;
  }
}

class _StatusActionButton extends ConsumerWidget {
  const _StatusActionButton({required this.orderId, required this.spec});

  final String orderId;
  final _StatusActionSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: spec.color,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_Radius.sm),
          ),
        ),
        onPressed: () async {
          try {
            await ref
                .read(courierOrderServiceProvider)
                .updateOrderStatus(orderId, spec.nextStatus);
            ref.invalidate(courierOrdersProvider);
            if (!context.mounted) return;
            _showSnack(context, spec.successMessage, type: _SnackType.success);
          } catch (e) {
            if (!context.mounted) return;
            _showSnack(context, 'Erreur statut : $e', type: _SnackType.error);
          }
        },
        icon: Icon(spec.icon),
        label: Text(spec.label),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte livraison active avec map
// ---------------------------------------------------------------------------

class _ActiveDeliveryMapCard extends ConsumerWidget {
  const _ActiveDeliveryMapCard({required this.order});

  final CourierOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = _trackingFromOrder(order);
    final fallback = DeliveryTrackingService.fallbackSnapshot(
      DeliveryTrackingQuery(
        orderId: tracking.orderId,
        address: tracking.address,
        createdAt: tracking.createdAt,
        deliveryAt: tracking.deliveryAt,
      ),
      DateTime.now(),
    );
    final snapshot = ref
        .watch(liveDeliveryTrackingProvider(tracking))
        .maybeWhen(data: (value) => value, orElse: () => fallback);
    final gps = ref
        .watch(courierLocationPublisherProvider(tracking))
        .maybeWhen(data: (value) => value, orElse: () => null);
    final action = _nextActionFor(order.status);

    return Container(
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: DjassaTheme.courierDark,
        borderRadius: BorderRadius.circular(_Radius.xl),
        boxShadow: DjassaTheme.shadowHeavy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: DjassaTheme.courierPrimary.withValues(
                  alpha: .16,
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: DjassaTheme.courierPrimary,
                ),
              ),
              const SizedBox(width: _Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Livraison en cours',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: DjassaTheme.primaryWhite,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      order.orderNumber,
                      style: TextStyle(
                        color: DjassaTheme.primaryWhite.withValues(alpha: .68),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _Gap.lg),
          RealtimeDeliveryMap(tracking: tracking, snapshot: snapshot),
          const SizedBox(height: _Gap.md),
          Row(
            children: [
              _LiveStatusChip(
                label: gps?.isLive == true ? 'Mon GPS live' : 'GPS en attente',
                color: gps?.isLive == true
                    ? _Semantic.success
                    : DjassaTheme.courierPrimary,
              ),
              const SizedBox(width: _Gap.sm),
              _LiveStatusChip(
                label: snapshot.hasClientRealtime
                    ? 'Client live'
                    : 'Client estimé',
                color: snapshot.hasClientRealtime
                    ? _Semantic.success
                    : DjassaTheme.primaryWhite.withValues(alpha: .5),
              ),
            ],
          ),
          const SizedBox(height: _Gap.md),
          _InfoLine(
              icon: Icons.place_rounded,
              text: order.deliveryAddress,
              dark: true),
          _InfoLine(
              icon: Icons.person_rounded, text: order.customerName, dark: true),
          if (order.customerPhone.isNotEmpty)
            _InfoLine(
                icon: Icons.phone_rounded,
                text: order.customerPhone,
                dark: true),
          const SizedBox(height: _Gap.lg),
          if (action != null && order.status != 'shipping')
            _StatusActionButton(orderId: order.id, spec: action)
          else if (order.status == 'shipping')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DjassaTheme.primaryWhite,
                      side: BorderSide(
                        color: DjassaTheme.primaryWhite.withValues(alpha: .28),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_Radius.sm),
                      ),
                    ),
                    onPressed: () => _setStatus(context, ref, 'shipping'),
                    icon: const Icon(Icons.route_rounded),
                    label: const Text('Toujours en route'),
                  ),
                ),
                const SizedBox(width: _Gap.md),
                Expanded(
                  child: _StatusActionButton(
                    orderId: order.id,
                    spec: _nextActionFor('shipping')!,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    try {
      await ref
          .read(courierOrderServiceProvider)
          .updateOrderStatus(order.id, status);
      ref.invalidate(courierOrdersProvider);
      if (!context.mounted) return;
      _showSnack(context, 'Livraison toujours en route.');
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Erreur statut : $e', type: _SnackType.error);
    }
  }
}

// ---------------------------------------------------------------------------
// Widgets communs
// ---------------------------------------------------------------------------

class _CourierDashboardHeader extends StatelessWidget {
  const _CourierDashboardHeader({
    required this.isAvailable,
    required this.activeCount,
    required this.availableCount,
    required this.completedCount,
    required this.onToggleAvailability,
  });

  final bool isAvailable;
  final int activeCount;
  final int availableCount;
  final int completedCount;
  final ValueChanged<bool> onToggleAvailability;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_Gap.xl),
      decoration: BoxDecoration(
        color: DjassaTheme.courierDark,
        borderRadius: BorderRadius.circular(_Radius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isAvailable
                    ? _Semantic.successBg.withValues(alpha: .16)
                    : _Semantic.warningBg.withValues(alpha: .16),
                child: Icon(
                  isAvailable
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_rounded,
                  color: isAvailable ? _Semantic.success : _Semantic.warning,
                ),
              ),
              const SizedBox(width: _Gap.md),
              Expanded(
                child: Text(
                  isAvailable ? 'Disponible' : 'Indisponible',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DjassaTheme.primaryWhite,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Switch.adaptive(
                value: isAvailable,
                activeThumbColor: DjassaTheme.courierPrimary,
                onChanged: onToggleAvailability,
              ),
            ],
          ),
          const SizedBox(height: _Gap.lg),
          Row(
            children: [
              _StatPill(label: 'En cours', value: '$activeCount'),
              const SizedBox(width: _Gap.sm),
              // On garde availableCount pour la cohérence UI mais il sera à 0
              _StatPill(label: 'Disponibles', value: '$availableCount'),
              const SizedBox(width: _Gap.sm),
              _StatPill(label: 'Livrées', value: '$completedCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(_Radius.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: DjassaTheme.primaryWhite,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: DjassaTheme.primaryWhite.withValues(alpha: .62),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourierFocusPanel extends StatelessWidget {
  const _CourierFocusPanel({
    required this.isAvailable,
    required this.activeCount,
    required this.completedCount,
  });

  final bool isAvailable;
  final int activeCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final readiness = isAvailable ? 1.0 : .35;
    final message = activeCount > 0
        ? 'Priorite: terminez votre livraison active.'
        : isAvailable
            ? 'Restez dans une zone dense pour recevoir plus vite.'
            : 'Activez votre disponibilite pour recevoir des courses.';

    return Container(
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.lg),
        border: Border.all(
            color: DjassaTheme.courierPrimary.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: DjassaTheme.courierSoft,
                child: Icon(Icons.route_rounded,
                    color: DjassaTheme.courierPrimary),
              ),
              const SizedBox(width: _Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mission du jour',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      message,
                      style: const TextStyle(color: DjassaTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _Gap.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: readiness,
              minHeight: 7,
              backgroundColor: DjassaTheme.courierSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DjassaTheme.courierPrimary,
              ),
            ),
          ),
          const SizedBox(height: _Gap.md),
          Row(
            children: [
              _CourierFocusChip(
                  icon: Icons.flash_on_rounded, label: 'Auto-attribution'),
              const SizedBox(width: _Gap.sm),
              _CourierFocusChip(
                  icon: Icons.verified_user_rounded,
                  label: '$completedCount terminees'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourierFocusChip extends StatelessWidget {
  const _CourierFocusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _Gap.sm, vertical: 9),
        decoration: BoxDecoration(
          color: DjassaTheme.courierSoft,
          borderRadius: BorderRadius.circular(_Radius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: DjassaTheme.courierPrimary, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DjassaTheme.courierDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourierIdentityCard extends ConsumerWidget {
  const _CourierIdentityCard({
    required this.name,
    required this.phone,
    required this.available,
    required this.profileComplete,
    this.avatarUrl,
  });

  final String name;
  final String phone;
  final bool available;
  final bool profileComplete;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(_Gap.xl),
      decoration: BoxDecoration(
        color: DjassaTheme.courierDark,
        borderRadius: BorderRadius.circular(_Radius.xl),
      ),
      child: Row(
        children: [
          AvatarPicker(
            currentUrl: avatarUrl,
            radius: 32,
            fallbackIcon: Icons.delivery_dining_rounded,
            fallbackColor: DjassaTheme.courierPrimary,
            backgroundColor: DjassaTheme.courierPrimary.withValues(alpha: .16),
            onUpdated: (_) {
              ref.read(authNotifierProvider.notifier).refreshUser();
            },
          ),
          const SizedBox(width: _Gap.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? 'Livreur Djassa' : name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DjassaTheme.primaryWhite,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: _Gap.xs),
                Text(
                  phone,
                  style: TextStyle(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .68),
                  ),
                ),
                const SizedBox(height: _Gap.sm),
                Text(
                  available ? 'Statut : disponible' : 'Statut : indisponible',
                  style: TextStyle(
                    color: available ? _Semantic.success : _Semantic.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: _Gap.sm),
                Row(
                  children: [
                    Icon(
                      profileComplete
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      size: 15,
                      color: profileComplete
                          ? _Semantic.success
                          : _Semantic.warning,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      profileComplete
                          ? 'Profil complet'
                          : 'Profil incomplet — courses bloquées',
                      style: TextStyle(
                        color: profileComplete
                            ? _Semantic.success
                            : _Semantic.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.completedCount});

  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_Gap.xl),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.lg),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: _Semantic.successBg,
            child: Icon(Icons.verified_rounded, color: _Semantic.success),
          ),
          const SizedBox(width: _Gap.md),
          Expanded(
            child: Text(
              '$completedCount livraison(s) livrée(s)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierOrderCard extends StatelessWidget {
  const _CourierOrderCard({
    required this.order,
    required this.profileComplete,
    this.onAccept,
    this.onRefuse,
    this.accepted = false,
  });

  final CourierOrder order;
  final bool profileComplete;
  final VoidCallback? onAccept;
  final VoidCallback? onRefuse;
  final bool accepted;

  @override
  Widget build(BuildContext context) {
    final action = accepted ? _nextActionFor(order.status) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: _Gap.md),
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.lg),
        border: Border.all(
          color: accepted
              ? _Semantic.success.withValues(alpha: .35)
              : DjassaTheme.borderMedium,
        ),
        boxShadow: DjassaTheme.shadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: _Gap.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accepted
                      ? _Semantic.successBg
                      : DjassaTheme.courierPrimary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  accepted
                      ? _statusLabel(order.status).toUpperCase()
                      : 'NOUVELLE',
                  style: TextStyle(
                    color: accepted
                        ? _Semantic.success
                        : DjassaTheme.courierPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                order.orderNumber,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: _Gap.md),
          Text(
            order.deliveryAddress.isEmpty
                ? 'Adresse non renseignée'
                : order.deliveryAddress,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: _Gap.sm),
          _InfoLine(icon: Icons.person_rounded, text: order.customerName),
          if (order.customerPhone.isNotEmpty)
            _InfoLine(icon: Icons.phone_rounded, text: order.customerPhone),
          _InfoLine(
            icon: Icons.shopping_bag_rounded,
            text:
                '${order.itemsCount} article(s) - ${formatPrice(order.total)}',
          ),
          _InfoLine(icon: Icons.info_rounded, text: _statusLabel(order.status)),
          if (action != null) ...[
            const SizedBox(height: _Gap.md),
            _StatusActionButton(orderId: order.id, spec: action),
          ] else if (!accepted) ...[
            const SizedBox(height: _Gap.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_Radius.sm),
                      ),
                    ),
                    onPressed: onRefuse,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: _Gap.md),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: profileComplete
                          ? DjassaTheme.courierPrimary
                          : DjassaTheme.textSecondary.withValues(alpha: .5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_Radius.sm),
                      ),
                    ),
                    onPressed: onAccept,
                    icon: Icon(
                      profileComplete
                          ? Icons.check_rounded
                          : Icons.lock_rounded,
                    ),
                    label: Text(profileComplete ? 'Accepter' : 'Profil requis'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.dark = false});

  final IconData icon;
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        dark ? DjassaTheme.courierPrimary : DjassaTheme.textSecondary;
    final textStyle = dark
        ? TextStyle(color: DjassaTheme.primaryWhite.withValues(alpha: .76))
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: _Gap.sm),
      child: Row(
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: _Gap.sm),
          Expanded(child: Text(text, style: textStyle)),
        ],
      ),
    );
  }
}

class _LiveStatusChip extends StatelessWidget {
  const _LiveStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_Gap.xxl),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.lg),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        children: [
          Icon(icon, size: 54, color: DjassaTheme.courierPrimary),
          const SizedBox(height: _Gap.md),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: _Gap.xs),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _CourierError extends StatelessWidget {
  const _CourierError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(_Gap.xxl),
        padding: const EdgeInsets.all(_Gap.xl),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(_Radius.lg),
          border: Border.all(color: _Semantic.danger.withValues(alpha: .3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: _Semantic.danger, size: 40),
            const SizedBox(height: _Gap.md),
            const Text(
              "Impossible de charger l'espace livreur.",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: _Gap.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: DjassaTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DeliveryTracking _trackingFromOrder(CourierOrder order) {
  return DeliveryTracking(
    orderId: order.id,
    orderNumber: order.orderNumber,
    address: order.deliveryAddress,
    createdAt: order.createdAt,
    deliveryAt: DateTime.now().add(const Duration(hours: 2)),
  );
}

bool _isClosed(String status) => status == 'delivered' || status == 'cancelled';

String _statusLabel(String status) {
  switch (status) {
    case 'pending_payment':
      return 'Paiement attendu';
    case 'paid':
      return 'Payée';
    case 'confirmed':
      return 'Confirmée';
    case 'courier_assigned':
      return 'Assignée';
    case 'shipping':
      return 'En route';
    case 'delivered':
      return 'Livrée';
    case 'cancelled':
      return 'Annulée';
    default:
      return status;
  }
}
