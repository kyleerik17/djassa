import 'package:flutter/material.dart';

class MarketplaceCategorySeed {
  const MarketplaceCategorySeed({
    required this.name,
    required this.subtitle,
    required this.iconName,
    required this.icon,
  });

  final String name;
  final String subtitle;
  final String iconName;
  final IconData icon;
}

class MarketplaceTaxonomy {
  static const categories = <MarketplaceCategorySeed>[
    MarketplaceCategorySeed(
      name: 'Téléphones',
      subtitle: 'Smartphones, accessoires, recharges',
      iconName: 'phone_iphone_rounded',
      icon: Icons.phone_iphone_rounded,
    ),
    MarketplaceCategorySeed(
      name: 'Électronique',
      subtitle: 'Audio, TV, ordinateurs, gadgets',
      iconName: 'devices_rounded',
      icon: Icons.devices_rounded,
    ),
    MarketplaceCategorySeed(
      name: 'Mode',
      subtitle: 'Vêtements, chaussures, montres',
      iconName: 'checkroom_rounded',
      icon: Icons.checkroom_rounded,
    ),
    MarketplaceCategorySeed(
      name: 'Maison',
      subtitle: 'Meubles, déco, cuisine',
      iconName: 'chair_rounded',
      icon: Icons.chair_rounded,
    ),
    MarketplaceCategorySeed(
      name: 'Beauté',
      subtitle: 'Soins, parfums, coiffure',
      iconName: 'spa_rounded',
      icon: Icons.spa_rounded,
    ),
    MarketplaceCategorySeed(
      name: 'Supermarché',
      subtitle: 'Courses, boissons, produits du quotidien',
      iconName: 'local_grocery_store_rounded',
      icon: Icons.local_grocery_store_rounded,
    ),
    MarketplaceCategorySeed(
      name: 'Bébé',
      subtitle: 'Puériculture, jouets, vêtements',
      iconName: 'child_care_rounded',
      icon: Icons.child_care_rounded,
    ),
    MarketplaceCategorySeed(
      name: 'Sport',
      subtitle: 'Fitness, maillots, équipements',
      iconName: 'sports_soccer_rounded',
      icon: Icons.sports_soccer_rounded,
    ),
    MarketplaceCategorySeed(
      name: 'Auto & Moto',
      subtitle: 'Accessoires, entretien, pièces',
      iconName: 'directions_car',
      icon: Icons.directions_car,
    ),
  ];
}
