// lib/data/models/product_model.dart

import '../../domain/entities/product.dart';

/// Modèle de données produit pour la sérialisation Supabase
class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.slug,
    required super.price,
    super.categoryId,
    super.categoryName,
    super.description,
    super.compatibility,
    super.oldPrice,
    super.stock,
    super.rating,
    super.badge,
    super.iconName,
    super.imageUrl,
    super.isActive,
    super.createdAt,
    super.updatedAt,
    super.structureId,
    super.createdBy,
    super.lengthMm,
    super.widthMm,
    super.heightMm,
    super.diameterMm,
    super.weightG,
    super.threadSize,
    super.material,
    super.color,
    super.oemReference,
    super.manufacturerReference,
    super.warrantyMonths,
    super.condition,
    super.partPosition,
  });

  /// Crée depuis JSON (réponse Supabase). Supporte la jointure
  /// `categories(name, slug)` quand elle est sélectionnée :
  /// `.select('*, categories(name, slug)')`
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final categoryJoin = json['categories'] as Map<String, dynamic>?;

    return ProductModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      categoryId: json['category_id'] ?? '',
      categoryName: categoryJoin?['name'] ?? json['category_name'] ?? '',
      description: json['description'] ?? '',
      compatibility: json['compatibility'] ?? '',
      price: _toInt(json['price']),
      oldPrice: _toInt(json['old_price']),
      stock: _toInt(json['stock']),
      rating: _toDouble(json['rating']) ?? 0,
      badge: json['badge'] ?? 'Top',
      iconName: json['icon_name'] ?? 'shopping_bag_rounded',
      imageUrl: json['image_url'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      structureId: json['structure_id'],
      createdBy: json['created_by'],
      lengthMm: _toDouble(json['length_mm']),
      widthMm: _toDouble(json['width_mm']),
      heightMm: _toDouble(json['height_mm']),
      diameterMm: _toDouble(json['diameter_mm']),
      weightG: _toDouble(json['weight_g']),
      threadSize: json['thread_size'] ?? '',
      material: json['material'] ?? '',
      color: json['color'] ?? '',
      oemReference: json['oem_reference'] ?? '',
      manufacturerReference: json['manufacturer_reference'] ?? '',
      warrantyMonths: _toInt(json['warranty_months']),
      condition: json['condition'] ?? 'Neuf',
      partPosition: json['part_position'] ?? '',
    );
  }

  /// Convertit en JSON pour insert/update Supabase.
  /// N'inclut pas id/created_at/updated_at (gérés par la base).
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'category_id': categoryId.isEmpty ? null : categoryId,
      'description': description,
      'compatibility': compatibility,
      'price': price,
      'old_price': oldPrice,
      'stock': stock,
      'rating': rating,
      'badge': badge,
      'icon_name': iconName,
      'image_url': imageUrl,
      'is_active': isActive,
      'structure_id': structureId,
      'length_mm': lengthMm,
      'width_mm': widthMm,
      'height_mm': heightMm,
      'diameter_mm': diameterMm,
      'weight_g': weightG,
      'thread_size': threadSize,
      'material': material,
      'color': color,
      'oem_reference': oemReference,
      'manufacturer_reference': manufacturerReference,
      'warranty_months': warrantyMonths,
      'condition': condition,
      'part_position': partPosition,
    };
  }

  /// Conversion depuis une entité Product
  static ProductModel fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      slug: product.slug,
      categoryId: product.categoryId,
      categoryName: product.categoryName,
      description: product.description,
      compatibility: product.compatibility,
      price: product.price,
      oldPrice: product.oldPrice,
      stock: product.stock,
      rating: product.rating,
      badge: product.badge,
      iconName: product.iconName,
      imageUrl: product.imageUrl,
      isActive: product.isActive,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      structureId: product.structureId,
      createdBy: product.createdBy,
      lengthMm: product.lengthMm,
      widthMm: product.widthMm,
      heightMm: product.heightMm,
      diameterMm: product.diameterMm,
      weightG: product.weightG,
      threadSize: product.threadSize,
      material: product.material,
      color: product.color,
      oemReference: product.oemReference,
      manufacturerReference: product.manufacturerReference,
      warrantyMonths: product.warrantyMonths,
      condition: product.condition,
      partPosition: product.partPosition,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// Modèle pour une ligne de compatibilité véhicule
class VehicleCompatibilityModel extends VehicleCompatibility {
  const VehicleCompatibilityModel({
    required super.id,
    required super.productId,
    super.makeName,
    super.modelName,
    super.generationName,
    super.yearStart,
    super.yearEnd,
    super.engineCode,
    super.fuelType,
    super.displacementCc,
  });

  factory VehicleCompatibilityModel.fromJson(Map<String, dynamic> json) {
    final make = json['vehicle_makes'] as Map<String, dynamic>?;
    final model = json['vehicle_models'] as Map<String, dynamic>?;
    final generation = json['vehicle_generations'] as Map<String, dynamic>?;
    final engine = json['vehicle_engines'] as Map<String, dynamic>?;

    return VehicleCompatibilityModel(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      makeName: make?['name'],
      modelName: model?['name'],
      generationName: generation?['name'],
      yearStart: json['year_start'] ?? generation?['year_start'],
      yearEnd: json['year_end'] ?? generation?['year_end'],
      engineCode: engine?['engine_code'],
      fuelType: engine?['fuel_type'],
      displacementCc: engine?['displacement_cc'],
    );
  }
}
