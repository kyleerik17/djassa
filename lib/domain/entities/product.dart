// lib/domain/entities/product.dart

import 'shop_product.dart';
import '../../core/utils/icon_mapper.dart';

/// Entité produit du domaine — version complète (pièces auto)
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    this.categoryId = '',
    this.categoryName = '',
    this.description = '',
    this.compatibility = '',
    this.oldPrice = 0,
    this.stock = 0,
    this.rating = 0,
    this.badge = 'Top',
    this.iconName = 'shopping_bag_rounded',
    this.imageUrl,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.structureId,
    this.createdBy,
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.diameterMm,
    this.weightG,
    this.threadSize = '',
    this.material = '',
    this.color = '',
    this.oemReference = '',
    this.manufacturerReference = '',
    this.warrantyMonths = 0,
    this.condition = 'Neuf',
    this.partPosition = '',
  });

  final String id;
  final String name;
  final String slug;
  final int price;
  final String categoryId;
  final String categoryName;
  final String description;
  final String compatibility;
  final int oldPrice;
  final int stock;
  final double rating;
  final String badge;
  final String iconName;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? structureId;
  final String? createdBy;
  final double? lengthMm;
  final double? widthMm;
  final double? heightMm;
  final double? diameterMm;
  final double? weightG;
  final String threadSize;
  final String material;
  final String color;
  final String oemReference;
  final String manufacturerReference;
  final int warrantyMonths;
  final String condition;
  final String partPosition;

  /// Conversion vers l'ancienne entité ShopProduct (compatibilité temporaire)
  ShopProduct toShopProduct() => ShopProduct(
        id: id,
        name: name,
        category: categoryName,
        price: price,
        oldPrice: oldPrice,
        rating: rating,
        stock: stock,
        icon: IconMapper.fromString(iconName),
        compatibility: compatibility,
        badge: badge,
      );
}

/// Entité compatibilité véhicule
class VehicleCompatibility {
  const VehicleCompatibility({
    required this.id,
    required this.productId,
    this.makeName,
    this.modelName,
    this.generationName,
    this.yearStart,
    this.yearEnd,
    this.engineCode,
    this.fuelType,
    this.displacementCc,
  });

  final String id;
  final String productId;
  final String? makeName;
  final String? modelName;
  final String? generationName;
  final int? yearStart;
  final int? yearEnd;
  final String? engineCode;
  final String? fuelType;
  final int? displacementCc;
}
