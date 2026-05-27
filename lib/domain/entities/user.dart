import 'package:equatable/equatable.dart';

/// Entité utilisateur représentant un utilisateur de l'application Djassa
class User extends Equatable {
  final String id;
  final String name;
  final String surname;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final bool isVerified;
  final String role;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.surname,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.isVerified = false,
    this.role = 'client',
    this.createdAt,
  });

  /// Crée un utilisateur vide (pour état initial)
  static User empty() {
    return const User(
      id: '',
      name: '',
      surname: '',
      phone: '',
    );
  }

  /// Vérifie si l'utilisateur est vide
  bool get isEmpty => this == User.empty();

  /// Vérifie si l'utilisateur n'est pas vide
  bool get isNotEmpty => this != User.empty();

  /// Nom complet de l'utilisateur
  String get fullName => '$name $surname';

  /// Vrai si ce profil est un livreur.
  bool get isCourier => role == 'courier';

  /// Vrai si ce profil est un client classique.
  bool get isClient => role == 'client';

  /// Convertit depuis JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      avatarUrl: json['avatar_url'],
      isVerified: json['is_verified'] ?? false,
      role: json['role'] ?? 'client',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  /// Convertit vers JSON
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

  /// Copie avec modifications
  User copyWith({
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
    return User(
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

  @override
  List<Object?> get props => [
        id,
        name,
        surname,
        phone,
        email,
        avatarUrl,
        isVerified,
        role,
        createdAt,
      ];
}
