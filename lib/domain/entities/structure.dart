import 'package:equatable/equatable.dart';

/// Boutique liée à un vendeur (`structures.owner_id` → `profiles.id`).
class Structure extends Equatable {
  final String id;
  final String ownerId;
  final String name;
  final String slug;
  final String description;
  final String phone;
  final String? email;
  final String address;
  final int deliveryFee;
  final int minimumOrder;
  final String openingHour;
  final String closingHour;
  final bool isVerified;
  final bool isActive;

  const Structure({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    this.description = '',
    this.phone = '',
    this.email,
    this.address = '',
    this.deliveryFee = 0,
    this.minimumOrder = 0,
    this.openingHour = '08:00',
    this.closingHour = '18:00',
    this.isVerified = false,
    this.isActive = true,
  });

  static const Structure empty = Structure(
    id: '',
    ownerId: '',
    name: '',
    slug: '',
  );

  bool get isEmpty => id.isEmpty;

  bool get isProfileComplete =>
      name.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      address.trim().isNotEmpty;

  factory Structure.fromJson(Map<String, dynamic> json) {
    return Structure(
      id: '${json['id'] ?? ''}',
      ownerId: '${json['owner_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      description: '${json['description'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      email: json['email'] as String?,
      address: '${json['address'] ?? ''}',
      deliveryFee: (json['delivery_fee'] as num?)?.toInt() ?? 0,
      minimumOrder: (json['minimum_order'] as num?)?.toInt() ?? 0,
      openingHour: '${json['opening_hour'] ?? '08:00'}',
      closingHour: '${json['closing_hour'] ?? '18:00'}',
      isVerified: json['is_verified'] == true,
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'owner_id': ownerId,
        'name': name.trim(),
        'slug': slug.trim(),
        'description': description.trim(),
        'phone': phone.trim(),
        'email': email?.trim(),
        'address': address.trim(),
        'delivery_fee': deliveryFee,
        'minimum_order': minimumOrder,
        'opening_hour': openingHour,
        'closing_hour': closingHour,
        'is_active': isActive,
      };

  Structure copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? slug,
    String? description,
    String? phone,
    String? email,
    String? address,
    int? deliveryFee,
    int? minimumOrder,
    String? openingHour,
    String? closingHour,
    bool? isVerified,
    bool? isActive,
  }) {
    return Structure(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      minimumOrder: minimumOrder ?? this.minimumOrder,
      openingHour: openingHour ?? this.openingHour,
      closingHour: closingHour ?? this.closingHour,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        name,
        slug,
        description,
        phone,
        email,
        address,
        deliveryFee,
        minimumOrder,
        openingHour,
        closingHour,
        isVerified,
        isActive,
      ];
}
