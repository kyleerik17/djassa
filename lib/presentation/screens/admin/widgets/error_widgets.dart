import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/djassa_theme.dart';

class AdminLoadingScaffold extends StatelessWidget {
  const AdminLoadingScaffold({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      body: Center(child: CircularProgressIndicator()));
}

class AdminAccessDenied extends StatelessWidget {
  const AdminAccessDenied({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      appBar: AppBar(
          title: const Text('Backoffice'),
          backgroundColor: DjassaTheme.backgroundSecondary),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ErrorCard(
              title: 'Accès administrateur requis',
              message: message,
              actionLabel: 'Retour profil',
              onAction: () => context.go('/profile')),
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: DjassaTheme.primaryWhite,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: DjassaTheme.borderMedium)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.admin_panel_settings_outlined,
              size: 58, color: DjassaTheme.accentOrange),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}