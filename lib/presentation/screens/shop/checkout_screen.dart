import 'package:djassa/presentation/screens/shop/shop_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../providers/auth_provider.dart'; // Assure-toi que ce chemin est bon
import '../../providers/core_providers.dart';
import '../../widgets/shop/delivery_tracking_widgets.dart';
import '../../widgets/shop/payment_ui.dart';
import '../../widgets/shop/shop_widgets.dart';

// Enum pour les méthodes de paiement
enum PaymentMethod { wave, om, mtn, moov }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isProcessing = false;
  
  // Gestion Téléphone
  final _phoneController = TextEditingController();
  bool _isEditingPhone = false;

  // Gestion Paiement
  PaymentMethod _selectedPayment = PaymentMethod.wave; // Défaut Wave

  @override
  void initState() {
    super.initState();
    // Initialiser le contrôleur avec le numéro de l'utilisateur
    // Note: On utilise ref.read ici car c'est une valeur initiale statique
    final user = ref.read(authNotifierProvider).user;
    if (user?.phone != null && user!.phone!.isNotEmpty) {
      _phoneController.text = user.phone!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String friendlyMessage) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(friendlyMessage, style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    final raw = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Erreur inattendue.';
    final isTechnical = raw.contains('FunctionException') || 
                        raw.contains('PostgrestException') || 
                        raw.contains('SocketException');
    if (isTechnical) return 'Échec du paiement. Veuillez vérifier votre connexion et réessayer.';
    return raw;
  }

  // Helper pour obtenir le nom lisible du paiement
  String get _paymentName {
    switch (_selectedPayment) {
      case PaymentMethod.wave: return 'Wave';
      case PaymentMethod.om: return 'Orange Money';
      case PaymentMethod.mtn: return 'MTN Mobile Money';
      case PaymentMethod.moov: return 'Moov Money';
    }
  }

  // Helper pour construire l'adresse complète
  String get _displayAddress {
    // On utilise ref.watch ici car c'est dans un getter appelé pendant le build
    final savedAddress = ref.watch(savedDeliveryAddressProvider);
    if (savedAddress == null) return '';
    
    final commune = savedAddress.commune;
    final city = savedAddress.city;
    
    if (commune != null && commune.isNotEmpty) {
      return '$commune, $city';
    }
    return city;
  }

  // ✅ Validation stricte du téléphone
  bool _isValidPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    // Accepte +225... ou 07... (8 à 15 chiffres)
    return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(clean);
  }

  Future<void> _confirmOrder() async {
    // ✅ PROTECTION Idempotence : empêche les doubles appels
    if (_isProcessing) return;

    // Utilisation de ref.read pour les actions ponctuelles
    final user = ref.read(authNotifierProvider).user;
    final lines = ref.read(cartProvider);
    final phoneToUse = _phoneController.text.trim();
    
    // Utilisation de ref.watch pour lire l'état actuel dans une méthode async
    // Note: Dans une méthode async, il est souvent préférable de passer les données en argument
    // ou de les lire avant le premier await. Ici, on lit l'adresse avant les awaits lourds.
    final savedAddress = ref.read(savedDeliveryAddressProvider); 

    if (user == null) { 
      context.go(AppConstants.loginRoute); 
      return; 
    }
    if (lines.isEmpty) { 
      context.go(AppConstants.cartRoute); 
      return; 
    }
    
    if (savedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter une adresse de livraison dans votre profil.')),
      );
      return;
    }

    if (phoneToUse.isEmpty || !_isValidPhone(phoneToUse)) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Numéro de téléphone invalide (ex: +225 07...).')),
       );
       return;
    }

    setState(() => _isProcessing = true);

    try {
      final deliveryAddressStr = _displayAddress;
      final trackingService = ref.read(deliveryTrackingServiceProvider);
      
      // Récupération position client
      final clientPosition = await trackingService.getCurrentClientPosition();

      // 1. Création du brouillon de commande
      final order = await ref.read(shopServiceProvider).createOrderDraft(
            lines: lines,
            customerName: user.fullName.trim().isEmpty ? 'Client Djassa' : user.fullName.trim(),
            customerPhone: phoneToUse,
            deliveryAddress: deliveryAddressStr,
            clientLatitude: clientPosition?.latitude,
            clientLongitude: clientPosition?.longitude,
          );

      final orderId = order['id'] as String;
      final total = (order['total'] as num?)?.toInt() ?? 0;
      final shortId = orderId.length > 6 ? orderId.substring(0, 6) : orderId;
      final orderNumber = order['order_number']?.toString() ?? 'DJ-$shortId';

      // 2. Démarrage du tracking local
      final trackingNotifier = ref.read(deliveryTrackingProvider.notifier);
      await trackingNotifier.start(
        orderId: orderId, 
        orderNumber: orderNumber, 
        address: deliveryAddressStr,
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

      // 3. Nettoyage du panier et refresh des commandes
      ref.invalidate(ordersProvider);
      ref.read(cartProvider.notifier).clear();

      if (!mounted) return;

      // 4. Création du paiement via le service
      final payment = await ref.read(shopServiceProvider).createPayment(
            orderId: orderId,
            amount: total,
            provider: _paymentName.toLowerCase().replaceAll(' ', ''), 
            customerPhone: phoneToUse,
            customerName: user.fullName.trim().isEmpty ? 'Client Djassa' : user.fullName.trim(),
          );

      final checkoutUrl = payment['checkout_url'] as String;
      final reference = payment['reference'] as String? ?? orderId;

      if (!mounted) return;

      // 5. Ouverture de l'interface de paiement
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
                  Icon(Icons.check_circle_rounded, color: Colors.white), 
                  SizedBox(width: 10), 
                  Text('Paiement réussi !', style: TextStyle(color: Colors.white))
                ]
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
          context.go(AppConstants.ordersRoute);
        },
        onPaymentFailed: () {
          if (!mounted) return;
          _showErrorSnackBar('Paiement échoué ou annulé.');
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
    // ✅ Utilisation du provider défini dans core_providers.dart
    final deliveryFee = ref.watch(deliveryFeeProvider);
    
    final subtotal = lines.fold<int>(0, (sum, line) => sum + line.product.price * line.quantity);
    final total = subtotal + deliveryFee;
    
    final user = ref.watch(authNotifierProvider).user;
    
    // Récupération de l'adresse sauvegardée pour l'affichage
    final savedAddress = ref.watch(savedDeliveryAddressProvider);
    final addressString = _displayAddress;

    return ShopScaffold(
      showSellButton: false,
      currentIndex: 2,
      title: 'Commande',
      showBackButton: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finaliser la commande', 
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900, 
                color: DjassaTheme.primaryBlack
              )
            ),
            const SizedBox(height: 20),

            // ── 1. ADRESSE DE LIVRAISON (LECTURE SEULE) ───────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(24), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8), 
                            decoration: BoxDecoration(
                              color: DjassaTheme.accentOrange.withOpacity(0.1), 
                              borderRadius: BorderRadius.circular(12)
                            ), 
                            child: const Icon(Icons.location_on_rounded, color: DjassaTheme.accentOrange, size: 24)
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Adresse de livraison', 
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => context.push('/profile'), 
                        child: const Text('Modifier', style: TextStyle(fontSize: 12)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (savedAddress != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200)
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home_rounded, color: Colors.grey, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              addressString,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.shade200)
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Aucune adresse enregistrée. Veuillez en ajouter une dans votre profil.',
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 2. CONTACT (MODIFIABLE) ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(24), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8), 
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50, 
                              borderRadius: BorderRadius.circular(12)
                            ), 
                            child: const Icon(Icons.phone_rounded, color: Colors.blue, size: 24)
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Numéro de contact', 
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () { 
                          setState(() { 
                            _isEditingPhone = !_isEditingPhone; 
                            if (!_isEditingPhone) {
                              _phoneController.text = user?.phone ?? ''; 
                            }
                          }); 
                        }, 
                        child: Text(_isEditingPhone ? 'Annuler' : 'Modifier')
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _isEditingPhone 
                  ? TextFormField(
                      controller: _phoneController, 
                      keyboardType: TextInputType.phone, 
                      decoration: InputDecoration(
                        hintText: 'Ex: 07 01 02 03 04', 
                        prefixIcon: const Icon(Icons.phone_iphone, color: Colors.grey), 
                        filled: true, 
                        fillColor: const Color(0xFFF5F5F7), 
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14), 
                          borderSide: BorderSide.none
                        ), 
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                      )
                    )
                  : Container(
                      width: double.infinity, 
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7), 
                        borderRadius: BorderRadius.circular(14)
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_iphone, color: Colors.grey, size: 20), 
                          const SizedBox(width: 10), 
                          Text(
                            _phoneController.text.isEmpty ? 'Non renseigné' : _phoneController.text, 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)
                          )
                        ]
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 3. PAIEMENT (INTERACTIF) ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(24), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50, 
                          borderRadius: BorderRadius.circular(12)
                        ), 
                        child: const Icon(Icons.payment_rounded, color: Colors.purple, size: 24)
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Moyen de paiement', 
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Grille de sélection
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.5,
                    children: [
                      _PaymentOption(method: PaymentMethod.wave, isSelected: _selectedPayment == PaymentMethod.wave, onTap: () => setState(() => _selectedPayment = PaymentMethod.wave)),
                      _PaymentOption(method: PaymentMethod.om, isSelected: _selectedPayment == PaymentMethod.om, onTap: () => setState(() => _selectedPayment = PaymentMethod.om)),
                      _PaymentOption(method: PaymentMethod.mtn, isSelected: _selectedPayment == PaymentMethod.mtn, onTap: () => setState(() => _selectedPayment = PaymentMethod.mtn)),
                      _PaymentOption(method: PaymentMethod.moov, isSelected: _selectedPayment == PaymentMethod.moov, onTap: () => setState(() => _selectedPayment = PaymentMethod.moov)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── FOOTER TOTAL & BOUTON ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DjassaTheme.primaryBlack, 
                borderRadius: BorderRadius.circular(30), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 10))]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Text('Total à payer', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(formatPrice(total), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        ]
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(20)
                        ), 
                        child: Text(
                          '${lines.length} article${lines.length > 1 ? 's' : ''}', 
                          style: const TextStyle(color: Colors.white, fontSize: 12)
                        )
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, 
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: DjassaTheme.accentOrange, 
                        foregroundColor: Colors.white, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                        elevation: 0
                      ),
                      // Désactiver si traitement en cours, panier vide ou pas d'adresse
                      onPressed: _isProcessing || lines.isEmpty || savedAddress == null 
                        ? null 
                        : _confirmOrder,
                      icon: _isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) 
                        : const Icon(Icons.lock_outline_rounded, size: 20),
                      label: Text(
                        _isProcessing ? 'Traitement...' : 'Payer maintenant', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// Widget pour les options de paiement
class _PaymentOption extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({required this.method, required this.isSelected, required this.onTap});

  IconData get _icon {
    switch (method) {
      case PaymentMethod.wave: return Icons.waves_rounded;
      case PaymentMethod.om: return Icons.circle_rounded; // Remplacer par logo Orange si disponible
      case PaymentMethod.mtn: return Icons.circle_rounded; // Remplacer par logo MTN si disponible
      case PaymentMethod.moov: return Icons.circle_rounded; // Remplacer par logo Moov si disponible
    }
  }

  Color get _color {
    switch (method) {
      case PaymentMethod.wave: return const Color(0xFF1DC4FF);
      case PaymentMethod.om: return const Color(0xFFFF7900);
      case PaymentMethod.mtn: return const Color(0xFFFFCC00);
      case PaymentMethod.moov: return const Color(0xFF0068B3);
    }
  }

  String get _label {
    switch (method) {
      case PaymentMethod.wave: return 'Wave';
      case PaymentMethod.om: return 'Orange';
      case PaymentMethod.mtn: return 'MTN';
      case PaymentMethod.moov: return 'Moov';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? _color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _color : Colors.transparent, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, color: isSelected ? _color : Colors.grey, size: 20),
            const SizedBox(width: 6),
            Text(
              _label, 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: isSelected ? _color : Colors.grey.shade700, 
                fontSize: 12
              )
            ),
          ],
        ),
      ),
    );
  }
}