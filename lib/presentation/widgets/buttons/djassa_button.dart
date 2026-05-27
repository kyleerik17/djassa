import 'package:flutter/material.dart';
import '../../../core/theme/djassa_theme.dart';

/// Bouton principal premium de l'application Djassa
class DjassaButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isEnabled;
  final IconData? icon;
  final double? width;
  final double? height;

  const DjassaButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isEnabled = true,
    this.icon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 50,
      child: isOutlined ? _buildOutlinedButton() : _buildFilledButton(),
    );
  }

  Widget _buildFilledButton() {
    return ElevatedButton(
      onPressed: isEnabled && !isLoading ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isEnabled ? DjassaTheme.primaryBlack : DjassaTheme.textLight,
        foregroundColor: DjassaTheme.primaryWhite,
        elevation: isEnabled ? 2 : 0,
        shadowColor: DjassaTheme.primaryBlack.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DjassaTheme.radiusSmall),
        ),
      ),
      child: _buildChild(),
    );
  }

  Widget _buildOutlinedButton() {
    return OutlinedButton(
      onPressed: isEnabled && !isLoading ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor:
            isEnabled ? DjassaTheme.primaryBlack : DjassaTheme.textLight,
        side: BorderSide(
          color: isEnabled ? DjassaTheme.primaryBlack : DjassaTheme.textLight,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DjassaTheme.radiusSmall),
        ),
      ),
      child: _buildChild(),
    );
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cabin',
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: 'Cabin',
      ),
    );
  }
}

/// Bouton icône flottant
class DjassaIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final bool isEnabled;

  const DjassaIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? DjassaTheme.primaryBlack,
        shape: BoxShape.circle,
        boxShadow: isEnabled ? DjassaTheme.shadowMedium : null,
      ),
      child: IconButton(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(
          icon,
          color: iconColor ?? DjassaTheme.primaryWhite,
          size: size * 0.5,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
