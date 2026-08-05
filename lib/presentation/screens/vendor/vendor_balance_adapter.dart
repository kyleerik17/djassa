import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// COUCHE D'ADAPTATION (MOCK) - À REMPLACER PAR TON VRAI PROVIDER DE SOLDE
// ============================================================================

enum BalancePeriod { today, days7, days30, custom }

class BalanceFilterState {
  final BalancePeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;

  BalanceFilterState({
    this.period = BalancePeriod.days7,
    this.customStart,
    this.customEnd,
  });
}

class BalanceFilterNotifier extends StateNotifier<BalanceFilterState> {
  BalanceFilterNotifier() : super(BalanceFilterState());

  void setPeriod(BalancePeriod period) {
    state = BalanceFilterState(period: period);
  }

  void setCustomPeriod(DateTime start, DateTime end) {
    state = BalanceFilterState(
      period: BalancePeriod.custom,
      customStart: start,
      customEnd: end,
    );
  }
}

final balanceFilterProvider = StateNotifierProvider<BalanceFilterNotifier, BalanceFilterState>(
  (ref) => BalanceFilterNotifier(),
);

class VendorBalanceData {
  final double availableBalance;
  final double pendingBalance;
  final double totalSales;

  VendorBalanceData({
    required this.availableBalance,
    required this.pendingBalance,
    required this.totalSales,
  });
}

// Provider simulant l'appel réseau pour le solde agrégé
final vendorBalanceProvider = FutureProvider.family<VendorBalanceData, BalanceFilterState>((ref, filter) async {
  // Simulation d'un délai réseau
  await Future.delayed(const Duration(milliseconds: 400));

  // Simulation de calcul basé sur la période (à remplacer par ton vrai appel API)
  final multiplier = switch (filter.period) {
    BalancePeriod.today => 1.0,
    BalancePeriod.days7 => 4.5,
    BalancePeriod.days30 => 18.0,
    BalancePeriod.custom => 10.0,
  };

  return VendorBalanceData(
    availableBalance: 125000.0 * multiplier,
    pendingBalance: 15000.0 * multiplier,
    totalSales: 140000.0 * multiplier,
  );
});