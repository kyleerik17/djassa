import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../data/services/client_order_tracking_service.dart';
import '../../../data/services/delivery_tracking_service.dart';
import '../../../domain/order_progress.dart';
import '../../providers/core_providers.dart';
import 'delivery_tracking_widgets.dart';

/// Grande carte de suivi animée (profil / accueil client).
class OrderProgressTracker extends ConsumerStatefulWidget {
  const OrderProgressTracker({
    super.key,
    required this.order,
    this.compact = false,
    this.onStepCelebration,
  });

  final ClientActiveOrder order;
  final bool compact;
  final void Function(String newStatus)? onStepCelebration;

  @override
  ConsumerState<OrderProgressTracker> createState() =>
      _OrderProgressTrackerState();
}

class _OrderProgressTrackerState extends ConsumerState<OrderProgressTracker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(OrderProgressTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.status != widget.order.status) {
      widget.onStepCelebration?.call(widget.order.status);
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawIndex =
        OrderProgressInfo.progressIndexFromStatus(widget.order.status);
    final currentIndex = rawIndex < 0 ? 0 : rawIndex;
    final current = OrderProgressStep.values[currentIndex.clamp(0, 3)];
    final currentInfo = OrderProgressInfo.forStep(current);
    final steps = OrderProgressInfo.timelineSteps();
    final waitingCourier = widget.order.status == 'paid' ||
        widget.order.status == 'pending_payment';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? 16 : 22),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(widget.compact ? 24 : 32),
        boxShadow: DjassaTheme.shadowHeavy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suivi en direct',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: DjassaTheme.accentOrange,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.order.orderNumber,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: DjassaTheme.primaryWhite,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              _HeroStepIcon(
                info: currentInfo,
                pulse: _pulseController,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            waitingCourier
                ? (widget.order.status == 'pending_payment'
                    ? 'Paiement en attente'
                    : 'En attente du livreur')
                : currentInfo.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: DjassaTheme.primaryWhite,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            waitingCourier
                ? 'Un livreur va bientôt prendre en charge votre commande.'
                : currentInfo.subtitle,
            style: TextStyle(
              color: DjassaTheme.primaryWhite.withValues(alpha: .68),
            ),
          ),
          if (!widget.compact &&
              currentIndex >=
                  OrderProgressInfo.stepIndex(
                      OrderProgressStep.delivering)) ...[
            const SizedBox(height: 16),
            _OrderLiveMap(order: widget.order),
          ],
          const SizedBox(height: 20),
          _AnimatedProgressBar(
            progress: waitingCourier ? 0.08 : (currentIndex + 1) / steps.length,
          ),
          const SizedBox(height: 18),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final state = waitingCourier
                ? _StepVisualState.upcoming
                : index < currentIndex
                    ? _StepVisualState.done
                    : index == currentIndex
                        ? _StepVisualState.active
                        : _StepVisualState.upcoming;
            return _TimelineStepRow(
              step: step,
              state: state,
              isLast: index == steps.length - 1,
              animateIn: index == currentIndex,
            );
          }),
          if (widget.order.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: DjassaTheme.primaryWhite.withValues(alpha: .55),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.order.deliveryAddress,
                    style: TextStyle(
                      color: DjassaTheme.primaryWhite.withValues(alpha: .62),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: DjassaMotion.normal)
        .slideY(begin: 0.04, end: 0, curve: DjassaMotion.emphasized);
  }
}

class _HeroStepIcon extends StatelessWidget {
  const _HeroStepIcon({
    required this.info,
    required this.pulse,
  });

  final OrderProgressInfo info;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final scale = 1.0 + (pulse.value * 0.045);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: info.color.withValues(alpha: .18),
          border:
              Border.all(color: info.color.withValues(alpha: .45), width: 2),
          boxShadow: [
            BoxShadow(
              color: info.color.withValues(alpha: .35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(info.icon, color: info.color, size: 36),
      ),
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: DjassaMotion.slow,
          curve: DjassaMotion.emphasized,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            backgroundColor: DjassaTheme.primaryWhite.withValues(alpha: .12),
            valueColor: const AlwaysStoppedAnimation(DjassaTheme.accentOrange),
            minHeight: 8,
          ),
        ),
      ),
    );
  }
}

enum _StepVisualState { done, active, upcoming }

class _TimelineStepRow extends StatelessWidget {
  const _TimelineStepRow({
    required this.step,
    required this.state,
    required this.isLast,
    required this.animateIn,
  });

  final OrderProgressInfo step;
  final _StepVisualState state;
  final bool isLast;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final isDone = state == _StepVisualState.done;
    final isActive = state == _StepVisualState.active;
    final dotColor = isDone || isActive ? step.color : DjassaTheme.borderMedium;

    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: DjassaMotion.normal,
              curve: DjassaMotion.emphasized,
              width: isActive ? 40 : 32,
              height: isActive ? 40 : 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor.withValues(alpha: isActive ? .22 : .14),
                border:
                    Border.all(color: dotColor, width: isActive ? 2.5 : 1.5),
              ),
              child: Icon(
                isDone ? Icons.check_rounded : step.icon,
                size: isActive ? 22 : 18,
                color: dotColor,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isDone
                    ? DjassaTheme.accentOrange.withValues(alpha: .5)
                    : DjassaTheme.primaryWhite.withValues(alpha: .12),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    color: isActive || isDone
                        ? DjassaTheme.primaryWhite
                        : DjassaTheme.primaryWhite.withValues(alpha: .45),
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                    fontSize: isActive ? 16 : 14,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      color: DjassaTheme.primaryWhite.withValues(alpha: .58),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    if (animateIn) {
      row = row
          .animate()
          .fadeIn(duration: DjassaMotion.normal)
          .slideX(begin: 0.025, end: 0, curve: DjassaMotion.emphasized);
    }
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: row);
  }
}

class _OrderLiveMap extends ConsumerWidget {
  const _OrderLiveMap({required this.order});

  final ClientActiveOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = DeliveryTracking(
      orderId: order.id,
      orderNumber: order.orderNumber,
      address: order.deliveryAddress,
      createdAt: order.createdAt,
      deliveryAt: order.createdAt.add(const Duration(hours: 4)),
    );
    final fallback = DeliveryTrackingService.fallbackSnapshot(
      DeliveryTrackingQuery(
        orderId: order.id,
        address: order.deliveryAddress,
        createdAt: order.createdAt,
        deliveryAt: tracking.deliveryAt,
      ),
      DateTime.now(),
    );
    final snapshot = ref
        .watch(liveDeliveryTrackingProvider(tracking))
        .maybeWhen(data: (v) => v, orElse: () => fallback);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 160,
        child: RealtimeDeliveryMap(tracking: tracking, snapshot: snapshot),
      ),
    );
  }
}
