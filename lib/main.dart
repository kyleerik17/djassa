import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/djassa_theme.dart';
import 'core/router/router_provider.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wtfygkiuzjmndnirtevy.supabase.co',
    anonKey: 'sb_publishable_BkULCR4lQWjtJzdwkdutEw_xxImMzKa',
  );

  final sharedPreferences = await SharedPreferences.getInstance();

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

// ✅ ConsumerStatefulWidget pour appeler checkAuthStatus une seule fois
class DjassaApp extends ConsumerStatefulWidget {
  const DjassaApp({super.key});

  @override
  ConsumerState<DjassaApp> createState() => _DjassaAppState();
}

class _DjassaAppState extends ConsumerState<DjassaApp> {
  @override
  void initState() {
    super.initState();
    // ✅ Appelé UNE SEULE FOIS au démarrage, jamais à chaque rebuild
    Future.microtask(() {
      ref.read(authNotifierProvider.notifier).checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp.router(
          title: 'Djassa',
          debugShowCheckedModeBanner: false,
          theme: DjassaTheme.lightTheme,
          darkTheme: DjassaTheme.darkTheme,
          themeMode: ThemeMode.light,
          routerConfig: router,
        );
      },
    );
  }
}