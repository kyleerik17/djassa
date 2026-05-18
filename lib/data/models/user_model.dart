import 'dart:convert';
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
    super.createdAt,
  });

  /// Crée depuis JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      avatarUrl: json['avatar_url'],
      isVerified: json['is_verified'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  /// Crée depuis une chaîne JSON
  factory UserModel.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return UserModel.fromJson(json);
  }

  /// Convertit en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'is_verified': isVerified,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Convertit en chaîne JSON
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Copie avec modifications
  @override
  UserModel copyWith({
    int? id,
    String? name,
    String? surname,
    String? phone,
    String? email,
    String? avatarUrl,
    bool? isVerified,
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
      createdAt: user.createdAt,
    );
  }
}
