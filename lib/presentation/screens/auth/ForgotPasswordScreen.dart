import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_navigation.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();

  bool _isSubmitting = false;
  bool _isSuccess = false;
  String _maskedEmail = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: DjassaMotion.slow,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: DjassaMotion.entrance,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: DjassaMotion.emphasized,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _isPhone(String value) {
    final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
    return phoneRegex.hasMatch(value.replaceAll(' ', ''));
  }

  bool _isEmail(String value) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(value);
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final name = parts[0];
    final visible = name.length <= 2 ? name : name.substring(0, 2);
    return '$visible${'*' * (name.length - visible.length)}@${parts[1]}';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleResetRequest() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    final identifier = _identifierController.text.trim();

    // Pour le moment, seul le reset par email est actif.
    if (!_isEmail(identifier)) {
      setState(() => _isSubmitting = false);
      _showError(
        'La réinitialisation par téléphone arrive bientôt. '
        'Utilisez votre email pour le moment, ou contactez le support.',
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        identifier,
        redirectTo: 'io.supabase.djassa://reset-callback/',
      );
      if (!mounted) return;
      setState(() {
        _maskedEmail = _maskEmail(identifier);
        _isSuccess = true;
      });
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Une erreur est survenue. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleResend() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _identifierController.text.trim(),
        redirectTo: 'io.supabase.djassa://reset-callback/',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email renvoyé avec succès.'),
            backgroundColor: DjassaTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Une erreur est survenue. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
                ),
              ),
            ),
            Positioned(
              top: -10.h,
              right: -15.w,
              child:
                  BlurHashCircle(color: DjassaTheme.accentOrange, size: 50.w),
            ),
            Positioned(
              bottom: -10.h,
              left: -15.w,
              child: BlurHashCircle(color: Colors.blue.shade900, size: 40.w),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: DjassaMotion.slow,
                          curve: DjassaMotion.emphasized,
                          builder: (_, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 1.5.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3.w),
                                  boxShadow: [
                                    BoxShadow(
                                      color: DjassaTheme.accentOrange
                                          .withOpacity(0.3 * value),
                                      blurRadius: 20 * value,
                                      offset: Offset(0, 6 * value),
                                    )
                                  ],
                                ),
                                child: Image.asset(AppConstants.logoAsset,
                                    height: 7.h, fit: BoxFit.contain),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 3.h),
                        AnimatedSwitcher(
                          duration: DjassaMotion.normal,
                          switchInCurve: DjassaMotion.emphasized,
                          switchOutCurve: DjassaMotion.exit,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.05, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: Container(
                            key: ValueKey(_isSuccess),
                            width: double.infinity,
                            padding: EdgeInsets.all(5.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4.w),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            child: _isSuccess
                                ? _buildSuccessView()
                                : _buildFormView(),
                          ),
                        ),
                        SizedBox(height: 2.5.h),
                        TextButton.icon(
                          onPressed: () => context.backOr(AppNavigation.login),
                          icon: Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white.withOpacity(0.7), size: 4.w),
                          label: Text(
                            'Retour à la connexion',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 3.5.w,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mot de passe oublié ?',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 6.w,
                fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 1.5.h),
          Text(
            'Entrez votre email associé à votre compte pour recevoir un lien de réinitialisation.',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 3.5.w, height: 1.4),
          ),
          SizedBox(height: 3.h),
          _AnimatedTextField(
            controller: _identifierController,
            label: 'Email ou téléphone',
            icon: Icons.alternate_email_rounded,
            hint: 'exemple@djassa.ci',
            keyboardType: TextInputType.emailAddress,
            enabled: !_isSubmitting,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ce champ est requis';
              }
              final v = value.trim();
              if (!_isEmail(v) && !_isPhone(v)) {
                return 'Format invalide';
              }
              return null;
            },
          ),
          SizedBox(height: 1.h),
          Text(
            'La réinitialisation par téléphone arrive bientôt.',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 3.w,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 2.h),
          AnimatedContainer(
            duration: DjassaMotion.fast,
            curve: DjassaMotion.emphasized,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2.5.w),
              boxShadow: _isSubmitting
                  ? []
                  : [
                      BoxShadow(
                        color: DjassaTheme.accentOrange.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: DjassaTheme.accentOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2.5.w)),
              ),
              onPressed: _isSubmitting ? null : _handleResetRequest,
              child: _isSubmitting
                  ? SizedBox(
                      width: 5.w,
                      height: 5.w,
                      child: const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Envoyer le lien',
                      style: TextStyle(
                          fontSize: 4.2.w, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: DjassaTheme.accentGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded,
              color: DjassaTheme.accentGreen, size: 15.w),
        ),
        SizedBox(height: 2.h),
        Text(
          'Vérifiez votre boîte !',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.black87,
              fontSize: 6.w,
              fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 1.5.h),
        Text(
          'Nous avons envoyé les instructions de réinitialisation à :\n$_maskedEmail',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.grey.shade600, fontSize: 3.5.w, height: 1.4),
        ),
        SizedBox(height: 3.h),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: DjassaTheme.accentOrange,
            side: const BorderSide(color: DjassaTheme.accentOrange),
            padding: EdgeInsets.symmetric(vertical: 1.5.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2.5.w)),
          ),
          onPressed: _isSubmitting ? null : _handleResend,
          child: Text('Renvoyer',
              style: TextStyle(fontSize: 3.8.w, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// WIDGETS UI AUXILIAIRES
// ─────────────────────────────────────────────────────────────────────────

class _AnimatedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool enabled;
  final String? Function(String?)? validator;

  const _AnimatedTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(
          fontWeight: FontWeight.w600, fontSize: 3.5.w, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 5.w, color: Colors.grey.shade600),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF5F5F7),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2.5.w),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2.5.w),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2.5.w),
          borderSide:
              const BorderSide(color: DjassaTheme.accentOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2.5.w),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
      ),
      validator: validator,
    );
  }
}

class BlurHashCircle extends StatelessWidget {
  final Color color;
  final double size;

  const BlurHashCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.15), Colors.transparent],
          stops: const [0.4, 1.0],
        ),
      ),
    );
  }
}
