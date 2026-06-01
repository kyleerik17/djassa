// lib/domain/entities/shop_category.dart
import 'package:flutter/material.dart';
import '../../core/utils/icon_mapper.dart'; // ← Import du mapper

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

  // ✅ Utilise IconMapper pour la conversion
  String get iconName => IconMapper.toIconName(icon);

  factory ShopCategory.fromSupabase(Map<String, dynamic> json) {
    return ShopCategory(
      name: json['name'] as String,
      icon: IconMapper.fromString(json['icon_name'] as String?),
      subtitle: json['subtitle'] as String? ?? '',
      itemsCount: json['items_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSupabase({required String vendorId}) => {
        'name': name,
        'icon_name': iconName,
        'subtitle': subtitle,
        'items_count': itemsCount,
        'vendor_id': vendorId,
        'is_active': true,
      };
}
