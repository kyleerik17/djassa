import 'package:flutter/material.dart';

/// Helper centralisé pour afficher des SnackBar au style cohérent
/// dans toute l'app. Évite d'avoir des styles différents
/// (floating vs non-floating, couleurs, durées) selon les écrans.
class AppSnackbar {
  const AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    final scheme = _resolveScheme(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration,
          backgroundColor: scheme.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          content: Row(
            children: [
              Icon(icon ?? scheme.defaultIcon, color: scheme.foreground, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.foreground),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, type: SnackBarType.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, type: SnackBarType.error);

  static void info(BuildContext context, String message) =>
      show(context, message: message, type: SnackBarType.info);

  static _SnackScheme _resolveScheme(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return _SnackScheme(
          background: const Color(0xFF1F2A22),
          foreground: Colors.white,
          defaultIcon: Icons.check_circle_rounded,
        );
      case SnackBarType.error:
        return _SnackScheme(
          background: const Color(0xFF2A1616),
          foreground: Colors.white,
          defaultIcon: Icons.error_rounded,
        );
      case SnackBarType.info:
        return _SnackScheme(
          background: const Color(0xFF1C1C1C),
          foreground: Colors.white,
          defaultIcon: Icons.info_rounded,
        );
    }
  }
}

enum SnackBarType { success, error, info }

class _SnackScheme {
  const _SnackScheme({
    required this.background,
    required this.foreground,
    required this.defaultIcon,
  });

  final Color background;
  final Color foreground;
  final IconData defaultIcon;
}