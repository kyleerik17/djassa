import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/djassa_theme.dart';

/// Champ de texte premium de l'application Djassa
class DjassaTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool autofocus;

  const DjassaTextField({
    Key? key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onTap,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.errorText,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cabin',
              color: DjassaTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: enabled
                ? DjassaTheme.backgroundPrimary
                : DjassaTheme.secondaryWhite,
            borderRadius: BorderRadius.circular(DjassaTheme.radiusSmall),
            border: Border.all(
              color: errorText != null
                  ? Colors.red
                  : enabled
                      ? DjassaTheme.borderLight
                      : DjassaTheme.borderMedium,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: obscureText,
            enabled: enabled,
            readOnly: readOnly,
            maxLines: maxLines,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            autofocus: autofocus,
            onTap: onTap,
            onChanged: onChanged,
            validator: validator,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Cabin',
              color: DjassaTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                fontFamily: 'Cabin',
                color: DjassaTheme.textSecondary,
              ),
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: prefixIcon,
                    )
                  : null,
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: InputBorder.none,
              errorText: null, // Géré externement
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Cabin',
              color: Colors.red,
            ),
          ),
        ],
      ],
    );
  }
}

/// Champ de recherche avec style premium
class DjassaSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final void Function(String)? onChanged;
  final VoidCallback? onFilterTap;
  final bool isEnabled;

  const DjassaSearchField({
    Key? key,
    this.controller,
    this.hint = 'Rechercher...',
    this.onChanged,
    this.onFilterTap,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DjassaTheme.backgroundPrimary,
        border: Border.all(color: DjassaTheme.borderLight),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: isEnabled,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.white,
          hintText: hint,
          hintStyle: const TextStyle(
            color: DjassaTheme.textSecondary,
            fontFamily: 'Cabin',
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(
              Icons.search,
              size: 20,
              color: DjassaTheme.textPrimary,
            ),
          ),
          suffixIcon: onFilterTap != null
              ? IconButton(
                  onPressed: onFilterTap,
                  icon: const Icon(Icons.tune, size: 20),
                  color: DjassaTheme.textPrimary,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(
          color: DjassaTheme.textPrimary,
          fontFamily: 'Cabin',
          fontSize: 14,
        ),
      ),
    );
  }
}
