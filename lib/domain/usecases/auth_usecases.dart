import 'package:dartz/dartz.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';

/// Cas d'utilisation pour connecter un utilisateur
class LoginUser {
  final UserRepository _repository;

  LoginUser({required UserRepository repository}) : _repository = repository;

  Future<Either<Failure, Map<String, dynamic>>> call({
    required String phone,
    required String password,
  }) async {
    return await _repository.login(phone: phone, password: password);
  }
}

/// Cas d'utilisation pour inscrire un nouvel utilisateur
class RegisterUser {
  final UserRepository _repository;

  RegisterUser({required UserRepository repository}) : _repository = repository;

  Future<Either<Failure, Map<String, dynamic>>> call({
    required String name,
    required String surname,
    required String phone,
    required String email,
    required String password,
  }) async {
    return await _repository.register(
      name: name,
      surname: surname,
      phone: phone,
      email: email,
      password: password,
    );
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
