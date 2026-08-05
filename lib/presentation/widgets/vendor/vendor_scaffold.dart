import 'package:flutter/material.dart';

import '../../../core/router/app_navigation.dart';
import '../../../core/theme/djassa_theme.dart';

class VendorScaffold extends StatelessWidget {
  const VendorScaffold({
    super.key,
    required this.currentIndex,
    required this.title,
    required this.body,
    this.actions,
  });

  final int currentIndex;
  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: DjassaTheme.backgroundSecondary,
        title: Text(title),
        automaticallyImplyLeading: false,
        actions: actions,
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: NavigationBar(
        backgroundColor: DjassaTheme.primaryWhite,
        indicatorColor: DjassaTheme.vendorSoft,
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (index == currentIndex) return;
          switch (index) {
            case 0:
              context.toVendor();
            case 1:
              context.toVendorOrders();
            case 2:
              context.toVendorAccount();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Boutique',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Compte',
          ),
        ],
      ),
    );
  }
}
