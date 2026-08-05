import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../widgets/shop/shop_widgets.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const String _supportPhone = '2250768963019';
  static const String _supportEmail = 'support@djassa.ci'; // À adapter si besoin

  Future<void> _openWhatsApp(BuildContext context) async {
    final text = Uri.encodeComponent(
      'Bonjour, je souhaite discuter avec un assistant Djassa.',
    );
    final uri = Uri.parse('https://wa.me/$_supportPhone?text=$text');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      _showErrorSnackBar(context, 'WhatsApp n\'est pas installé sur cet appareil.');
    }
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    // Le format tel:+225... est le plus universel pour les appels
    final uri = Uri.parse('tel:+2250768963019');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      _showErrorSnackBar(context, 'Impossible de lancer l\'application téléphone.');
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri.parse(
      'mailto:$_supportEmail?subject=Demande%20d\'assistance%20Djassa&body=Bonjour,%0A%0AJe vous contacte concernant...',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      _showErrorSnackBar(context, 'Aucune application de messagerie configurée.');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShopScaffold(
      currentIndex: 4,
      title: 'Assistance',
      showBackButton: true,
      showSellButton: false,
      child: SingleChildScrollView( // ✅ Évite les débordements sur petits écrans
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 1. Carte principale d'appel à l'action
            PromoCard(
              title: 'Besoin d’aide pour choisir ?',
              subtitle: 'Envoyez votre besoin, votre budget ou une référence. Un conseiller vous répond rapidement.',
              buttonLabel: 'Chat WhatsApp',
              icon: Icons.support_agent_rounded,
              onPressed: () => _openWhatsApp(context),
            ),
            
            const SizedBox(height: 24),

            // ✅ 2. Informations sur les horaires (Gestion des attentes)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DjassaTheme.accentOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DjassaTheme.accentOrange.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.access_time_rounded, color: DjassaTheme.accentOrange, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Horaires du support',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Lun - Sam : 08h00 - 18h00',
                          style: TextStyle(fontSize: 12, color: DjassaTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ✅ 3. Section : Contact Direct
            const Text(
              'Contact direct',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            
            _SupportOption(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chat WhatsApp',
              subtitle: 'Réponse rapide avec un conseiller',
              onTap: () => _openWhatsApp(context),
            ),
            _SupportOption(
              icon: Icons.phone_in_talk_rounded,
              title: 'Appel téléphonique',
              subtitle: '07 68 96 30 19',
              onTap: () => _makePhoneCall(context),
            ),
            _SupportOption(
              icon: Icons.email_outlined,
              title: 'Envoyer un email',
              subtitle: 'Pour les demandes détaillées ou avec photos',
              onTap: () => _sendEmail(context),
            ),

            const SizedBox(height: 24),

            // ✅ 4. Section : Aide en autonomie
            const Text(
              'Aide en ligne',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            _SupportOption(
              icon: Icons.quiz_outlined,
              title: 'Foire aux questions (FAQ)',
              subtitle: 'Trouvez rapidement une réponse à vos questions',
              onTap: () {
                // TODO: Ajouter la route vers la FAQ quand elle sera prête
                // context.go(AppConstants.faqRoute);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Section FAQ bientôt disponible')),
                );
              },
            ),
            _SupportOption(
              icon: Icons.receipt_long_rounded,
              title: 'Suivi de commande',
              subtitle: 'Retrouvez l’état de vos livraisons en cours',
              onTap: () => context.go(AppConstants.ordersRoute),
            ),
            
            // Espace pour la barre de navigation du bas si ShopScaffold en a une
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DjassaTheme.primaryWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: DjassaTheme.borderMedium),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .12),
                child: Icon(icon, color: DjassaTheme.accentOrange, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: DjassaTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: DjassaTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}