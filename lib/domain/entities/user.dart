import 'package:equatable/equatable.dart';

/// Entité utilisateur représentant un utilisateur de l'application Djassa
class User extends Equatable {
  final int id;
  final String name;
  final String surname;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.surname,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.isVerified = false,
    this.createdAt,
  });

  /// Crée un utilisateur vide (pour état initial)
  static User empty() {
    return const User(
      id: 0,
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

  /// Convertit depuis JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
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
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Copie avec modifications
  User copyWith({
    int? id,
    String? name,
    String? surname,
    String? phone,
    String? email,
    String? avatarUrl,
    bool? isVerified,
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
        createdAt,
      ];
}
