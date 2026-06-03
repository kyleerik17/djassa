import 'package:flutter/material.dart';

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

  bool get hasCreator => creatorName != null && creatorName!.trim().isNotEmpty;
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
