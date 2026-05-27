import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../widgets/shop/shop_widgets.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    final text = Uri.encodeComponent(
      'Bonjour, je souhaite discuter avec un assistant Djassa.',
    );
    final uri = Uri.parse('https://wa.me/2250768963019?text=$text');

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir WhatsApp pour le moment.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShopScaffold(
      currentIndex: 4,
      title: 'Assistance',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PromoCard(
            title: 'Besoin d’aide pour choisir ?',
            subtitle:
                'Envoyez votre besoin, votre budget ou une référence. Un conseiller vous répond.',
            buttonLabel: 'Chat avec un assistant',
            icon: Icons.support_agent_rounded,
            onPressed: () => _openWhatsApp(context),
          ),
          const SizedBox(height: 20),
          _SupportOption(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Chat avec un assistant',
            subtitle: 'Ouvre une discussion WhatsApp avec Djassa',
            onTap: () => _openWhatsApp(context),
          ),
          _SupportOption(
            icon: Icons.phone_in_talk_rounded,
            title: 'Appel conseiller',
            subtitle: 'Confirmez les détails par téléphone',
            onTap: () {},
          ),
          _SupportOption(
            icon: Icons.receipt_long_rounded,
            title: 'Suivi commande',
            subtitle: 'Retrouvez l’état de vos commandes',
            onTap: () => context.go('/orders'),
          ),
          const SizedBox(height: 88),
        ],
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
                backgroundColor:
                    DjassaTheme.accentOrange.withValues(alpha: .12),
                child: Icon(icon, color: DjassaTheme.accentOrange),
              ),
              const SizedBox(width: 12),
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
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
