import '../../domain/entities/user.dart';
import 'package:dartz/dartz.dart';

/// Échecs possibles lors des opérations
abstract class Failure {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  String toString() => 'Failure: $message (code: $statusCode)';
}

class NetworkFailure extends Failure {
  const NetworkFailure({String message = 'Erreur de connexion'}) 
      : super(message: message);
}

class ServerFailure extends Failure {
  const ServerFailure({String message = 'Erreur serveur', int? statusCode}) 
      : super(message: message, statusCode: statusCode);
}

class AuthFailure extends Failure {
  const AuthFailure({String message = 'Non autorisé'}) 
      : super(message: message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({String message = 'Non trouvé'}) 
      : super(message: message);
}

class ValidationFailure extends Failure {
  const ValidationFailure({String message = 'Validation échouée'}) 
      : super(message: message);
}

class CacheFailure extends Failure {
  const CacheFailure({String message = 'Erreur cache'}) 
      : super(message: message);
}

/// Repository abstrait pour la gestion des utilisateurs
abstract class UserRepository {
  /// Récupère l'utilisateur connecté
  Future<Either<Failure, User>> getCurrentUser();
  
  /// Connecte un utilisateur
  Future<Either<Failure, Map<String, dynamic>>> login({
    required String phone,
    required String password,
  });
  
  /// Inscrit un nouvel utilisateur
  Future<Either<Failure, Map<String, dynamic>>> register({
    required String name,
    required String surname,
    required String phone,
    required String email,
    required String password,
  });
  
  /// Met à jour le profil utilisateur
  Future<Either<Failure, User>> updateProfile(User user);
  
  /// Déconnecte l'utilisateur
  Future<Either<Failure, void>> logout();
  
  /// Vérifie si l'utilisateur est connecté
  Future<bool> isLoggedIn();
  
  /// Sauvegarde les données utilisateur en local
  Future<Either<Failure, void>> saveUserLocally(User user);
  
  /// Récupère les données utilisateur depuis le local
  Future<Either<Failure, User>> getUserLocally();
  
  /// Supprime les données utilisateur du local
  Future<Either<Failure, void>> clearUserLocally();
  
  /// Sauvegarde le token d'authentification
  Future<Either<Failure, void>> saveToken(String token);
  
  /// Récupère le token d'authentification
  Future<String?> getToken();
}
