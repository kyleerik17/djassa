import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../data/services/delivery_tracking_service.dart';
import '../../providers/core_providers.dart';

String formatDeliveryDate(DateTime value) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  final month = months[value.month - 1];
  return '${value.day} $month ${value.year} à '
      '${value.hour.toString().padLeft(2, '0')}h';
}

Future<void> showDeliveryStageDialog(
  BuildContext context, {
  required DeliveryTracking tracking,
  required DeliveryTrackingStage stage,
}) {
  final content = _stageContent(stage, tracking);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black.withValues(alpha: .46),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, _, __) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.sizeOf(context).width - 36,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: DjassaTheme.primaryWhite,
            borderRadius: BorderRadius.circular(30),
            boxShadow: DjassaTheme.shadowHeavy,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedStageIcon(icon: content.icon, color: content.color),
              const SizedBox(height: 18),
              Text(
                content.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                content.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DjassaTheme.primaryBlack.withValues(alpha: .62),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _DialogTimeline(currentStage: stage),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: DjassaTheme.accentOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Compris'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .88, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class DeliveryTrackingCard extends StatelessWidget {
  const DeliveryTrackingCard({
    super.key,
    required this.tracking,
    required this.stage,
    required this.now,
    this.snapshot,
    this.clientGpsStatus,
    this.onTap,
  });

  final DeliveryTracking tracking;
  final DeliveryTrackingStage stage;
  final DateTime now;
  final DeliveryLiveSnapshot? snapshot;
  final DeliveryPositionPublishStatus? clientGpsStatus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = _stageContent(stage, tracking);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
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
                  backgroundColor:
                      DjassaTheme.accentOrange.withValues(alpha: .18),
                  child: Icon(content.icon, color: DjassaTheme.accentOrange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suivi ${tracking.orderNumber}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: DjassaTheme.primaryWhite,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        content.title,
                        style: TextStyle(
                          color:
                              DjassaTheme.primaryWhite.withValues(alpha: .68),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.touch_app_rounded,
                  color: DjassaTheme.primaryWhite,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            RealtimeDeliveryMap(
              tracking: tracking,
              snapshot: snapshot ??
                  DeliveryTrackingService.fallbackSnapshot(
                    DeliveryTrackingQuery(
                      orderId: tracking.orderId,
                      address: tracking.address,
                      createdAt: tracking.createdAt,
                      deliveryAt: tracking.deliveryAt,
                      clientLatitude: tracking.clientLatitude,
                      clientLongitude: tracking.clientLongitude,
                    ),
                    now,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  color: DjassaTheme.accentOrange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Livraison prévue le ${formatDeliveryDate(tracking.deliveryAt)}',
                    style: TextStyle(
                      color: DjassaTheme.primaryWhite.withValues(alpha: .78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tracking.address,
              style: TextStyle(
                color: DjassaTheme.primaryWhite.withValues(alpha: .62),
              ),
            ),
            const SizedBox(height: 10),
            _RealtimeLegend(
              snapshot: snapshot,
              clientGpsStatus: clientGpsStatus,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 360.ms).slideY(begin: .08, end: 0);
  }
}

class RealtimeDeliveryMap extends StatelessWidget {
  const RealtimeDeliveryMap({
    super.key,
    required this.tracking,
    required this.snapshot,
  });

  final DeliveryTracking tracking;
  final DeliveryLiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final client = snapshot.client.position;
    final courier = snapshot.courier.position;
    final center = LatLng(
      (client.latitude + courier.latitude) / 2,
      (client.longitude + courier.longitude) / 2,
    );

    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(24),
      ),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 12.4,
          minZoom: 10,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.djassa.app',
            retinaMode: RetinaMode.isHighDensity(context),
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [courier, client],
                color: DjassaTheme.accentOrange,
                strokeWidth: 4,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: courier,
                width: 112,
                height: 74,
                child: const _MapMarker(
                  icon: Icons.delivery_dining_rounded,
                  label: 'Livreur',
                  color: DjassaTheme.accentOrange,
                  pulse: true,
                ),
              ),
              Marker(
                point: client,
                width: 112,
                height: 74,
                child: const _MapMarker(
                  icon: Icons.person_pin_circle_rounded,
                  label: 'Client',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: DjassaTheme.primaryWhite.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(999),
                boxShadow: DjassaTheme.shadowLight,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_rounded,
                    size: 14,
                    color: DjassaTheme.accentOrange,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'OpenStreetMap',
                    style: TextStyle(
                      color: DjassaTheme.primaryBlack.withValues(alpha: .72),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.icon,
    required this.label,
    required this.color,
    this.pulse = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .36),
            blurRadius: 18,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pulse
            ? iconWidget
                .animate(
                    onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                  begin: const Offset(.92, .92),
                  end: const Offset(1.08, 1.08),
                  duration: 850.ms,
                )
            : iconWidget,
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _RealtimeLegend extends StatelessWidget {
  const _RealtimeLegend({
    required this.snapshot,
    required this.clientGpsStatus,
  });

  final DeliveryLiveSnapshot? snapshot;
  final DeliveryPositionPublishStatus? clientGpsStatus;

  @override
  Widget build(BuildContext context) {
    final courierLive = snapshot?.hasCourierRealtime ?? false;
    final clientLive =
        clientGpsStatus?.isLive ?? snapshot?.hasClientRealtime ?? false;
    return Row(
      children: [
        _LiveChip(
          label: courierLive ? 'GPS livreur live' : 'GPS livreur en attente',
          color: courierLive ? Colors.green : DjassaTheme.accentOrange,
        ),
        const SizedBox(width: 8),
        _LiveChip(
          label: clientLive ? 'Mon GPS live' : 'Adresse estimée',
          color: clientLive ? Colors.green : Colors.blueGrey,
        ),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({
    required this.label,
    required this.color,
  });

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class DeliveryFlowInfoCard extends StatelessWidget {
  const DeliveryFlowInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        icon: Icons.receipt_long_rounded,
        title: 'Commande créée',
        text: 'Les articles du panier sont enregistrés avec votre adresse.',
      ),
      (
        icon: Icons.inventory_2_rounded,
        title: 'Préparation boutique',
        text: 'L’équipe vérifie le paiement, rassemble les pièces et emballe.',
      ),
      (
        icon: Icons.delivery_dining_rounded,
        title: 'Remise au livreur',
        text: 'Le livreur récupère le colis puis active son GPS livreur.',
      ),
      (
        icon: Icons.map_rounded,
        title: 'Suivi live',
        text: 'Vous voyez le livreur et votre position sur OpenStreetMap.',
      ),
    ];

    return Container(
      width: double.infinity,
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
                backgroundColor: Colors.blue.withValues(alpha: .12),
                child: const Icon(Icons.route_rounded, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Comment se passe la livraison ?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.indexed.map((entry) {
            final index = entry.$1;
            final step = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == steps.length - 1 ? 0 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: DjassaTheme.accentOrange.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      step.icon,
                      size: 18,
                      color: DjassaTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.text,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DjassaTheme.primaryBlack
                                        .withValues(alpha: .62),
                                    height: 1.32,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AnimatedStageIcon extends StatelessWidget {
  const _AnimatedStageIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 38),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
          begin: const Offset(.92, .92),
          end: const Offset(1.05, 1.05),
          duration: 780.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _DialogTimeline extends StatelessWidget {
  const _DialogTimeline({required this.currentStage});

  final DeliveryTrackingStage currentStage;

  @override
  Widget build(BuildContext context) {
    const stages = DeliveryTrackingStage.values;
    final currentIndex = stages.indexOf(currentStage);

    return Row(
      children: List.generate(stages.length, (index) {
        final isDone = index <= currentIndex;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            height: 8,
            margin: EdgeInsets.only(right: index == stages.length - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color:
                  isDone ? DjassaTheme.accentOrange : DjassaTheme.borderMedium,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

_StageContent _stageContent(
  DeliveryTrackingStage stage,
  DeliveryTracking tracking,
) {
  switch (stage) {
    case DeliveryTrackingStage.created:
      return _StageContent(
        icon: Icons.check_circle_rounded,
        color: DjassaTheme.accentOrange,
        title: 'Commande créée',
        message:
            'Votre commande ${tracking.orderNumber} est enregistrée. Après paiement, l’équipe prépare les articles puis assigne un livreur.',
      );
    case DeliveryTrackingStage.scheduled:
      return _StageContent(
        icon: Icons.event_available_rounded,
        color: DjassaTheme.accentOrange,
        title: 'Livraison prévue le ${formatDeliveryDate(tracking.deliveryAt)}',
        message:
            'Le livreur reçoit le colis préparé et partagera sa position GPS dès le départ vers ${tracking.address}.',
      );
    case DeliveryTrackingStage.shipping:
      return const _StageContent(
        icon: Icons.delivery_dining_rounded,
        color: Colors.blue,
        title: 'Commande en cours de livraison',
        message:
            'Le livreur partage sa vraie position GPS. Gardez votre téléphone disponible pour faciliter la remise.',
      );
    case DeliveryTrackingStage.delivered:
      return const _StageContent(
        icon: Icons.verified_rounded,
        color: Colors.green,
        title: 'Commande livrée',
        message:
            'Merci pour votre achat. La carte de suivi disparaît maintenant de l’accueil.',
      );
  }
}

class _StageContent {
  const _StageContent({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
}
