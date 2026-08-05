import 'package:djassa/core/theme/djassa_theme.dart';
import 'package:djassa/presentation/screens/profile/widgets/dev.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Footer discret affichant la version de l'app en bas de l'écran Profil,
/// avec une petite icône ⓘ à côté.
///
/// Un tap sur l'icône ouvre la sheet développeur (portfolio/GitHub).
/// Volontairement petit et gris clair pour ne pas ressembler à un vrai
/// lien fonctionnel — mais visible et trouvable, contrairement à un pur
/// easter egg caché derrière un appui long.
///
/// ⚠️ Dépendance requise : `package_info_plus`. Si absente :
///   flutter pub add package_info_plus
class AppVersionFooter extends StatelessWidget {
  const AppVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor = DjassaTheme.textSecondary.withValues(alpha: .55);

    return Center(
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final versionLabel = snapshot.hasData
              ? 'v${snapshot.data!.version} (${snapshot.data!.buildNumber})'
              : '';

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showDeveloperPreviewSheet(context),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    
                    versionLabel,
                    style: TextStyle(fontSize: 11, color: textColor),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: textColor,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}