import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/user_repository.dart';

/// Source de données distante pour les appels API
class RemoteDataSource {
  final http.Client _client;
  final String _baseUrl;

  RemoteDataSource({
    required http.Client client,
    String baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.djassa.com'),
  })  : _client = client,
        _baseUrl = baseUrl;

  /// Récupère l'utilisateur connecté depuis l'API
  Future<User> getCurrentUser(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/user/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(json);
      } else if (response.statusCode == 401) {
        throw const AuthFailure(message: 'Token invalide ou expiré');
      } else {
        throw ServerFailure(
          message: 'Erreur serveur lors de la récupération des données',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Erreur de connexion: ${e.message}');
    }
  }

  /// Met à jour le profil utilisateur
  Future<User> updateProfile(String token, User user) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(user.toJson()),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(json);
      } else if (response.statusCode == 401) {
        throw const AuthFailure(message: 'Non autorisé');
      } else if (response.statusCode == 422) {
        throw const ValidationFailure(message: 'Données invalides');
      } else {
        throw ServerFailure(
          message: 'Erreur lors de la mise à jour du profil',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Erreur de connexion: ${e.message}');
    }
  }

  /// Authentifie l'utilisateur
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw const AuthFailure(message: 'Identifiants incorrects');
      } else if (response.statusCode == 404) {
        throw const NotFoundFailure(message: 'Utilisateur non trouvé');
      } else {
        throw ServerFailure(
          message: 'Erreur lors de la connexion',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Erreur de connexion: ${e.message}');
    }
  }

  /// Inscrit un nouvel utilisateur
  Future<Map<String, dynamic>> register({
    required String name,
    required String surname,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'surname': surname,
          'phone': phone,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 400) {
        throw const ValidationFailure(message: 'Données invalides');
      } else if (response.statusCode == 409) {
        throw const ValidationFailure(message: 'Cet utilisateur existe déjà');
      } else {
        throw ServerFailure(
          message: 'Erreur lors de l\'inscription',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Erreur de connexion: ${e.message}');
    }
  }

  /// Déconnecte l'utilisateur (invalide le token)
  Future<void> logout(String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerFailure(
          message: 'Erreur lors de la déconnexion',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Erreur de connexion: ${e.message}');
    }
  }
}
