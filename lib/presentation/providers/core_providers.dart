import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../data/repositories/user_repository_impl.dart';
import '../../../data/sources/local/local_data_source.dart';
import '../../../data/sources/remote/remote_data_source.dart';
import '../../../domain/repositories/user_repository.dart';

/// Fournit une instance de SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialisez SharedPreferences dans main()');
});

/// Fournit une instance de FlutterSecureStorage
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Fournit un client HTTP
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// Fournit la source de données locale
final localDataSourceProvider = Provider<LocalDataSource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalDataSource(prefs: prefs);
});

/// Fournit la source de données distante
final remoteDataSourceProvider = Provider<RemoteDataSource>((ref) {
  final client = ref.watch(httpClientProvider);
  return RemoteDataSource(client: client);
});

/// Fournit le repository utilisateur avec RemoteDataSource
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final remoteDataSource = ref.watch(remoteDataSourceProvider);
  
  return UserRepositoryImpl(
    prefs: prefs,
    secureStorage: secureStorage,
    remoteDataSource: remoteDataSource,
  );
});

/// Fournit les use cases d'authentification
final loginUserProvider = Provider((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return LoginUser(repository: repository);
});

final registerUserProvider = Provider((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return RegisterUser(repository: repository);
});

/// Fournit les use cases utilisateur
final getCurrentUserProvider = Provider((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return GetCurrentUser(repository: repository);
});

final isLoggedInProvider = Provider((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return IsLoggedIn(repository: repository);
});

final logoutProvider = Provider((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return Logout(repository: repository);
});

final saveUserLocallyProvider = Provider((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return SaveUserLocally(repository: repository);
});

final getUserLocallyProvider = Provider((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return GetUserLocally(repository: repository);
});

final clearUserLocallyProvider = Provider((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return ClearUserLocally(repository: repository);
});

final updateProfileProvider = Provider((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return UpdateProfile(repository: repository);
});
