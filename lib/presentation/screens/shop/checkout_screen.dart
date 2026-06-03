import 'package:djassa/presentation/screens/shop/shop_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/delivery_tracking_widgets.dart';
import '../../widgets/shop/payment_ui.dart';
import '../../widgets/shop/shop_widgets.dart';

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

  void _showErrorSnackBar(String friendlyMessage) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  friendlyMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Réessayer',
            textColor: Colors.white,
            onPressed: _confirmOrder,
          ),
        ),
      );
  }

  String _friendlyMessage(Object e) {
    final raw = e is Exception
        ? e.toString().replaceFirst('Exception: ', '')
        : 'Erreur inattendue. Veuillez réessayer.';

    final isTechnical = raw.contains('FunctionException') ||
        raw.contains('PostgrestException') ||
        raw.contains('status:') ||
        raw.contains('reasonPhrase') ||
        raw.contains('SocketException') ||
        raw.contains('HttpException');

    if (isTechnical) {
      return 'Échec du paiement. Veuillez réessayer ou choisir '
          'un autre moyen de paiement.';
    }
    return raw;
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

    setState(() => _isProcessing = true);

    try {
      // 1. Sauvegarde adresse
      await ref
          .read(savedDeliveryAddressProvider.notifier)
          .save(_selectedCity!, _selectedCommune!);

      // 2. Position client pour le tracking
      final trackingService = ref.read(deliveryTrackingServiceProvider);
      final clientPosition = await trackingService.getCurrentClientPosition();

      // 3. Crée la commande Djassa (brouillon)
      final order = await ref.read(shopServiceProvider).createOrderDraft(
            lines: lines,
            customerName: user.fullName.trim().isEmpty
                ? 'Client Djassa'
                : user.fullName.trim(),
            customerPhone: user.phone,
            deliveryAddress: _deliveryAddress,
            clientLatitude: clientPosition?.latitude,
            clientLongitude: clientPosition?.longitude,
          );

      final orderId = order['id'] as String;
      final total = (order['total'] as num?)?.toInt() ?? 0;
      final shortId = orderId.length > 6 ? orderId.substring(0, 6) : orderId;
      final orderNumber = order['order_number']?.toString() ?? 'DJ-$shortId';

      // 4. Démarre le tracking livraison
      final trackingNotifier = ref.read(deliveryTrackingProvider.notifier);
      await trackingNotifier.start(
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

      ref.invalidate(ordersProvider);
      ref.read(cartProvider.notifier).clear();

      if (!mounted) return;

      // 5. Crée la transaction GeniusPay via la Supabase Edge Function
      final payment = await ref.read(shopServiceProvider).createPayment(
            orderId: orderId,
            amount: total,
            provider: 'checkout',
            customerPhone: user.phone,
            customerName: user.fullName.trim().isEmpty
                ? 'Client Djassa'
                : user.fullName.trim(),
          );

      final checkoutUrl = payment['checkout_url'] as String;
      final reference = payment['reference'] as String? ?? orderId;

      if (!mounted) return;

      // 6. Ouvre la WebView GeniusPay
      await openOrderPayment(
        context,
        checkoutUrl: checkoutUrl,
        reference: reference,
        onPaymentSuccess: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Paiement réussi !',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
          context.go('/orders');
        },
        onPaymentFailed: () {
          if (!mounted) return;
          _showErrorSnackBar(
            'Paiement échoué ou annulé. '
            'Vous pouvez réessayer depuis vos commandes.',
          );
        },
      );
    } catch (e) {
      _showErrorSnackBar(_friendlyMessage(e));
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

          // ── Bloc adresse ──────────────────────────────────────────────
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

          // ── Bouton payer ──────────────────────────────────────────────
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
