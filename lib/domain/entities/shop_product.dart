// lib/domain/entities/shop_product.dart
import 'package:flutter/material.dart';
import '../../core/utils/icon_mapper.dart'; // ← Import du mapper

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

  // ✅ Utilise IconMapper pour la conversion
  String get iconName => IconMapper.toIconName(icon);

  factory ShopProduct.fromSupabase(Map<String, dynamic> json) {
    return ShopProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      price: json['price'] as int,
      oldPrice: json['old_price'] as int,
      rating: (json['rating'] as num).toDouble(),
      stock: json['stock'] as int,
      icon: IconMapper.fromString(json['icon_name'] as String?),
      compatibility: json['compatibility'] as String? ?? '',
      badge: json['badge'] as String? ?? '',
    );
  }

  Map<String, dynamic> toSupabase({required String vendorId}) => {
        'name': name,
        'category': category,
        'price': price,
        'old_price': oldPrice,
        'rating': rating,
        'stock': stock,
        'icon_name': iconName,
        'compatibility': compatibility,
        'badge': badge,
        'vendor_id': vendorId,
        'is_active': true,
      };
}
