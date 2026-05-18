import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';
import '../sources/remote/remote_data_source.dart';

/// Implémentation du repository utilisateur
class UserRepositoryImpl implements UserRepository {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  final RemoteDataSource? _remoteDataSource;
  
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';

  UserRepositoryImpl({
    required SharedPreferences prefs,
    required FlutterSecureStorage secureStorage,
    RemoteDataSource? remoteDataSource,
  })  : _prefs = prefs,
        _secureStorage = secureStorage,
        _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final userJson = _prefs.getString(_userKey);
      if (userJson == null) {
        return const Left(AuthFailure(message: 'Aucun utilisateur connecté'));
      }
      
      final user = UserModel.fromJsonString(userJson);
      return Right(user);
    } catch (e) {
      return const Left(CacheFailure(message: 'Erreur lors de la récupération des données'));
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      // Appel API pour invalider le token si disponible
      if (_remoteDataSource != null) {
        final token = await _secureStorage.read(key: _tokenKey);
        if (token != null) {
          try {
            await _remoteDataSource.logout(token);
          } catch (_) {
            // Ignorer les erreurs de déconnexion API
          }
        }
      }
      
      await _secureStorage.delete(key: _tokenKey);
      await _prefs.remove(_userKey);
      return const Right(null);
    } catch (e) {
      return const Left(CacheFailure(message: 'Erreur lors de la déconnexion'));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile(User user) async {
    try {
      // Si remoteDataSource est disponible, appeler l'API
      if (_remoteDataSource != null) {
        final token = await _secureStorage.read(key: _tokenKey);
        if (token != null) {
          final updatedUser = await _remoteDataSource.updateProfile(token, user);
          await saveUserLocally(updatedUser);
          return Right(updatedUser);
        }
      }
      
      // Fallback: mise à jour locale uniquement
      await saveUserLocally(user);
      return Right(user);
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur lors de la mise à jour: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> saveUserLocally(User user) async {
    try {
      final userModel = UserModel.fromEntity(user);
      final userJson = userModel.toJsonString();
      await _prefs.setString(_userKey, userJson);
      return const Right(null);
    } catch (e) {
      return const Left(CacheFailure(message: 'Erreur lors de la sauvegarde'));
    }
  }

  @override
  Future<Either<Failure, User>> getUserLocally() async {
    try {
      final userJson = _prefs.getString(_userKey);
      if (userJson == null) {
        return const Left(NotFoundFailure(message: 'Aucune donnée utilisateur trouvée'));
      }
      
      final user = UserModel.fromJsonString(userJson);
      return Right(user);
    } catch (e) {
      return const Left(CacheFailure(message: 'Erreur lors de la lecture des données'));
    }
  }

  @override
  Future<Either<Failure, void>> clearUserLocally() async {
    try {
      await _prefs.remove(_userKey);
      return const Right(null);
    } catch (e) {
      return const Left(CacheFailure(message: 'Erreur lors de la suppression'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> login({
    required String phone,
    required String password,
  }) async {
    try {
      if (_remoteDataSource == null) {
        return const Left(ServerFailure(message: 'Service non disponible'));
      }
      
      final result = await _remoteDataSource!.login(
        phone: phone,
        password: password,
      );
      
      // Sauvegarder le token si présent
      final token = result['token'] as String?;
      if (token != null) {
        await saveToken(token);
      }
      
      return Right(result);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur lors de la connexion: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> register({
    required String name,
    required String surname,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      if (_remoteDataSource == null) {
        return const Left(ServerFailure(message: 'Service non disponible'));
      }
      
      final result = await _remoteDataSource!.register(
        name: name,
        surname: surname,
        phone: phone,
        email: email,
        password: password,
      );
      
      // Sauvegarder le token si présent
      final token = result['token'] as String?;
      if (token != null) {
        await saveToken(token);
      }
      
      return Right(result);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Erreur lors de l\'inscription: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      return const Right(null);
    } catch (e) {
      return const Left(CacheFailure(message: 'Erreur lors de la sauvegarde du token'));
    }
  }

  @override
  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }
}
