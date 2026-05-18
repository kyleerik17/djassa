import 'package:dartz/dartz.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';

/// Cas d'utilisation pour récupérer l'utilisateur connecté
class GetCurrentUser {
  final UserRepository _repository;

  GetCurrentUser({required UserRepository repository}) : _repository = repository;

  Future<Either<Failure, User>> call() async {
    return await _repository.getCurrentUser();
  }
}

/// Cas d'utilisation pour vérifier si l'utilisateur est connecté
class IsLoggedIn {
  final UserRepository _repository;

  IsLoggedIn({required UserRepository repository}) : _repository = repository;

  Future<bool> call() async {
    return await _repository.isLoggedIn();
  }
}

/// Cas d'utilisation pour déconnecter l'utilisateur
class Logout {
  final UserRepository _repository;

  Logout({required UserRepository repository}) : _repository = repository;

  Future<Either<Failure, void>> call() async {
    return await _repository.logout();
  }
}

/// Cas d'utilisation pour mettre à jour le profil utilisateur
class UpdateProfile {
  final UserRepository _repository;

  UpdateProfile({required UserRepository repository}) : _repository = repository;

  Future<Either<Failure, User>> call(User user) async {
    return await _repository.updateProfile(user);
  }
}

/// Cas d'utilisation pour sauvegarder les données utilisateur en local
class SaveUserLocally {
  final UserRepository _repository;

  SaveUserLocally({required UserRepository repository}) : _repository = repository;

  Future<Either<Failure, void>> call(User user) async {
    return await _repository.saveUserLocally(user);
  }
}

/// Cas d'utilisation pour récupérer les données utilisateur depuis le local
class GetUserLocally {
  final UserRepository _repository;

  GetUserLocally({required UserRepository repository}) : _repository = repository;

  Future<Either<Failure, User>> call() async {
    return await _repository.getUserLocally();
  }
}

/// Cas d'utilisation pour supprimer les données utilisateur du local
class ClearUserLocally {
  final UserRepository _repository;

  ClearUserLocally({required UserRepository repository}) : _repository = repository;

  Future<Either<Failure, void>> call() async {
    return await _repository.clearUserLocally();
  }
}
