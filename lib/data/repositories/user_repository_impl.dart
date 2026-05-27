import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';
import '../sources/remote/remote_data_source.dart';

class UserRepositoryImpl implements UserRepository {
  final SharedPreferences _prefs;
  final RemoteDataSource _remoteDataSource;

  static const String _userKey = 'user_data';

  UserRepositoryImpl({
    required SharedPreferences prefs,
    required RemoteDataSource remoteDataSource,
  })  : _prefs = prefs,
        _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final user = await _remoteDataSource.getCurrentUser();

      if (user == null) {
        return const Left(
          AuthFailure(message: 'Utilisateur non connecté'),
        );
      }

      await saveUserLocally(user);

      return Right(user);
    } catch (e) {
      return Left(
        ServerFailure(
          message: e.toString(),
        ),
      );
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return _remoteDataSource.isLoggedIn();
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remoteDataSource.logout();

      await _prefs.remove(_userKey);

      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(
          message: e.toString(),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile(User user) async {
    try {
      final updatedUser = await _remoteDataSource.updateProfile(
        UserModel.fromEntity(user),
      );

      await saveUserLocally(updatedUser);

      return Right(updatedUser);
    } catch (e) {
      return Left(
        ServerFailure(
          message: e.toString(),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> saveUserLocally(User user) async {
    try {
      final userModel = UserModel.fromEntity(user);

      await _prefs.setString(
        _userKey,
        userModel.toJsonString(),
      );

      return const Right(null);
    } catch (e) {
      return const Left(
        CacheFailure(
          message: 'Erreur sauvegarde utilisateur',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, User>> getUserLocally() async {
    try {
      final userJson = _prefs.getString(_userKey);

      if (userJson == null) {
        return const Left(
          NotFoundFailure(
            message: 'Utilisateur introuvable',
          ),
        );
      }

      final user = UserModel.fromJsonString(userJson);

      return Right(user);
    } catch (e) {
      return const Left(
        CacheFailure(
          message: 'Erreur lecture utilisateur',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> clearUserLocally() async {
    try {
      await _prefs.remove(_userKey);

      return const Right(null);
    } catch (e) {
      return const Left(
        CacheFailure(
          message: 'Erreur suppression utilisateur',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final user = await _remoteDataSource.login(
        identifier: identifier,
        password: password,
      );

      await saveUserLocally(user);

      return Right({
        'user': user,
      });
    } catch (e) {
      return Left(
        AuthFailure(
          message: e.toString(),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> register({
    required String name,
    required String surname,
    required String phone,
    required String email,
    required String password,
    String role = 'client',
  }) async {
    try {
      final user = await _remoteDataSource.register(
        name: name,
        surname: surname,
        phone: phone,
        email: email,
        password: password,
        role: role,
      );

      await saveUserLocally(user);

      return Right({
        'user': user,
      });
    } catch (e) {
      return Left(
        AuthFailure(
          message: e.toString(),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> saveToken(String token) async {
    return const Right(null);
  }

  @override
  Future<String?> getToken() async {
    return null;
  }
}