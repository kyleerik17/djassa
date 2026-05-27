// lib/data/sources/remote/admin_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

// ── Models ────────────────────────────────────────────────────

class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconName,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final String slug;
  final String iconName;
  final int sortOrder;
  final bool isActive;

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    return AdminCategory(
      id:        '${json['id'] ?? ''}',
      name:      '${json['name'] ?? ''}',
      slug:      '${json['slug'] ?? ''}',
      iconName:  '${json['icon_name'] ?? 'category'}',
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      isActive:  json['is_active'] == true,
    );
  }
}

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.slug,
    required this.description,
    required this.compatibility,
    required this.price,
    required this.oldPrice,
    required this.stock,
    required this.rating,
    required this.badge,
    required this.iconName,
    required this.imageUrl,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String? categoryId;
  final String categoryName;
  final String name;
  final String slug;
  final String description;
  final String compatibility;
  final int price;
  final int oldPrice;
  final int stock;
  final double rating;
  final String badge;
  final String iconName;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    final category = json['categories'] is Map
        ? Map<String, dynamic>.from(json['categories'])
        : <String, dynamic>{};

    return AdminProduct(
      id:            '${json['id'] ?? ''}',
      categoryId:    json['category_id'] == null ? null : '${json['category_id']}',
      categoryName:  '${category['name'] ?? 'Sans rayon'}',
      name:          '${json['name'] ?? ''}',
      slug:          '${json['slug'] ?? ''}',
      description:   '${json['description'] ?? ''}',
      compatibility: '${json['compatibility'] ?? ''}',
      price:         int.tryParse('${json['price'] ?? 0}') ?? 0,
      oldPrice:      int.tryParse('${json['old_price'] ?? 0}') ?? 0,
      stock:         int.tryParse('${json['stock'] ?? 0}') ?? 0,
      rating:        double.tryParse('${json['rating'] ?? 4.5}') ?? 4.5,
      badge:         '${json['badge'] ?? 'Top'}',
      iconName:      '${json['icon_name'] ?? 'car'}',
      imageUrl:      json['image_url'] == null ||
                     '${json['image_url']}'.trim().isEmpty
                         ? null
                         : '${json['image_url']}',
      isActive:      json['is_active'] == true,
      createdAt:     DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}

class AdminProductInput {
  const AdminProductInput({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.compatibility,
    required this.price,
    required this.oldPrice,
    required this.stock,
    required this.rating,
    required this.badge,
    required this.iconName,
    required this.imageUrl,
    required this.isActive,
  });

  final String categoryId;
  final String name;
  final String description;
  final String compatibility;
  final int price;
  final int oldPrice;
  final int stock;
  final double rating;
  final String badge;
  final String iconName;
  final String? imageUrl;
  final bool isActive;

  Map<String, dynamic> toJson({String? slug}) {
    return {
      'category_id':   categoryId,
      'name':          name.trim(),
      if (slug != null) 'slug': slug,
      'description':   description.trim(),
      'compatibility': compatibility.trim(),
      'price':         price,
      'old_price':     oldPrice,
      'stock':         stock,
      'rating':        rating,
      'badge':         badge.trim().isEmpty ? 'Top' : badge.trim(),
      'icon_name':     iconName,
      'image_url':     imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
      'is_active':     isActive,
    };
  }
}

// ── Service ───────────────────────────────────────────────────

class AdminService {
  AdminService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final row = await _client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();
      return row?['is_admin'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<AdminCategory>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select('id,name,slug,icon_name,sort_order,is_active')
        .order('sort_order');

    return rows
        .map<AdminCategory>(
          (row) => AdminCategory.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<List<AdminProduct>> fetchProducts() async {
    final rows = await _client
        .from('products')
        .select('*, categories(id,name)')
        .order('created_at', ascending: false);

    return rows
        .map<AdminProduct>(
          (row) => AdminProduct.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<AdminProduct> createProduct(AdminProductInput input) async {
    final slug = await _uniqueSlug(input.name);
    final row = await _client
        .from('products')
        .insert(input.toJson(slug: slug))
        .select('*, categories(id,name)')
        .single();

    return AdminProduct.fromJson(Map<String, dynamic>.from(row));
  }

  Future<AdminProduct> updateProduct({
    required String id,
    required AdminProductInput input,
  }) async {
    final row = await _client
        .from('products')
        .update(input.toJson())
        .eq('id', id)
        .select('*, categories(id,name)')
        .single();

    return AdminProduct.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setProductActive({
    required String id,
    required bool isActive,
  }) async {
    await _client
        .from('products')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('products').delete().eq('id', id);
  }

  Future<String> _uniqueSlug(String name) async {
    final base = _slugify(name);
    final safeBase = base.isEmpty ? 'article' : base;
    var candidate = safeBase;
    var suffix = 2;

    while (true) {
      final existing = await _client
          .from('products')
          .select('id')
          .eq('slug', candidate)
          .maybeSingle();

      if (existing == null) return candidate;
      candidate = '$safeBase-$suffix';
      suffix++;
    }
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}