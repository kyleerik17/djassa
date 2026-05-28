import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/user_usecases.dart';
import 'core_providers.dart';

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

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasError => status == AuthStatus.error;
}

/// Provider notifiant pour l'authentification
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
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

  /// Vérifie l'état d'authentification au démarrage.
  ///
  /// Stratégie "rester connecté" :
  /// 1. On lit d'abord l'utilisateur stocké localement (SharedPreferences).
  ///    S'il existe, on considère l'utilisateur comme authentifié immédiatement
  ///    (UX : pas d'écran de login au lancement).
  /// 2. En arrière-plan, on tente de rafraîchir le profil depuis Supabase.
  ///    Si ça réussit, on met à jour les infos et on re-sauve localement.
  ///    Si ça échoue (réseau, session expirée, etc.), on garde la session
  ///    locale — l'utilisateur reste connecté.
  /// 3. Seul un appel explicite à [logoutUser] efface les données locales.
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // 1) Source de vérité = stockage local
      final localResult = await _getUserLocally();

      User? localUser;
      localResult.fold((_) => localUser = null, (u) => localUser = u);

      if (localUser != null) {
        // Utilisateur trouvé localement → on le considère connecté tout de suite
        state = AuthState(
          status: AuthStatus.authenticated,
          user: localUser,
        );

        // 2) Rafraîchissement silencieux en arrière-plan
        _refreshSilently();
        return;
      }

      // 2b) Pas de user local : on tente quand même Supabase (cas premier
      // lancement après login natif)
      final loggedIn = await _isLoggedIn();
      if (loggedIn) {
        final result = await _getCurrentUser();
        result.fold(
          (failure) {
            state = const AuthState(status: AuthStatus.unauthenticated);
          },
          (user) async {
            await _saveUserLocally(user); // on persiste pour la prochaine fois
            state = AuthState(
              status: AuthStatus.authenticated,
              user: user,
            );
          },
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      // En cas d'erreur inattendue, on ne déconnecte PAS l'utilisateur
      // s'il avait déjà une session locale.
      if (state.user != null) {
        state = state.copyWith(status: AuthStatus.authenticated);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    }
  }

  /// Rafraîchit le profil sans jamais déconnecter l'utilisateur en cas d'échec.
  Future<void> _refreshSilently() async {
    try {
      final result = await _getCurrentUser();
      result.fold(
        (_) {}, // échec silencieux : on garde la session locale
        (user) async {
          await _saveUserLocally(user);
          state = state.copyWith(user: user);
        },
      );
    } catch (_) {
      // ignore
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
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Erreur lors de la connexion',
      );
    }
  }

  /// Déconnecte l'utilisateur (seul moyen de perdre la session)
  Future<void> logoutUser() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _logout();
      await _clearUserLocally();

      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (_) {
      // Même en cas d'erreur réseau, on force la déconnexion locale
      await _clearUserLocally();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Met à jour l'utilisateur dans le state ET en local
  Future<void> updateUser(User user) async {
    await _saveUserLocally(user);
    state = state.copyWith(user: user);
  }

  /// Recharge le profil depuis Supabase et met à jour le state
  Future<void> refreshUser() async {
    try {
      final result = await _getCurrentUser();
      result.fold(
        (_) {},
        (user) async {
          await _saveUserLocally(user);
          state = state.copyWith(user: user);
        },
      );
    } catch (_) {}
  }

  void reset() {
    state = const AuthState();
  }
}
