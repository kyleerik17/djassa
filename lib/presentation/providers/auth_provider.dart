import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/user_usecases.dart';
import 'core_providers.dart';

/// État de l'authentification
enum AuthStatus {
  initial,           // App vient de démarrer, vérification en cours
  loading,           // Action utilisateur en cours (login/logout/refresh)
  authenticated,     // Utilisateur connecté
  unauthenticated,   // Utilisateur déconnecté
  error              // Erreur lors d'une opération
}

/// Sentinel utilisé pour distinguer "paramètre non fourni" de "paramètre = null"
/// dans copyWith. Sans ça, impossible de remettre `user` ou `errorMessage` à null.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

/// État du provider d'authentification
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final DateTime? lastRefreshedAt; // Timestamp du dernier rafraîchissement réussi

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.lastRefreshedAt,
  });

  /// copyWith corrigé : accepte explicitement `null` pour effacer un champ.
  /// Utiliser `_unset` (via les valeurs par défaut ci-dessous) permet de
  /// différencier "je ne touche pas à ce champ" de "je le mets à null".
  AuthState copyWith({
    AuthStatus? status,
    Object? user = _unset,
    Object? errorMessage = _unset,
    Object? lastRefreshedAt = _unset,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: identical(user, _unset) ? this.user : user as User?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      lastRefreshedAt: identical(lastRefreshedAt, _unset)
          ? this.lastRefreshedAt
          : lastRefreshedAt as DateTime?,
    );
  }

  /// L'utilisateur est-il en train de charger ?
  bool get isLoading => status == AuthStatus.loading;

  /// L'utilisateur est-il authentifié ?
  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Y a-t-il une erreur ?
  bool get hasError => status == AuthStatus.error;

  /// L'app est-elle encore en état initial ?
  bool get isInitial => status == AuthStatus.initial;

  /// Le profil est-il considéré comme "périmé" (> 24h sans refresh) ?
  bool get isProfileStale {
    if (!isAuthenticated || user == null || lastRefreshedAt == null) return true;
    return DateTime.now().difference(lastRefreshedAt!).inHours > 24;
  }

  /// L'utilisateur est-il connecté ET son profil est-il frais ?
  bool get hasFreshProfile => isAuthenticated && !isProfileStale;
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

  // Timeout pour les appels réseau (5 secondes)
  static const Duration _networkTimeout = Duration(seconds: 5);

  // Durée avant qu'un profil ne soit considéré comme "stale"
  static const Duration _profileFreshnessThreshold = Duration(hours: 24);

  /// ✅ Compteur de "génération" de session.
  ///
  /// C'est LA correction qui règle le mélange de profils : chaque fois qu'on
  /// change explicitement d'utilisateur (login, logout, reset), on incrémente
  /// ce compteur. Tout appel asynchrone en vol (refresh, checkAuthStatus...)
  /// capture la génération au moment où il démarre, et vérifie qu'elle n'a
  /// pas changé avant d'appliquer son résultat au state. Si un login/logout
  /// est survenu entre-temps, le résultat périmé est silencieusement ignoré
  /// au lieu d'écraser le profil du nouvel utilisateur.
  int _generation = 0;

  /// Empêche plusieurs `checkAuthStatus()` de tourner en parallèle
  /// (ex: appelé deux fois rapidement au resume de l'app).
  bool _checkInProgress = false;

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

  /// Vérifie l'état d'authentification au démarrage de l'app.
  ///
  /// Stratégie "rester connecté" :
  /// 1. Lecture rapide du stockage local (SharedPreferences/Hive)
  /// 2. Si user trouvé → authentification immédiate + refresh silencieux
  /// 3. Sinon → tentative Supabase avec timeout
  Future<void> checkAuthStatus() async {
    // Évite de re-vérifier si déjà authentifié avec un user valide
    if (state.isAuthenticated && state.user != null) {
      // Optionnel : refresh si le profil est stale
      if (state.isProfileStale) {
        _refreshSilently();
      }
      return;
    }

    // Empêche les exécutions concurrentes de checkAuthStatus
    if (_checkInProgress) return;
    _checkInProgress = true;

    final myGeneration = ++_generation;
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // ÉTAPE 1 : Source de vérité rapide = stockage local
      final localResult = await _getUserLocally();

      User? localUser;
      localResult.fold(
        (failure) {
          // Erreur de lecture locale (corruption, etc.)
          localUser = null;
        },
        (user) => localUser = user,
      );

      // ⚠️ Si un autre login/logout a eu lieu pendant cet await, on abandonne :
      // on ne veut pas écraser le profil du nouvel utilisateur avec des
      // données lues pour l'ancien contexte.
      if (myGeneration != _generation) return;

      if (localUser != null) {
        // ✅ Utilisateur trouvé localement → authentifié immédiatement
        state = AuthState(
          status: AuthStatus.authenticated,
          user: localUser,
          lastRefreshedAt: DateTime.now(), // Considéré comme "frais" au départ
        );

        // Refresh silencieux en arrière-plan pour mettre à jour les données
        _refreshSilently(generation: myGeneration);
        return;
      }

      // ÉTAPE 2 : Pas de user local → on tente Supabase
      final loggedIn = await _isLoggedIn().timeout(_networkTimeout);
      if (myGeneration != _generation) return;

      if (loggedIn) {
        final result = await _getCurrentUser().timeout(_networkTimeout);
        if (myGeneration != _generation) return;

        result.fold(
          (failure) {
            // Session Supabase invalide ou erreur réseau
            state = const AuthState(status: AuthStatus.unauthenticated);
          },
          (user) async {
            await _persistUser(user);
            if (myGeneration != _generation) return;
            state = AuthState(
              status: AuthStatus.authenticated,
              user: user,
              lastRefreshedAt: DateTime.now(),
            );
          },
        );
      } else {
        // Pas de session active côté serveur
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e, stackTrace) {
      // Log l'erreur pour debugging/monitoring
      _logError('checkAuthStatus failed', e, stackTrace);

      if (myGeneration != _generation) return;

      // Fallback sécurisé : si on avait un user local, on le garde
      if (state.user != null) {
        state = state.copyWith(status: AuthStatus.authenticated);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } finally {
      _checkInProgress = false;
    }
  }

  /// Rafraîchit le profil utilisateur silencieusement (sans bloquer l'UI)
  ///
  /// Cette méthode ne change JAMAIS le statut d'authentification.
  /// En cas d'échec, l'utilisateur reste connecté avec ses données locales.
  Future<void> _refreshSilently({int? generation}) async {
    final myGeneration = generation ?? _generation;
    try {
      final result = await _getCurrentUser().timeout(_networkTimeout);

      // ⚠️ Garde anti-race : si l'utilisateur a changé (logout/login) pendant
      // cet appel réseau, on jette le résultat au lieu d'écraser le nouveau
      // profil avec les données de l'ancien utilisateur.
      if (myGeneration != _generation) return;

      result.fold(
        (failure) {
          // Échec silencieux : on garde la session locale intacte
          _logWarning('Silent refresh failed', failure);
        },
        (user) async {
          await _persistUser(user);
          if (myGeneration != _generation) return;
          state = state.copyWith(
            user: user,
            lastRefreshedAt: DateTime.now(),
          );
        },
      );
    } catch (e, stackTrace) {
      _logError('Silent refresh exception', e, stackTrace);
      // Ignore silencieusement - l'utilisateur reste connecté
    }
  }

  /// Connecte l'utilisateur après succès du login (email/password, OAuth, etc.)
  Future<void> loginUser(User user) async {
    // ✅ Nouvelle génération : tout appel en vol pour l'ancien utilisateur
    // (refresh, checkAuthStatus...) sera ignoré s'il retourne après ce point.
    final myGeneration = ++_generation;

    state = const AuthState(status: AuthStatus.loading);

    try {
      await _persistUser(user);
      if (myGeneration != _generation) return;

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        lastRefreshedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      _logError('loginUser failed', e, stackTrace);

      if (myGeneration != _generation) return;

      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Erreur lors de la connexion. Veuillez réessayer.',
      );
    }
  }

  /// Déconnecte l'utilisateur (seul moyen officiel de perdre la session)
  Future<void> logoutUser() async {
    // ✅ Incrémenter IMMÉDIATEMENT, avant tout await, pour invalider
    // instantanément tout refresh/check en cours pour l'utilisateur qui part.
    final myGeneration = ++_generation;

    state = const AuthState(status: AuthStatus.loading);

    try {
      // Tente de notifier le serveur, mais ne bloque pas si échec
      await _logout().timeout(_networkTimeout).catchError((_) {
        // Ignore l'erreur de logout serveur
        return null;
      });

      // Toujours effacer les données locales (source de vérité pour "déconnecté")
      await _clearUserLocally();

      if (myGeneration != _generation) return;
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e, stackTrace) {
      _logError('logoutUser failed', e, stackTrace);

      // Même en cas d'erreur critique, on force la déconnexion locale
      await _clearUserLocally();
      if (myGeneration != _generation) return;
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Met à jour les informations de l'utilisateur (profil, avatar, etc.)
  Future<void> updateUser(User user) async {
    if (!state.isAuthenticated) return;

    final myGeneration = _generation;
    await _persistUser(user);
    if (myGeneration != _generation) return;

    state = state.copyWith(
      user: user,
      lastRefreshedAt: DateTime.now(),
    );
  }

  /// Recharge explicitement le profil depuis le serveur
  ///
  /// Utile quand l'utilisateur clique sur "Actualiser" ou après une modification
  /// côté serveur (ex: admin change les permissions).
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;

    final myGeneration = _generation;
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final result = await _getCurrentUser().timeout(_networkTimeout);
      if (myGeneration != _generation) return;

      result.fold(
        (failure) {
          state = state.copyWith(
            status: AuthStatus.authenticated, // Reste connecté
            errorMessage: 'Impossible de rafraîchir le profil. Vérifiez votre connexion.',
          );
        },
        (user) async {
          await _persistUser(user);
          if (myGeneration != _generation) return;
          state = state.copyWith(
            user: user,
            status: AuthStatus.authenticated,
            errorMessage: null,
            lastRefreshedAt: DateTime.now(),
          );
        },
      );
    } catch (e, stackTrace) {
      _logError('refreshUser failed', e, stackTrace);

      if (myGeneration != _generation) return;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: 'Erreur réseau lors du rafraîchissement.',
      );
    }
  }

  /// Réinitialise complètement l'état d'authentification
  ///
  /// À utiliser uniquement dans des cas très spécifiques (ex: switch de compte,
  /// reset complet de l'app). Préférer [logoutUser] pour une déconnexion normale.
  void reset() {
    ++_generation; // invalide tout appel en vol
    state = const AuthState();
  }

  /// Méthode utilitaire privée pour persister l'utilisateur
  Future<void> _persistUser(User user) async {
    await _saveUserLocally(user);
  }

  /// Logger les erreurs (à remplacer par Firebase Crashlytics, Sentry, etc.)
  void _logError(String context, Object error, StackTrace stackTrace) {
    // TODO: Intégrer avec ton système de logging
    print('❌ [AUTH ERROR] $context: $error');
    print(stackTrace);
  }

  /// Logger les warnings non-critiques
  void _logWarning(String context, Object message) {
    // TODO: Intégrer avec ton système de logging
    print('⚠️ [AUTH WARNING] $context: $message');
  }
}