import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/user_usecases.dart';
import '../../core_providers.dart';

/// État de l'authentification
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// État du provider d'authentification
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  /// Crée un état avec les données utilisateur
  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Vérifie si l'état est chargé
  bool get isLoading => status == AuthStatus.loading;
  
  /// Vérifie si l'utilisateur est authentifié
  bool get isAuthenticated => status == AuthStatus.authenticated;
  
  /// Vérifie s'il y a une erreur
  bool get hasError => status == AuthStatus.error;
}

/// Provider notifiant pour l'authentification
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  
  return AuthNotifier(
    isLoggedIn: IsLoggedIn(repository: repository),
    getCurrentUser: GetCurrentUser(repository: repository),
    logout: Logout(repository: repository),
    saveUserLocally: SaveUserLocally(repository: repository),
    getUserLocally: GetUserLocally(repository: repository),
    clearUserLocally: ClearUserLocally(repository: repository),
  );
});

/// Notifier pour gérer l'état d'authentification
class AuthNotifier extends StateNotifier<AuthState> {
  final IsLoggedIn _isLoggedIn;
  final GetCurrentUser _getCurrentUser;
  final Logout _logout;
  final SaveUserLocally _saveUserLocally;
  final GetUserLocally _getUserLocally;
  final ClearUserLocally _clearUserLocally;

  AuthNotifier({
    required IsLoggedIn isLoggedIn,
    required GetCurrentUser getCurrentUser,
    required Logout logout,
    required SaveUserLocally saveUserLocally,
    required GetUserLocally getUserLocally,
    required ClearUserLocally clearUserLocally,
  })  : _isLoggedIn = isLoggedIn,
        _getCurrentUser = getCurrentUser,
        _logout = logout,
        _saveUserLocally = saveUserLocally,
        _getUserLocally = getUserLocally,
        _clearUserLocally = clearUserLocally,
        super(const AuthState());

  /// Vérifie l'état d'authentification au démarrage
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    
    try {
      final loggedIn = await _isLoggedIn();
      
      if (loggedIn) {
        final result = await _getCurrentUser();
        result.fold(
          (failure) {
            state = state.copyWith(
              status: AuthStatus.unauthenticated,
              errorMessage: failure.message,
            );
          },
          (user) {
            state = state.copyWith(
              status: AuthStatus.authenticated,
              user: user,
            );
          },
        );
      } else {
        // Vérifier les données locales
        final localResult = await _getUserLocally();
        localResult.fold(
          (_) {
            state = const AuthState(status: AuthStatus.unauthenticated);
          },
          (user) {
            state = AuthState(
              status: AuthStatus.authenticated,
              user: user,
            );
          },
        );
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Connecte l'utilisateur
  Future<void> loginUser(User user) async {
    state = state.copyWith(status: AuthStatus.loading);
    
    try {
      await _saveUserLocally(user);
      
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Erreur lors de la connexion',
      );
    }
  }

  /// Déconnecte l'utilisateur
  Future<void> logoutUser() async {
    state = state.copyWith(status: AuthStatus.loading);
    
    try {
      await _logout();
      await _clearUserLocally();
      
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Erreur lors de la déconnexion',
      );
    }
  }

  /// Met à jour l'utilisateur
  Future<void> updateUser(User user) async {
    state = state.copyWith(user: user);
  }

  /// Réinitialise l'état
  void reset() {
    state = const AuthState();
  }
}
