import 'package:djassa/presentation/screens/vendor/vendor_balance_adapter.dart';
import 'package:djassa/presentation/screens/vendor/vendor_edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/shared/logout_confirmation_sheet.dart';
import '../../widgets/vendor/vendor_scaffold.dart';

// ---------------------------------------------------------------------------
// Design Tokens
// ---------------------------------------------------------------------------
class _Radius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
}

class _Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Écran principal du compte vendeur (Design Dashboard Moderne)
class VendorAccountScreen extends ConsumerWidget {
  const VendorAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;

    if (user == null || !user.isVendor) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go(AppConstants.loginRoute),
            child: const Text('Se connecter'),
          ),
        ),
      );
    }

    return VendorScaffold(
      currentIndex: 2,
      title: 'Compte vendeur',
      body: ListView(
        padding:
            const EdgeInsets.symmetric(horizontal: _Gap.lg, vertical: _Gap.md),
        children: [
          // 1. Header Profil (Style Carte Intégrée)
          _ProfileHeader(user: user),

          const SizedBox(height: _Gap.xl),

          // 2. Section Mon Solde (Point Focal)
          const VendorBalanceSection(),

          const SizedBox(height: _Gap.xl),

          // 3. Menu Actions Rapides
          _ActionMenu(user: user),

          const SizedBox(height: _Gap.xl),

          // 4. Déconnexion
          _LogoutButton(ref: ref),

          const SizedBox(height: _Gap.xl), // Espace pour la bottom bar
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// WIDGETS UI
// ─────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar avec Hero Animation
          Hero(
            tag: 'vendor_avatar_${user.id}',
            child: CircleAvatar(
              radius: 32,
              backgroundColor: DjassaTheme.vendorSoft,
              backgroundImage:
                  (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                      ? NetworkImage(user.avatarUrl!)
                      : null,
              child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                  ? const Icon(Icons.storefront_rounded,
                      color: DjassaTheme.vendorPrimary, size: 32)
                  : null,
            ),
          ),
          const SizedBox(width: _Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.name ?? ''} ${user.surname ?? ''}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email ?? 'Email non renseigné',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Bouton Modifier Rapide
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.grey),
            onPressed: () => _navigateToEditProfile(context),
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context) {
    // Transition native simple et efficace
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VendorEditProfileScreen()),
    );
  }
}

class VendorBalanceSection extends ConsumerWidget {
  const VendorBalanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(balanceFilterProvider);
    final balanceAsync = ref.watch(vendorBalanceProvider(filterState));

    return Container(
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mon Solde',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              _PeriodFilterButton(),
            ],
          ),
          const SizedBox(height: _Gap.lg),
          balanceAsync.when(
            data: (data) => _BalanceContent(data: data),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'Erreur de chargement',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceContent extends StatelessWidget {
  final VendorBalanceData data;
  const _BalanceContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Carte Principale : Solde Disponible (Dégradé Noir/Orange subtil)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_Gap.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [DjassaTheme.vendorDark, DjassaTheme.vendorPrimary],
            ),
            borderRadius: BorderRadius.circular(_Radius.md),
            boxShadow: [
              BoxShadow(
                color: DjassaTheme.vendorPrimary.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Disponible',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white.withOpacity(0.7), size: 18),
                ],
              ),
              const SizedBox(height: _Gap.xs),
              Text(
                '${data.availableBalance.toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(height: _Gap.md),

        // Stats Secondaires
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'En attente',
                value: '${data.pendingBalance.toStringAsFixed(0)}',
                icon: Icons.hourglass_empty_rounded,
                color: DjassaTheme.vendorPrimary,
              ),
            ),
            const SizedBox(width: _Gap.md),
            Expanded(
              child: _StatCard(
                label: 'Ventes totales',
                value: '${data.totalSales.toStringAsFixed(0)}',
                icon: Icons.trending_up_rounded,
                color: DjassaTheme.vendorDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_Gap.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(_Radius.sm),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          const Text('FCFA',
              style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _PeriodFilterButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(balanceFilterProvider);

    return PopupMenuButton<BalancePeriod>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_Radius.sm)),
      itemBuilder: (context) => [
        const PopupMenuItem(
            value: BalancePeriod.today, child: Text("Aujourd'hui")),
        const PopupMenuItem(
            value: BalancePeriod.days7, child: Text('7 derniers jours')),
        const PopupMenuItem(
            value: BalancePeriod.days30, child: Text('30 derniers jours')),
        const PopupMenuItem(
            value: BalancePeriod.custom, child: Text('Personnalisé')),
      ],
      onSelected: (period) {
        if (period == BalancePeriod.custom) {
          _pickCustomDate(context, ref);
        } else {
          ref.read(balanceFilterProvider.notifier).setPeriod(period);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: DjassaTheme.vendorSoft,
          borderRadius: BorderRadius.circular(_Radius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_rounded,
                size: 16, color: DjassaTheme.vendorPrimary),
            const SizedBox(width: 4),
            Text(
              _getPeriodLabel(state.period),
              style: const TextStyle(
                color: DjassaTheme.vendorPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel(BalancePeriod period) {
    switch (period) {
      case BalancePeriod.today:
        return "Auj.";
      case BalancePeriod.days7:
        return '7j';
      case BalancePeriod.days30:
        return '30j';
      case BalancePeriod.custom:
        return 'Perso.';
    }
  }

  Future<void> _pickCustomDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: DjassaTheme.vendorPrimary),
        ),
        child: child!,
      ),
    );
    if (start != null) {
      final end = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: start,
        lastDate: now,
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(primary: DjassaTheme.vendorPrimary),
          ),
          child: child!,
        ),
      );
      if (end != null) {
        ref.read(balanceFilterProvider.notifier).setCustomPeriod(start, end);
      }
    }
  }
}

class _ActionMenu extends StatelessWidget {
  final dynamic user;
  const _ActionMenu({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_Gap.lg),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(_Radius.lg),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.receipt_long_rounded,
            title: 'Historique des commandes',
            subtitle: 'Voir toutes vos ventes passées',
            onTap: () {}, // TODO: Navigation vers historique
          ),
          Divider(height: 24, color: Colors.grey.shade200),
          _MenuItem(
            icon: Icons.settings_rounded,
            title: 'Paramètres de la boutique',
            subtitle: 'Gérer les notifications et préférences',
            onTap: () {}, // TODO: Navigation vers paramètres
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_Radius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _Gap.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 20, color: DjassaTheme.vendorPrimary),
            ),
            const SizedBox(width: _Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  final WidgetRef ref;
  const _LogoutButton({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_Radius.sm)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        foregroundColor: const Color(0xFFE0453C),
        side: const BorderSide(color: Color(0xFFE0453C), width: 1.5),
      ),
      onPressed: () => _logout(context, ref),
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Déconnexion',
          style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  void _logout(BuildContext context, WidgetRef ref) {
    showLogoutConfirmationSheet(
      context,
      onConfirm: () async {
        await ref.read(authNotifierProvider.notifier).logoutUser();
        if (context.mounted) context.go(AppConstants.loginRoute);
      },
    );
  }
}
