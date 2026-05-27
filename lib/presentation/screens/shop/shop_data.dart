import 'package:flutter/material.dart';

class ShopCategory {
  const ShopCategory({
    required this.name,
    required this.icon,
    required this.subtitle,
    required this.itemsCount,
  });

  final String name;
  final IconData icon;
  final String subtitle;
  final int itemsCount;
}

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.oldPrice,
    required this.rating,
    required this.stock,
    required this.icon,
    required this.compatibility,
    required this.badge,
  });

  final String id;
  final String name;
  final String category;
  final int price;
  final int oldPrice;
  final double rating;
  final int stock;
  final IconData icon;
  final String compatibility;
  final String badge;
}

class CartLine {
  const CartLine({
    required this.product,
    required this.quantity,
  });

  final ShopProduct product;
  final int quantity;
}

class OrderPreview {
  const OrderPreview({
    required this.id,
    required this.status,
    required this.date,
    required this.total,
    required this.items,
  });

  final String id;
  final String status;
  final String date;
  final int total;
  final int items;
}

const List<ShopCategory> shopCategories = [
  ShopCategory(
    name: 'Électronique',
    icon: Icons.devices_rounded,
    subtitle: 'Accessoires, gadgets, équipements',
    itemsCount: 120,
  ),
  ShopCategory(
    name: 'Maison',
    icon: Icons.home_rounded,
    subtitle: 'Décoration, entretien, rangement',
    itemsCount: 86,
  ),
  ShopCategory(
    name: 'Mode',
    icon: Icons.checkroom_rounded,
    subtitle: 'Vêtements, sacs, chaussures',
    itemsCount: 148,
  ),
  ShopCategory(
    name: 'Beauté',
    icon: Icons.spa_rounded,
    subtitle: 'Soins, parfums, accessoires',
    itemsCount: 72,
  ),
  ShopCategory(
    name: 'Sport',
    icon: Icons.sports_soccer_rounded,
    subtitle: 'Équipements et accessoires',
    itemsCount: 64,
  ),
  ShopCategory(
    name: 'Divers',
    icon: Icons.category_rounded,
    subtitle: 'Autres articles du catalogue',
    itemsCount: 200,
  ),
];

const List<ShopProduct> shopProducts = [
  ShopProduct(
    id: '1',
    name: 'Casque audio bluetooth',
    category: 'Électronique',
    price: 18500,
    oldPrice: 24000,
    rating: 4.8,
    stock: 18,
    icon: Icons.headphones_rounded,
    compatibility: 'Bluetooth • USB-C',
    badge: '-23%',
  ),
  ShopProduct(
    id: '2',
    name: 'Lampe de bureau LED',
    category: 'Maison',
    price: 6500,
    oldPrice: 8500,
    rating: 4.7,
    stock: 42,
    icon: Icons.light_mode_rounded,
    compatibility: 'Rechargeable',
    badge: 'Top',
  ),
  ShopProduct(
    id: '3',
    name: 'Sac à dos urbain',
    category: 'Mode',
    price: 28500,
    oldPrice: 34000,
    rating: 4.9,
    stock: 9,
    icon: Icons.backpack_rounded,
    compatibility: '15 pouces',
    badge: 'Garantie',
  ),
  ShopProduct(
    id: '4',
    name: 'Gourde sport isotherme',
    category: 'Sport',
    price: 12000,
    oldPrice: 15000,
    rating: 4.6,
    stock: 14,
    icon: Icons.sports_handball_rounded,
    compatibility: '750 ml',
    badge: '-18%',
  ),
  ShopProduct(
    id: '5',
    name: 'Kit soin visage',
    category: 'Beauté',
    price: 22500,
    oldPrice: 27500,
    rating: 4.5,
    stock: 21,
    icon: Icons.spa_rounded,
    compatibility: 'Tous types de peau',
    badge: 'Nouveau',
  ),
  ShopProduct(
    id: '6',
    name: 'Organiseur multifonction',
    category: 'Divers',
    price: 9000,
    oldPrice: 12000,
    rating: 4.7,
    stock: 30,
    icon: Icons.inventory_2_rounded,
    compatibility: 'Bureau & maison',
    badge: 'Promo',
  ),
];

final List<CartLine> cartLines = [];

const List<OrderPreview> orderPreviews = [
  OrderPreview(
    id: 'DJ-2408',
    status: 'Livrée',
    date: '18 mai 2026',
    total: 82500,
    items: 3,
  ),
  OrderPreview(
    id: 'DJ-2389',
    status: 'En route',
    date: '12 mai 2026',
    total: 41000,
    items: 1,
  ),
  OrderPreview(
    id: 'DJ-2311',
    status: 'Confirmée',
    date: '02 mai 2026',
    total: 58500,
    items: 1,
  ),
];

ShopProduct productById(String? id) {
  return shopProducts.firstWhere(
    (product) => product.id == id,
    orElse: () => shopProducts.first,
  );
}

String formatPrice(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final indexFromEnd = text.length - i;
    buffer.write(text[i]);
    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
      buffer.write(' ');
    }
  }
  return '${buffer.toString()} FCFA';
}
