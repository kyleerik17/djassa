import 'package:flutter/material.dart';

import '../../../core/utils/icon_mapper.dart';

// Serialisation IconData
//
// IconData n'est pas nativement serialisable en JSON. On stocke aussi un
// nom d'icone stable pour reconstruire une constante via IconMapper.

Map<String, dynamic> _iconToJson(IconData icon) => {
      'codePoint': icon.codePoint,
      'fontFamily': icon.fontFamily,
      'fontPackage': icon.fontPackage,
      'iconName': IconMapper.toIconName(icon),
    };

IconData _iconFromJson(Map<String, dynamic>? json) {
  if (json == null) return Icons.category_rounded;
  return IconMapper.fromString(json['iconName'] as String?);
}

class ShopCategory {
  const ShopCategory({
    this.id = '',
    required this.name,
    required this.icon,
    this.iconName = 'category',
    required this.subtitle,
    required this.itemsCount,
  });

  final String id;
  final String name;
  final IconData icon;
  final String iconName;
  final String subtitle;
  final int itemsCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': _iconToJson(icon),
        'iconName': iconName,
        'subtitle': subtitle,
        'itemsCount': itemsCount,
      };

  factory ShopCategory.fromJson(Map<String, dynamic> json) => ShopCategory(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: _iconFromJson(json['icon'] as Map<String, dynamic>?),
        iconName: json['iconName'] as String? ?? 'category',
        subtitle: json['subtitle'] as String? ?? '',
        itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,
      );
}

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    this.categoryId = '',
    required this.category,
    this.description = '',
    required this.price,
    required this.oldPrice,
    required this.rating,
    required this.stock,
    required this.icon,
    required this.compatibility,
    required this.badge,
    this.imageUrl,
    this.creatorName,
    this.creatorAvatarUrl,
    this.isActive = true,
    // ---- Caractéristiques physiques de la pièce ----
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.diameterMm,
    this.weightG,
    this.threadSize = '',
    this.material = '',
    this.color = '',
    // ---- Références ----
    this.oemReference = '',
    this.manufacturerReference = '',
    // ---- Etat / garantie / position ----
    this.warrantyMonths = 0,
    this.condition = 'Neuf',
    this.partPosition = '',
    // ---- Compatibilité véhicule détaillée ----
    this.compatibleVehicles = const [],
  });

  final String id;
  final String name;
  final String categoryId;
  final String category;
  final String description;
  final int price;
  final int oldPrice;
  final double rating;
  final int stock;
  final IconData icon;
  final String compatibility;
  final String badge;
  final String? imageUrl;
  final String? creatorName;
  final String? creatorAvatarUrl;
  final bool isActive;

  // Dimensions / poids (null = non renseigné, ne pas afficher)
  final double? lengthMm;
  final double? widthMm;
  final double? heightMm;
  final double? diameterMm;
  final double? weightG;
  final String threadSize;
  final String material;
  final String color;

  // Références constructeur / fabricant
  final String oemReference;
  final String manufacturerReference;

  // Etat / garantie / position sur le véhicule
  final int warrantyMonths;
  final String condition; // Neuf | Occasion | Reconditionné
  final String partPosition; // ex: Avant Gauche

  // Liste de libellés de compatibilité détaillée
  // ex: "Toyota Corolla 2019-2023 1.8L Essence"
  final List<String> compatibleVehicles;

  bool get hasCreator => creatorName != null && creatorName!.trim().isNotEmpty;

  bool get hasDimensions =>
      lengthMm != null || widthMm != null || heightMm != null;

  bool get hasDiameter => diameterMm != null && diameterMm! > 0;

  bool get hasWeight => weightG != null && weightG! > 0;

  /// Ex: "120 × 75 × 18 mm" (ne montre que les valeurs renseignées)
  String get dimensionsLabel {
    final parts = <String>[
      if (lengthMm != null) _trimZero(lengthMm!),
      if (widthMm != null) _trimZero(widthMm!),
      if (heightMm != null) _trimZero(heightMm!),
    ];
    if (parts.isEmpty) return '';
    return '${parts.join(' × ')} mm';
  }

  /// Ex: "850 g" ou "1.2 kg" si ≥ 1000g
  String get weightLabel {
    final w = weightG;
    if (w == null || w <= 0) return '';
    if (w >= 1000) {
      return '${(w / 1000).toStringAsFixed(w % 1000 == 0 ? 0 : 1)} kg';
    }
    return '${_trimZero(w)} g';
  }

  String get diameterLabel {
    final d = diameterMm;
    if (d == null || d <= 0) return '';
    return 'Ø ${_trimZero(d)} mm';
  }

  static String _trimZero(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'category': category,
        'description': description,
        'price': price,
        'oldPrice': oldPrice,
        'rating': rating,
        'stock': stock,
        'icon': _iconToJson(icon),
        'compatibility': compatibility,
        'badge': badge,
        'imageUrl': imageUrl,
        'creatorName': creatorName,
        'creatorAvatarUrl': creatorAvatarUrl,
        'isActive': isActive,
        'lengthMm': lengthMm,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'diameterMm': diameterMm,
        'weightG': weightG,
        'threadSize': threadSize,
        'material': material,
        'color': color,
        'oemReference': oemReference,
        'manufacturerReference': manufacturerReference,
        'warrantyMonths': warrantyMonths,
        'condition': condition,
        'partPosition': partPosition,
        'compatibleVehicles': compatibleVehicles,
      };

  factory ShopProduct.fromJson(Map<String, dynamic> json) => ShopProduct(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        categoryId: json['categoryId'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: (json['price'] as num?)?.toInt() ?? 0,
        oldPrice: (json['oldPrice'] as num?)?.toInt() ?? 0,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        icon: _iconFromJson(json['icon'] as Map<String, dynamic>?),
        compatibility: json['compatibility'] as String? ?? '',
        badge: json['badge'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        creatorName: json['creatorName'] as String?,
        creatorAvatarUrl: json['creatorAvatarUrl'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        lengthMm: (json['lengthMm'] as num?)?.toDouble(),
        widthMm: (json['widthMm'] as num?)?.toDouble(),
        heightMm: (json['heightMm'] as num?)?.toDouble(),
        diameterMm: (json['diameterMm'] as num?)?.toDouble(),
        weightG: (json['weightG'] as num?)?.toDouble(),
        threadSize: json['threadSize'] as String? ?? '',
        material: json['material'] as String? ?? '',
        color: json['color'] as String? ?? '',
        oemReference: json['oemReference'] as String? ?? '',
        manufacturerReference: json['manufacturerReference'] as String? ?? '',
        warrantyMonths: (json['warrantyMonths'] as num?)?.toInt() ?? 0,
        condition: json['condition'] as String? ?? 'Neuf',
        partPosition: json['partPosition'] as String? ?? '',
        compatibleVehicles: (json['compatibleVehicles'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

class CartLine {
  const CartLine({
    required this.product,
    required this.quantity,
  });

  final ShopProduct product;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        product: ShopProduct.fromJson(
          Map<String, dynamic>.from(json['product'] as Map),
        ),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
}

class OrderPreview {
  const OrderPreview({
    required this.id,
    required this.status,
    required this.date,
    required this.total,
    required this.items,
    this.orderUuid = '',
    this.statusKey = '',
    this.checkoutUrl,
    this.reference, // ✅ Référence GeniusPay (MTX-XXXXXXXXXX)
  });

  final String id;
  final String orderUuid;
  final String statusKey;
  final String status;
  final String date;
  final int total;
  final int items;
  final String? checkoutUrl;
  final String? reference; // ✅ Référence pour polling GeniusPay

  bool get needsPayment => statusKey == 'pending_payment';

  /// Factory pour mapper la réponse API (Supabase/Backend)
  factory OrderPreview.fromJson(Map<String, dynamic> json) {
    return OrderPreview(
      id: json['id'] as String? ?? json['order_number'] as String? ?? '',
      status: json['status'] as String? ?? 'inconnu',
      statusKey:
          json['status_key'] as String? ?? json['status'] as String? ?? '',
      date: json['date'] as String? ?? json['created_at'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: json['items_count'] as int? ?? json['items'] as int? ?? 0,
      orderUuid: json['order_uuid'] as String? ?? json['uuid'] as String? ?? '',
      checkoutUrl: json['checkout_url'] as String?,
      reference:
          json['payment_reference'] as String? ?? json['reference'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'status_key': statusKey,
      'date': date,
      'total': total,
      'items': items,
      'order_uuid': orderUuid,
      if (checkoutUrl != null) 'checkout_url': checkoutUrl,
      if (reference != null) 'reference': reference,
    };
  }
}

final List<CartLine> cartLines = [];

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
