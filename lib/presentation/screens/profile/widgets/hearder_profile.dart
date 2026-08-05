import 'package:djassa/core/theme/djassa_theme.dart';
import 'package:djassa/presentation/screens/profile/widgets/helper.dart';
import 'package:djassa/presentation/screens/profile/widgets/profile_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
/// Carte d'en-tête du profil.
///
/// - Affiche un skeleton tant que [user] est null (évite le flash de
///   valeurs par défaut pendant le chargement).
/// - Masque le numéro de téléphone par défaut (`07 68 ** ** 19`), avec un
///   tap pour révéler/masquer et un appui long pour copier.
/// - Gère l'échec de chargement de l'avatar réseau sans crash visuel.
class ProfileHeaderCard extends StatefulWidget {
  const ProfileHeaderCard({
    super.key,
    required this.fullName,
    required this.roleLabel,
    required this.phoneOrEmail,
    required this.avatarUrl,
    required this.isLoading,
    required this.onEdit,
  });

  /// Nom complet déjà résolu (fallback déjà appliqué par l'appelant).
  final String fullName;
  final String roleLabel;
  final String phoneOrEmail;
  final String? avatarUrl;
  final bool isLoading;
  final VoidCallback onEdit;

  @override
  State<ProfileHeaderCard> createState() => _ProfileHeaderCardState();
}

class _ProfileHeaderCardState extends State<ProfileHeaderCard> {
  bool _phoneRevealed = false;
  bool _avatarFailed = false;

  bool get _looksLikePhone {
    final digits = widget.phoneOrEmail.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8 && digits.length == widget.phoneOrEmail.trim().length ||
        (digits.length >= 8 && !widget.phoneOrEmail.contains('@'));
  }

  String get _maskedPhone {
    final raw = widget.phoneOrEmail.replaceAll(' ', '');
    if (raw.length < 6) return widget.phoneOrEmail;
    final start = raw.substring(0, 2);
    final end = raw.substring(raw.length - 2);
    return '$start ** ** $end';
  }

  String get _displayedContact {
    if (!_looksLikePhone) return widget.phoneOrEmail;
    return _phoneRevealed ? widget.phoneOrEmail : _maskedPhone;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const _ProfileHeaderSkeleton();
    }

    final hasAvatar = widget.avatarUrl != null &&
        widget.avatarUrl!.isNotEmpty &&
        !_avatarFailed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .18),
            backgroundImage: hasAvatar ? NetworkImage(widget.avatarUrl!) : null,
            onBackgroundImageError: hasAvatar
                ? (_, __) {
                    if (mounted) setState(() => _avatarFailed = true);
                  }
                : null,
            child: hasAvatar
                ? null
                : const Icon(
                    Icons.person_rounded,
                    color: DjassaTheme.accentOrange,
                    size: 34,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fullName,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: DjassaTheme.primaryWhite),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.roleLabel,
                  style: TextStyle(
                    color: DjassaTheme.accentOrange.withValues(alpha: .9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: _looksLikePhone
                      ? () => setState(() => _phoneRevealed = !_phoneRevealed)
                      : null,
                  onLongPress: () => _copyToClipboard(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _displayedContact,
                          style: TextStyle(
                            color: DjassaTheme.primaryWhite.withValues(alpha: .72),
                          ),
                        ),
                      ),
                      if (_looksLikePhone) ...[
                        const SizedBox(width: 6),
                        Icon(
                          _phoneRevealed
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 14,
                          color: DjassaTheme.primaryWhite.withValues(alpha: .5),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: ProfileStrings.editProfileTooltip,
            style: IconButton.styleFrom(
              backgroundColor: DjassaTheme.accentOrange,
            ),
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.phoneOrEmail));
    AppSnackbar.success(context, ProfileStrings.phoneCopied);
  }
}

/// Skeleton affiché pendant le chargement de l'utilisateur, pour éviter
/// le flash de valeurs par défaut ("Client Djassa", "Compte e-commerce").
class _ProfileHeaderSkeleton extends StatefulWidget {
  const _ProfileHeaderSkeleton();

  @override
  State<_ProfileHeaderSkeleton> createState() => _ProfileHeaderSkeletonState();
}

class _ProfileHeaderSkeletonState extends State<_ProfileHeaderSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: .35, end: .75).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DjassaTheme.primaryBlack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: FadeTransition(
        opacity: _opacity,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 140, height: 18),
                  const SizedBox(height: 8),
                  _bar(width: 70, height: 12),
                  const SizedBox(height: 6),
                  _bar(width: 110, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}