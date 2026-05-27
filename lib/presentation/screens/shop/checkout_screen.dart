import 'package:djassa/presentation/screens/shop/shop_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/delivery_tracking_widgets.dart';
import '../../widgets/shop/shop_widgets.dart';

/// Opérateurs Mobile Money disponibles
const List<Map<String, String>> _providers = [
  {'label': 'Wave', 'value': 'wave', 'icon': '🌊'},
  {'label': 'Orange Money', 'value': 'orange_money', 'icon': '🟠'},
  {'label': 'MTN Money', 'value': 'mtn_money', 'icon': '🟡'},
  {'label': 'Moov Money', 'value': 'moov_money', 'icon': '🔵'},
];

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isProcessing = false;
  String? _selectedCity;
  String? _selectedCommune;
  bool _showAddressError = false;

  List<String> get _availableCommunes =>
      _selectedCity != null ? deliveryCitiesCommunes[_selectedCity!] ?? [] : [];

  String get _deliveryAddress {
    if (_selectedCity == null) return '';
    if (_selectedCommune == null) return _selectedCity!;
    return '$_selectedCommune, $_selectedCity';
  }

  bool get _addressComplete =>
      _selectedCity != null && _selectedCommune != null;

  @override
  void initState() {
    super.initState();
    final savedAddress = ref.read(savedDeliveryAddressProvider);
    _selectedCity = savedAddress?.city;
    _selectedCommune = savedAddress?.commune;
  }

  Future<void> _showTrackingDialog(
    DeliveryTracking tracking,
    DeliveryTrackingStage stage,
  ) {
    if (!mounted) return Future<void>.value();
    return showDeliveryStageDialog(
      context,
      tracking: tracking,
      stage: stage,
    );
  }

  /// Dialog pour choisir l'opérateur et saisir le numéro Mobile Money
  Future<Map<String, String>?> _askPaymentInfo(String? prefilled) async {
    final controller = TextEditingController(text: prefilled ?? '');
    String selectedProvider = 'wave';

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    DjassaTheme.accentOrange.withValues(alpha: .12),
                child: const Icon(
                  Icons.phone_rounded,
                  color: DjassaTheme.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Paiement Mobile Money')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisissez votre opérateur et entrez le numéro à débiter.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Sélection de l'opérateur
              const Text(
                'Opérateur',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _providers.map((p) {
                  final isSelected = selectedProvider == p['value'];
                  return GestureDetector(
                    onTap: () =>
                        setStateDialog(() => selectedProvider = p['value']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DjassaTheme.accentOrange.withValues(alpha: .12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? DjassaTheme.accentOrange
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '${p['icon']}  ${p['label']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.normal,
                          color: isSelected
                              ? DjassaTheme.accentOrange
                              : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Numéro de téléphone
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  hintText: 'Ex: 07 00 00 00 00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: DjassaTheme.accentOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final phone = controller.text.trim();
                if (phone.length < 8) return;
                Navigator.of(ctx).pop({
                  'phone': phone,
                  'provider': selectedProvider,
                });
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOrder() async {
    final user = ref.read(authNotifierProvider).user;
    final lines = ref.read(cartProvider);

    if (user == null) {
      context.go('/login');
      return;
    }

    if (lines.isEmpty) {
      context.go('/cart');
      return;
    }

    if (!_addressComplete) {
      setState(() => _showAddressError = true);
      return;
    }

    // 1. Demander opérateur + numéro Mobile Money
    final paymentInfo = await _askPaymentInfo(user.phone);
    if (paymentInfo == null || !mounted) return;

    final phone = paymentInfo['phone']!;
    final provider = paymentInfo['provider']!;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(savedDeliveryAddressProvider.notifier)
          .save(_selectedCity!, _selectedCommune!);
      final trackingService = ref.read(deliveryTrackingServiceProvider);
      final clientPosition = await trackingService.getCurrentClientPosition();

      // 2. Créer la commande
      final order = await ref.read(shopServiceProvider).createOrderDraft(
            lines: lines,
            customerName: user.fullName.trim().isEmpty
                ? 'Client Djassa'
                : user.fullName.trim(),
            customerPhone: phone,
            deliveryAddress: _deliveryAddress,
          );

      final orderId = order['id'] as String;
      final total = order['total'] as int;
      final shortId = orderId.length > 6 ? orderId.substring(0, 6) : orderId;
      final orderNumber = order['order_number']?.toString() ?? 'DJ-$shortId';

      // 3. Créer le paiement GeniusPay
      final payment = await ref.read(shopServiceProvider).createPayment(
            orderId: orderId,
            amount: total,
            provider: provider, // ✅ paramètre requis
            customerPhone: phone,
            customerName:
                user.fullName.trim().isEmpty ? null : user.fullName.trim(),
          );

      final checkoutUrl = payment['checkout_url'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('URL de paiement introuvable.');
      }

      final trackingNotifier = ref.read(deliveryTrackingProvider.notifier);
      final tracking = await trackingNotifier.start(
        orderId: orderId,
        orderNumber: orderNumber,
        address: _deliveryAddress,
        clientLatitude: clientPosition?.latitude,
        clientLongitude: clientPosition?.longitude,
      );
      if (clientPosition != null) {
        await trackingService.upsertPosition(
          orderId: orderId,
          role: 'client',
          position: clientPosition,
        );
      }

      // 4. Vider le panier, rafraîchir les commandes et annoncer les étapes
      ref.invalidate(ordersProvider);
      ref.read(cartProvider.notifier).clear();

      await trackingNotifier.markStageAnnounced(
        orderId,
        DeliveryTrackingStage.created,
      );
      await _showTrackingDialog(tracking, DeliveryTrackingStage.created);

      await trackingNotifier.markStageAnnounced(
        orderId,
        DeliveryTrackingStage.scheduled,
      );
      await _showTrackingDialog(tracking, DeliveryTrackingStage.scheduled);

      // 5. Ouvrir l'URL de paiement
      final uri = Uri.parse(checkoutUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Impossible d\'ouvrir la page de paiement.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Page de paiement ouverte. Revenez après confirmation.'),
        ),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final subtotal = lines.fold<int>(
      0,
      (sum, line) => sum + line.product.price * line.quantity,
    );
    final deliveryFee = ref.watch(deliveryFeeProvider);
    final total = subtotal + deliveryFee;

    return ShopScaffold(
      currentIndex: 2,
      title: 'Commande',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Finaliser la commande'),
          const SizedBox(height: 12),

          // Bloc adresse avec dropdowns
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DjassaTheme.primaryWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _showAddressError && !_addressComplete
                    ? Colors.red.shade300
                    : DjassaTheme.borderMedium,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    Text(
                      'Adresse de livraison',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Dropdown ville
                DropdownButtonFormField<String>(
                  initialValue: _selectedCity,
                  decoration: InputDecoration(
                    labelText: 'Ville',
                    prefixIcon: const Icon(Icons.location_city_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  hint: const Text('Sélectionner une ville'),
                  items: deliveryCitiesCommunes.keys
                      .map((city) => DropdownMenuItem(
                            value: city,
                            child: Text(city),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCity = value;
                      _selectedCommune = null;
                      _showAddressError = false;
                    });
                  },
                ),

                const SizedBox(height: 12),

                // Dropdown commune
                DropdownButtonFormField<String>(
                  initialValue: _selectedCommune,
                  decoration: InputDecoration(
                    labelText: 'Commune',
                    prefixIcon: const Icon(Icons.map_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  hint: Text(
                    _selectedCity == null
                        ? 'Choisir une ville d\'abord'
                        : 'Sélectionner une commune',
                  ),
                  items: _availableCommunes
                      .map((commune) => DropdownMenuItem(
                            value: commune,
                            child: Text(commune),
                          ))
                      .toList(),
                  onChanged: _selectedCity == null
                      ? null
                      : (value) {
                          setState(() {
                            _selectedCommune = value;
                            _showAddressError = false;
                          });
                        },
                ),

                if (_showAddressError && !_addressComplete) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Veuillez sélectionner une ville et une commune',
                    style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                  ),
                ],

                if (_addressComplete) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.green.shade600, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _deliveryAddress,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          _CheckoutBlock(
            icon: Icons.payments_rounded,
            title: 'Paiement',
            content: 'Wave · Orange Money · MTN · Moov',
            action: '',
            onTap: () {},
          ),
          _CheckoutBlock(
            icon: Icons.verified_rounded,
            title: 'Vérification',
            content: 'Nos équipes confirment les détails avant envoi.',
            action: '',
            onTap: () {},
          ),
          const DeliveryFlowInfoCard(),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: DjassaTheme.primaryBlack,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total à payer',
                        style: TextStyle(
                          color:
                              DjassaTheme.primaryWhite.withValues(alpha: .72),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatPrice(total),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: DjassaTheme.primaryWhite,
                              fontSize: 22,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: DjassaTheme.accentOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed:
                      _isProcessing || lines.isEmpty ? null : _confirmOrder,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.open_in_browser_rounded),
                  label: Text(_isProcessing ? 'Traitement...' : 'Payer'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _CheckoutBlock extends StatelessWidget {
  const _CheckoutBlock({
    required this.icon,
    required this.title,
    required this.content,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String content;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: DjassaTheme.borderMedium),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .12),
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
                  const SizedBox(height: 4),
                  Text(content),
                ],
              ),
            ),
            if (action.isNotEmpty)
              TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
