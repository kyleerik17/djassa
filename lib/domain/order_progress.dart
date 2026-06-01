import 'package:flutter/material.dart';

/// Étapes visibles côté client (synchronisées avec `orders.status`).
enum OrderProgressStep {
  orderTaken,
  preparing,
  delivering,
  delivered,
}

class OrderProgressInfo {
  const OrderProgressInfo({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final OrderProgressStep step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  static OrderProgressStep stepFromStatus(String status) {
    switch (status) {
      case 'shipping':
        return OrderProgressStep.delivering;
      case 'delivered':
        return OrderProgressStep.delivered;
      case 'confirmed':
        return OrderProgressStep.preparing;
      case 'courier_assigned':
        return OrderProgressStep.orderTaken;
      case 'paid':
      case 'pending_payment':
      default:
        return OrderProgressStep.orderTaken;
    }
  }

  /// Index de progression sur la timeline (0–3), -1 = avant prise en charge livreur.
  static int progressIndexFromStatus(String status) {
    switch (status) {
      case 'delivered':
        return 3;
      case 'shipping':
        return 2;
      case 'confirmed':
        return 1;
      case 'courier_assigned':
        return 0;
      case 'paid':
      case 'pending_payment':
        return -1;
      default:
        return 0;
    }
  }

  static bool isProgressForward(String? from, String to) {
    if (from == null || from == to) return false;
    const order = [
      'pending_payment',
      'paid',
      'courier_assigned',
      'confirmed',
      'shipping',
      'delivered',
    ];
    final a = order.indexOf(from);
    final b = order.indexOf(to);
    if (a < 0 || b < 0) return true;
    return b > a;
  }

  static int stepIndex(OrderProgressStep step) {
    switch (step) {
      case OrderProgressStep.orderTaken:
        return 0;
      case OrderProgressStep.preparing:
        return 1;
      case OrderProgressStep.delivering:
        return 2;
      case OrderProgressStep.delivered:
        return 3;
    }
  }

  static OrderProgressInfo forStep(OrderProgressStep step) {
    switch (step) {
      case OrderProgressStep.orderTaken:
        return const OrderProgressInfo(
          step: OrderProgressStep.orderTaken,
          title: 'Commande prise',
          subtitle: 'Un livreur a accepté votre course',
          icon: Icons.assignment_turned_in_rounded,
          color: Color(0xFFEA7C17),
        );
      case OrderProgressStep.preparing:
        return const OrderProgressInfo(
          step: OrderProgressStep.preparing,
          title: 'Préparation',
          subtitle: 'Votre colis est en cours de préparation',
          icon: Icons.inventory_2_rounded,
          color: Color(0xFF5C6BC0),
        );
      case OrderProgressStep.delivering:
        return const OrderProgressInfo(
          step: OrderProgressStep.delivering,
          title: 'En livraison',
          subtitle: 'Le livreur est en route vers vous',
          icon: Icons.delivery_dining_rounded,
          color: Color(0xFF1E88E5),
        );
      case OrderProgressStep.delivered:
        return const OrderProgressInfo(
          step: OrderProgressStep.delivered,
          title: 'Commande livrée',
          subtitle: 'Merci pour votre confiance',
          icon: Icons.verified_rounded,
          color: Color(0xFF43A047),
        );
    }
  }

  static List<OrderProgressInfo> timelineSteps() => [
        for (final s in OrderProgressStep.values) forStep(s),
      ];

  static bool isActiveDeliveryStatus(String status) {
    return status != 'delivered' && status != 'cancelled';
  }
}
