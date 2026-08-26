import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/djassa_theme.dart';
import 'core/router/router_provider.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/order_notification_service.dart';

// TODO: remplacer par --dart-define ou flutter_dotenv.
// Exemple de lancement :
// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const String _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://wtfygkiuzjmndnirtevy.supabase.co',
);
const String _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_BkULCR4lQWjtJzdwkdutEw_xxImMzKa',
);

void main() async {
  // runZonedGuarded capte aussi les erreurs asynchrones non catchées
  // (utile pour brancher Sentry/Crashlytics plus tard).
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

      // Verrouille l'app en portrait (à retirer si tablette/paysage prévu).
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      SharedPreferences? sharedPreferences;
      bool startupError = false;

      try {
        await Supabase.initialize(
          url: _supabaseUrl,
          anonKey: _supabaseAnonKey,
        );
        sharedPreferences = await SharedPreferences.getInstance();
        await OrderNotificationService().initialize();
      } catch (e, st) {
        // TODO: brancher un vrai logger (Sentry/Crashlytics) ici.
        debugPrint('Erreur au démarrage: $e\n$st');
        startupError = true;
      }

      if (startupError || sharedPreferences == null) {
        runApp(const _StartupErrorApp());
        return;
      }

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          ],
          child: const DjassaApp(),
        ),
      );
    },
    (error, stack) {
      // TODO: brancher un vrai logger ici aussi (erreurs hors du try/catch ci-dessus).
      debugPrint('Erreur non catchée: $error\n$stack');
    },
  );
}

/// Écran minimal affiché si l'initialisation (Supabase, prefs, notifications)
/// échoue, plutôt que de crasher l'app à froid sans aucun retour visuel.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "Impossible de démarrer l'application.\nVérifiez votre connexion et réessayez.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DjassaApp extends ConsumerStatefulWidget {
  const DjassaApp({super.key});

  @override
  ConsumerState<DjassaApp> createState() => _DjassaAppState();
}

class _DjassaAppState extends ConsumerState<DjassaApp> {
  final _orderNotificationService = OrderNotificationService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authNotifierProvider.notifier).checkAuthStatus();
    });
  }

  @override
  void dispose() {
    _orderNotificationService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    // ref.listen remplace le pattern _watchedUserId + Future.microtask dans build().
    // select() évite de re-déclencher le listener si un autre champ d'AuthState change.
    ref.listen<String?>(
      authNotifierProvider.select((state) => state.user?.id),
      (previous, next) {
        _orderNotificationService.watchUser(next);
      },
    );

    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp.router(
          title: 'Djassa',
          debugShowCheckedModeBanner: false,
          theme: DjassaTheme.lightTheme,
          darkTheme: DjassaTheme.darkTheme,
          themeMode: ThemeMode.light,
          locale: const Locale('fr', 'CI'),
          supportedLocales: const [
            Locale('fr', 'CI'),
            Locale('fr'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        );
      },
    );
  }
}