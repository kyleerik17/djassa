import 'package:djassa/core/theme/djassa_theme.dart';
import 'package:djassa/presentation/screens/profile/widgets/helper.dart';
import 'package:djassa/presentation/screens/profile/widgets/profile_string.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// True uniquement en debug/profile local (`flutter run` par défaut).
/// En release (l'app buildée pour les clients, ex: `flutter build apk
/// --release` ou `flutter build web --release`), cette constante vaut
/// `false` et l'action "Dev: Ange Erik" disparaît automatiquement du
/// profil — c'est un artefact de développement, pas une fonctionnalité
/// destinée aux clients finaux.
///
/// ⚠️ Si tu la vois encore s'afficher : vérifie que tu lances bien l'app
/// avec `flutter run --release` (ou que ton build de prod utilise bien
/// `--release`/`--profile=false`) pour tester la disparition. En mode
/// debug normal, c'est normal et attendu qu'elle reste visible.
const bool showDeveloperSection = kDebugMode;

Future<void> showDeveloperPreviewSheet(BuildContext context) async {
  Future<void> launchURL(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnackbar.error(context, ProfileStrings.devLinkError);
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryWhite,
        borderRadius: BorderRadius.circular(28),
        boxShadow: DjassaTheme.shadowHeavy,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .12),
                child: const Icon(
                  Icons.code_rounded,
                  color: DjassaTheme.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ange Erik',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: ProfileStrings.closeTooltip,
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(ProfileStrings.devBio),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      launchURL('https://kyledevmonportfolio.lovable.app/'),
                  icon: const Icon(Icons.language_rounded),
                  label: const Text(ProfileStrings.devPortfolio),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: DjassaTheme.accentOrange,
                  ),
                  onPressed: () => launchURL('https://github.com/Angeerik23'),
                  icon: const Icon(Icons.code_rounded),
                  label: const Text(ProfileStrings.devGithub),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}