import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/djassa_theme.dart';
import 'core/router/app_router.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Configuration de la barre d'état
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const DjassaApp(),
    ),
  );
}

/// Application principale Djassa
class DjassaApp extends ConsumerWidget {
  const DjassaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Vérifier l'état d'authentification au démarrage
    Future.microtask(() {
      ref.read(authNotifierProvider.notifier).checkAuthStatus();
    });

    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp.router(
          title: 'Djassa',
          debugShowCheckedModeBanner: false,
          theme: DjassaTheme.lightTheme,
          darkTheme: DjassaTheme.darkTheme,
          themeMode: ThemeMode.light, // Mode clair par défaut
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
