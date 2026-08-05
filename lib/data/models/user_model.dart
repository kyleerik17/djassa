import 'dart:convert' as convert; // ✅ Alias pour éviter les conflits de nom
import '../../domain/entities/user.dart';

/// Modèle de données utilisateur pour la sérialisation
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.surname,
    required super.phone,
    super.email,
    super.avatarUrl,
    super.isVerified,
    super.role,
    super.createdAt,
  });

  /// Crée depuis un Map JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '', // ✅ Sécurisation si l'ID est un int
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      avatarUrl: json['avatar_url'],
      isVerified: json['is_verified'] ?? false,
      role: json['role'] ?? 'client',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) // ✅ TryParse pour éviter les crashs
          : null,
    );
  }

  /// Crée depuis une chaîne JSON
  factory UserModel.fromJsonString(String jsonString) {
    try {
      final decoded = convert.jsonDecode(jsonString) as Map<String, dynamic>;
      return UserModel.fromJson(decoded);
    } catch (e) {
      // Retourne un utilisateur vide ou lève une exception selon votre logique
      throw Exception('Erreur de parsing JSON utilisateur: $e');
    }
  }

  /// Convertit en Map JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'is_verified': isVerified,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Convertit en chaîne JSON
  String toJsonString() {
    return convert.jsonEncode(toJson());
  }

  /// Copie avec modifications
  UserModel copyWith({
    String? id,
    String? name,
    String? surname,
    String? phone,
    String? email,
    String? avatarUrl,
    bool? isVerified,
    String? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Conversion depuis une entité User
  static UserModel fromEntity(User user) {
    return UserModel(
      id: user.id,
      name: user.name,
      surname: user.surname,
      phone: user.phone,
      email: user.email,
      avatarUrl: user.avatarUrl,
      isVerified: user.isVerified,
      role: user.role,
      createdAt: user.createdAt,
    );
  }
}