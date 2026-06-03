import 'package:djassa/core/theme/avatar_picker.dart';
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delivery_dining_rounded, size: 72),
                const SizedBox(height: 16),
                const Text(
                  "Ce compte n'est pas un profil livreur",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
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
          loading: () => const Center(child: CircularProgressIndicator()),
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
                onGoToOrders: () => setState(() => _index = 1),
                onLogout: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
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
    final available = orders.where((o) => o.courierId != userId).toList();
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (!profile.isProfileComplete)
            _IncompleteProfileBanner(
              missing: profile.missingFields,
              onGoToProfile: onGoToProfile,
            ),
          _CourierDashboardHeader(
            isAvailable: profile.isAvailable,
            activeCount: active.length,
            availableCount: available.length,
            completedCount: completed,
            onToggleAvailability: (value) async {
              await ref
                  .read(courierProfileServiceProvider)
                  .setAvailability(value);
              ref.invalidate(courierProfileProvider);
            },
          ),
          const SizedBox(height: 18),
          if (current == null)
            _EmptyState(
              icon: Icons.map_rounded,
              title: 'Aucune livraison active',
              message: available.isEmpty
                  ? "La carte s'affichera ici dès que vous acceptez une commande"
                  : "${available.length} commande(s) disponible(s). Ouvrez Courses pour accepter.",
            )
          else
            _ActiveDeliveryMapCard(order: current),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Courses
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
    final profileComplete = profile.isProfileComplete;

    final mine = orders
        .where((o) => o.courierId == userId && !_isClosed(o.status))
        .toList();
    final available = orders
        .where((o) => o.courierId != userId && !_isClosed(o.status))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(courierOrdersProvider);
        ref.invalidate(courierProfileProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (!profileComplete)
            _IncompleteProfileBanner(
              missing: profile.missingFields,
              onGoToProfile: onGoToProfile,
            ),
          _HeaderCard(availableCount: available.length),
          const SizedBox(height: 18),
          if (mine.isNotEmpty) ...[
            const _SectionTitle(title: 'Mes livraisons acceptées'),
            const SizedBox(height: 10),
            ...mine.map(
              (order) => _CourierOrderCard(
                order: order,
                accepted: true,
                profileComplete: profileComplete,
              ),
            ),
            const SizedBox(height: 18),
          ],
          const _SectionTitle(title: 'Nouvelles commandes'),
          const SizedBox(height: 10),
          if (available.isEmpty)
            const _EmptyCourierOrders()
          else
            ...available.map(
              (order) => _CourierOrderCard(
                order: order,
                profileComplete: profileComplete,
                onAccept:
                    profileComplete ? () => _accept(context, ref, order) : null,
                onRefuse: () => _refuse(context, ref, order),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    CourierOrder order,
  ) async {
    try {
      final accepted =
          await ref.read(courierOrderServiceProvider).acceptOrder(order.id);
      ref.invalidate(courierOrdersProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: accepted ? Colors.green : Colors.orange,
          content: Text(
            accepted
                ? 'Commande ${order.orderNumber} acceptée.'
                : 'Trop tard, cette commande a déjà été prise.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur acceptation : $e')));
    }
  }

  Future<void> _refuse(
    BuildContext context,
    WidgetRef ref,
    CourierOrder order,
  ) async {
    try {
      await ref.read(courierOrderServiceProvider).refuseOrder(order.id);
      ref.invalidate(courierOrdersProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commande ${order.orderNumber} refusée.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur refus : $e')));
    }
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Profil incomplet — acceptation bloquée',
                  style: TextStyle(
                    color: Colors.orange.shade200,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...missing.map(
            (field) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: Colors.orange.shade300),
                  const SizedBox(width: 8),
                  Text(
                    field,
                    style: TextStyle(
                      color: Colors.orange.shade200,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HistorySummary(
          completedCount: history.where((o) => o.status == 'delivered').length,
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Livraisons terminées'),
        const SizedBox(height: 10),
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
    required this.onGoToOrders,
    required this.onLogout,
  });

  final VoidCallback onGoToOrders;
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CourierIdentityCard(
              name: user?.fullName ?? 'Livreur Djassa',
              phone: user?.phone ?? user?.email ?? '',
              available: _isAvailable,
              profileComplete: profile.isProfileComplete,
              avatarUrl: user?.avatarUrl,
            ),
            const SizedBox(height: 18),
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
                onEdit: () => setState(() => _editingProfile = true),
              ),
            const SizedBox(height: 14),
            _CourierProfileActions(
              onGoToOrders: widget.onGoToOrders,
              onRefresh: () {
                ref.invalidate(courierOrdersProvider);
                ref.invalidate(courierProfileProvider);
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Profil livreur enregistré.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur profil : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CourierProfileActions extends StatelessWidget {
  const _CourierProfileActions({
    required this.onGoToOrders,
    required this.onRefresh,
  });

  final VoidCallback onGoToOrders;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mon espace livreur',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _ProfileShortcut(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Courses disponibles',
            subtitle: 'Accepter ou refuser les nouvelles commandes',
            onTap: onGoToOrders,
          ),
          _ProfileShortcut(
            icon: Icons.notifications_active_rounded,
            title: 'Alertes commande',
            subtitle: 'Reception sur le telephone des nouvelles courses',
            onTap: onRefresh,
          ),
          _ProfileShortcut(
            icon: Icons.support_agent_rounded,
            title: 'Support livreur',
            subtitle: 'Aide en cas de blocage pendant une livraison',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support livreur bientot actif.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileShortcut extends StatelessWidget {
  const _ProfileShortcut({
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
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DjassaTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(18),
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
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: DjassaTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
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

// ---------------------------------------------------------------------------
// Formulaire profil — avec photo picker
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations livreur',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Tous les champs sont obligatoires pour accepter des commandes.',
            style: TextStyle(color: DjassaTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: isAvailable,
            onChanged: onAvailabilityChanged,
            title: const Text('Disponible pour livrer'),
            subtitle: const Text('Active ou suspend la réception des courses'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: licenseNumber,
            decoration: const InputDecoration(
              labelText: 'Numéro du permis *',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: licenseType,
            decoration: const InputDecoration(
              labelText: 'Type de permis *',
              prefixIcon: Icon(Icons.card_membership_rounded),
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
          const SizedBox(height: 16),
          Text(
            'Photo du permis *',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _PhotoPickerField(
            currentUrl: licensePhotoUrl,
            onPicked: onPhotoUrlChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: vehicleType,
            decoration: const InputDecoration(
              labelText: 'Véhicule *',
              prefixIcon: Icon(Icons.two_wheeler_rounded),
            ),
            items: const [
              'Moto',
              'Voiture',
              'Tricycle',
              'Camionnette',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (value) => onVehicleTypeChanged(value ?? 'Moto'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: vehiclePlate,
            decoration: const InputDecoration(
              labelText: 'Immatriculation *',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emergencyPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact urgence *',
              prefixIcon: Icon(Icons.emergency_rounded),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: DjassaTheme.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
// Widget photo picker - CORRIGÉ ✅
// ---------------------------------------------------------------------------

class _CourierProfileSavedCard extends StatelessWidget {
  const _CourierProfileSavedCard({
    required this.isAvailable,
    required this.onEdit,
  });

  final bool isAvailable;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.withValues(alpha: .12),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
                    Text(
                      isAvailable
                          ? 'Vous êtes disponible pour les livraisons.'
                          : 'Vous êtes actuellement indisponible.',
                      style: TextStyle(
                        color: DjassaTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
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

class _PhotoPickerField extends StatefulWidget {
  const _PhotoPickerField({required this.currentUrl, required this.onPicked});

  final String currentUrl;
  final ValueChanged<String> onPicked;

  @override
  State<_PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<_PhotoPickerField> {
  bool _uploading = false;

  /// Upload vers Supabase Storage avec gestion d'erreur robuste
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

      // ✅ Path sécurisé : licenses/{user_id}/{timestamp}.{ext}
      const bucket = 'courier-documents';
      final contentType = ext == 'jpg' ? 'image/jpeg' : 'image/$ext';
      final path =
          '${user.id}/licenses/${DateTime.now().millisecondsSinceEpoch}.$ext';

      // ✅ Upload avec upsert:true pour permettre la réécriture
      await SupabaseService.client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
              cacheControl: '3600',
            ),
          );

      // ✅ Pour bucket PRIVÉ : utiliser createSignedUrl au lieu de getPublicUrl
      final url = await SupabaseService.client.storage
          .from(bucket)
          .createSignedUrl(path, 60 * 60 * 24 * 30); // URL valable 30 jours

      widget.onPicked(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Photo du permis uploadée avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on StorageException catch (e) {
      // ✅ Gestion spécifique des erreurs Supabase Storage
      final message = _getStorageErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur inattendue : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Traduit les erreurs StorageException en messages utilisateur clairs
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Text(
                'Ajouter la photo du permis',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 8),
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
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasPhoto
              ? Colors.transparent
              : DjassaTheme.backgroundSecondary.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPhoto ? Colors.green.shade400 : DjassaTheme.borderMedium,
            width: hasPhoto ? 2 : 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: _uploading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('Upload en cours...'),
                    ],
                  ),
                )
              : hasPhoto
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        // ✅ Image.network fonctionne avec les URL signées
                        Image.network(
                          widget.currentUrl,
                          fit: BoxFit.cover,
                          headers: {
                            // Si nécessaire, ajouter des headers d'authentification
                          },
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, size: 48),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            color: Colors.black.withValues(alpha: .55),
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
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
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
                        Icon(
                          Icons.add_a_photo_rounded,
                          size: 38,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Ajouter la photo du permis',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Galerie ou caméra',
                          style: TextStyle(
                            color: Colors.grey.shade400,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(28),
        boxShadow: DjassaTheme.shadowHeavy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: DjassaTheme.accentOrange.withValues(
                  alpha: .16,
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: DjassaTheme.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 14),
          RealtimeDeliveryMap(tracking: tracking, snapshot: snapshot),
          const SizedBox(height: 12),
          Row(
            children: [
              _LiveStatusChip(
                label: gps?.isLive == true ? 'Mon GPS live' : 'GPS en attente',
                color: gps?.isLive == true
                    ? Colors.green
                    : DjassaTheme.accentOrange,
              ),
              const SizedBox(width: 8),
              _LiveStatusChip(
                label: snapshot.hasClientRealtime
                    ? 'Client live'
                    : 'Client estimé',
                color:
                    snapshot.hasClientRealtime ? Colors.green : Colors.blueGrey,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DarkInfoLine(icon: Icons.place_rounded, text: order.deliveryAddress),
          _DarkInfoLine(icon: Icons.person_rounded, text: order.customerName),
          if (order.customerPhone.isNotEmpty)
            _DarkInfoLine(icon: Icons.phone_rounded, text: order.customerPhone),
          const SizedBox(height: 14),
          if (order.status == 'courier_assigned')
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DjassaTheme.accentOrange,
                ),
                onPressed: () => _setStatus(context, ref, 'confirmed'),
                icon: const Icon(Icons.inventory_2_rounded),
                label: const Text('Préparation terminée'),
              ),
            )
          else if (order.status == 'confirmed')
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                ),
                onPressed: () => _setStatus(context, ref, 'shipping'),
                icon: const Icon(Icons.delivery_dining_rounded),
                label: const Text('En cours de livraison'),
              ),
            )
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
                    ),
                    onPressed: () => _setStatus(context, ref, 'shipping'),
                    icon: const Icon(Icons.route_rounded),
                    label: const Text('Toujours en route'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _setStatus(context, ref, 'delivered'),
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Livré'),
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
          .updateOrderStatus(this.order.id, status);
      ref.invalidate(courierOrdersProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            switch (status) {
              'delivered' => 'Livraison terminée.',
              'confirmed' => 'Préparation signalée au client.',
              'shipping' => 'Livraison en cours — le client est notifié.',
              _ => 'Statut mis à jour.',
            },
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur statut : $e')));
    }
  }
}

// ---------------------------------------------------------------------------
// Widgets communs (inchangés)
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isAvailable
                    ? Colors.green.withValues(alpha: .16)
                    : Colors.orange.withValues(alpha: .16),
                child: Icon(
                  isAvailable
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_rounded,
                  color: isAvailable ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
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
                onChanged: onToggleAvailability,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatPill(label: 'En cours', value: '$activeCount'),
              const SizedBox(width: 8),
              _StatPill(label: 'Disponibles', value: '$availableCount'),
              const SizedBox(width: 8),
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
          borderRadius: BorderRadius.circular(18),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          AvatarPicker(
            currentUrl: avatarUrl,
            radius: 32,
            fallbackIcon: Icons.delivery_dining_rounded,
            fallbackColor: DjassaTheme.accentOrange,
            backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .16),
            onUpdated: (_) {
              ref.read(authNotifierProvider.notifier).refreshUser();
            },
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: TextStyle(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .68),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  available ? 'Statut : disponible' : 'Statut : indisponible',
                  style: TextStyle(
                    color: available ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      profileComplete
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      size: 15,
                      color: profileComplete ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      profileComplete
                          ? 'Profil complet'
                          : 'Profil incomplet — courses bloquées',
                      style: TextStyle(
                        color: profileComplete
                            ? Colors.greenAccent
                            : Colors.orange,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green.withValues(alpha: .12),
            child: const Icon(Icons.verified_rounded, color: Colors.green),
          ),
          const SizedBox(width: 12),
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.availableCount});

  final int availableCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .18),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: DjassaTheme.accentOrange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$availableCount commande(s) disponible(s)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DjassaTheme.primaryWhite,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Le premier livreur qui accepte gagne la livraison.',
                  style: TextStyle(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierStatusButton extends ConsumerWidget {
  const _CourierStatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.orderId,
    required this.nextStatus,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String orderId;
  final String nextStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: () async {
          try {
            await ref
                .read(courierOrderServiceProvider)
                .updateOrderStatus(orderId, nextStatus);
            ref.invalidate(courierOrdersProvider);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  nextStatus == 'confirmed'
                      ? 'Préparation signalée au client.'
                      : 'Livraison en cours — le client est notifié.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur : $e')),
            );
          }
        },
        icon: Icon(icon),
        label: Text(label),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accepted ? Colors.green.shade200 : DjassaTheme.borderMedium,
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
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accepted
                      ? Colors.green.shade50
                      : DjassaTheme.accentOrange.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  accepted
                      ? _statusLabel(order.status).toUpperCase()
                      : 'NOUVELLE',
                  style: TextStyle(
                    color: accepted
                        ? Colors.green.shade700
                        : DjassaTheme.accentOrange,
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
          const SizedBox(height: 12),
          Text(
            order.deliveryAddress.isEmpty
                ? 'Adresse non renseignée'
                : order.deliveryAddress,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _InfoLine(icon: Icons.person_rounded, text: order.customerName),
          if (order.customerPhone.isNotEmpty)
            _InfoLine(icon: Icons.phone_rounded, text: order.customerPhone),
          _InfoLine(
            icon: Icons.shopping_bag_rounded,
            text:
                '${order.itemsCount} article(s) - ${formatPrice(order.total)}',
          ),
          _InfoLine(icon: Icons.info_rounded, text: _statusLabel(order.status)),
          if (accepted && order.status == 'courier_assigned') ...[
            const SizedBox(height: 12),
            _CourierStatusButton(
              label: 'Préparation terminée',
              icon: Icons.inventory_2_rounded,
              color: DjassaTheme.accentOrange,
              orderId: order.id,
              nextStatus: 'confirmed',
            ),
          ] else if (accepted && order.status == 'confirmed') ...[
            const SizedBox(height: 12),
            _CourierStatusButton(
              label: 'En cours de livraison',
              icon: Icons.delivery_dining_rounded,
              color: const Color(0xFF1E88E5),
              orderId: order.id,
              nextStatus: 'shipping',
            ),
          ] else if (!accepted) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRefuse,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: profileComplete
                          ? DjassaTheme.accentOrange
                          : Colors.grey.shade400,
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
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: DjassaTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _DarkInfoLine extends StatelessWidget {
  const _DarkInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DjassaTheme.accentOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: DjassaTheme.primaryWhite.withValues(alpha: .76),
              ),
            ),
          ),
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

class _EmptyCourierOrders extends StatelessWidget {
  const _EmptyCourierOrders();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.inbox_rounded,
      title: 'Aucune nouvelle commande',
      message: 'Patientez, les prochaines commandes apparaîtront ici.',
    );
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DjassaTheme.borderMedium),
      ),
      child: Column(
        children: [
          Icon(icon, size: 54, color: DjassaTheme.accentOrange),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "Impossible de charger l'espace livreur.\n$message",
          textAlign: TextAlign.center,
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
