// ignore_for_file: deprecated_member_use

import 'dart:ui'; // Pour BackdropFilter (effet de flou)
import 'package:djassa/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Recommandé pour les vrais logos

import '../../../core/router/app_navigation.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSocialLoading = false;
  bool _isSubmitting = false;

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
        parent: _animationController, curve: DjassaMotion.emphasized);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _animationController, curve: DjassaMotion.emphasized));

    _animationController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _isPhone(String value) =>
      RegExp(r'^\+?[0-9]{8,15}$').hasMatch(value.replaceAll(' ', ''));
  bool _isEmail(String value) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);

  UserModel _convertSupabaseUserToModel(User? supabaseUser,
      {Map<String, dynamic>? extraData}) {
    if (supabaseUser == null) {
      return UserModel(
          id: '',
          name: 'Inconnu',
          surname: '',
          phone: '',
          email: null,
          role: 'client',
          createdAt: DateTime.now());
    }
    final metadata = supabaseUser.userMetadata ?? {};
    return UserModel(
      id: supabaseUser.id,
      email: supabaseUser.email,
      name: extraData?['name'] ?? metadata['name'] ?? 'Utilisateur',
      surname: extraData?['surname'] ?? metadata['surname'] ?? '',
      phone: extraData?['phone'] ?? metadata['phone'] ?? '',
      avatarUrl: metadata['avatar_url'],
      isVerified: supabaseUser.emailConfirmedAt != null,
      role: extraData?['role'] ?? 'client',
      createdAt: DateTime.tryParse(supabaseUser.createdAt) ?? DateTime.now(),
    );
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final identifier = _identifierController.text.trim();
      final result = await ref.read(userRepositoryProvider).login(
            identifier: identifier,
            password: _passwordController.text,
          );

      if (!mounted) return;

      result.fold(
        (failure) => _showErrorSnackBar(failure.message),
        (data) async {
          try {
            final userModel = UserModel.fromJson(data);
            await authNotifier.loginUser(userModel);
            if (mounted) context.go(UserRole.homeRoute(userModel));
          } catch (e) {
            final user = UserModel(
              id: data['id'] ?? '1',
              name: data['name'] ?? 'Utilisateur',
              surname: data['surname'] ?? '',
              phone: data['phone'] ?? (_isPhone(identifier) ? identifier : ''),
              email:
                  data['email'] ?? (_isEmail(identifier) ? identifier : null),
              isVerified: data['is_verified'] ?? false,
              role: data['role'] ?? 'client',
              createdAt: DateTime.now(),
            );
            await authNotifier.loginUser(user);
            if (mounted) context.go(UserRole.homeRoute(user));
          }
        },
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSocialSignIn(OAuthProvider provider) async {
    if (_isSocialLoading) return;
    setState(() => _isSocialLoading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signInWithOAuth(provider,
          redirectTo: 'io.supabase.djassa://login-callback/');
      final sbUser = supabase.auth.currentUser;
      if (sbUser != null && mounted) {
        final userModel = _convertSupabaseUserToModel(sbUser);
        await ref.read(authNotifierProvider.notifier).loginUser(userModel);
        if (mounted) context.go(UserRole.homeRoute(userModel));
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
            e is AuthException ? e.message : 'Erreur de connexion sociale');
      }
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
        // Correction ici : gauche, haut, droite, bas
        margin: EdgeInsets.fromLTRB(5.w, 0, 5.w, 3.h),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isSubmitting || _isSocialLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Noir plus profond et élégant
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Fond avec orbes lumineuses très subtiles (Ambiance)
            Positioned(
                top: -10.h,
                right: -20.w,
                child:
                    _GlowingOrb(color: DjassaTheme.accentOrange, size: 60.w)),
            Positioned(
                bottom: -10.h,
                left: -20.w,
                child: _GlowingOrb(color: Colors.blue.shade800, size: 50.w)),

            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 2. Logo épuré avec lueur subtile

                        SizedBox(height: 2.5.h),

                        Text(
                          "Achetez. Vendez.\nPartout en Côte d'Ivoire.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                            fontSize: 5.w,
                            height: 1.4,
                            letterSpacing: 0.5,
                          ),
                        ),

                        SizedBox(height: 4.h),

                        // 3. Carte de Formulaire "Glassmorphism" sombre
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5.w),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withOpacity(0.03), // Très subtil
                                borderRadius: BorderRadius.circular(5.w),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text('Connexion',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 6.5.w,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 0.5.h),
                                    Text('Heureux de vous revoir parmi nous.',
                                        style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 3.2.w)),
                                    SizedBox(height: 3.h),

                                    _CleanTextField(
                                      controller: _identifierController,
                                      label: 'Email ou téléphone',
                                      icon: Icons.person_outline_rounded,
                                      hint: '+225 07 12 34 56 78',
                                      keyboardType: TextInputType.emailAddress,
                                      enabled: !isLoading,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Ce champ est requis';
                                        }
                                        final v = value.trim();
                                        if (!_isEmail(v) && !_isPhone(v)) {
                                          return 'Format invalide';
                                        }
                                        return null;
                                      },
                                    ),

                                    SizedBox(height: 2.h),

                                    _CleanTextField(
                                      controller: _passwordController,
                                      label: 'Mot de passe',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      enabled: !isLoading,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 5.w,
                                            color: Colors.white54),
                                        onPressed: isLoading
                                            ? null
                                            : () => setState(() =>
                                                _obscurePassword =
                                                    !_obscurePassword),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ce champ est requis';
                                        }
                                        if (value.length < 6) {
                                          return 'Minimum 6 caractères';
                                        }
                                        return null;
                                      },
                                    ),

                                    SizedBox(height: 1.h),

                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => context.toForgotPassword(),
                                        child: Text('Mot de passe oublié ?',
                                            style: TextStyle(
                                                color: DjassaTheme.accentOrange,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 3.2.w)),
                                      ),
                                    ),

                                    SizedBox(height: 2.h),

                                    // Bouton Principal avec effet de lueur au hover/focus
                                    AnimatedContainer(
                                      duration: DjassaMotion.fast,
                                      curve: DjassaMotion.emphasized,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(3.w),
                                        boxShadow: !isLoading
                                            ? [
                                                BoxShadow(
                                                    color: DjassaTheme
                                                        .accentOrange
                                                        .withOpacity(0.3),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 5))
                                              ]
                                            : [],
                                      ),
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              DjassaTheme.accentOrange,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                              vertical: 1.8.h),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(3.w)),
                                        ),
                                        onPressed:
                                            isLoading ? null : _handleLogin,
                                        child: isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.5))
                                            : Text('Se connecter',
                                                style: TextStyle(
                                                    fontSize: 4.2.w,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 3.h),

                        // Séparateur élégant
                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: Colors.white.withOpacity(0.1),
                                    thickness: 1)),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: Text('ou',
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 3.2.w,
                                        fontWeight: FontWeight.w500))),
                            Expanded(
                                child: Divider(
                                    color: Colors.white.withOpacity(0.1),
                                    thickness: 1)),
                          ],
                        ),

                        SizedBox(height: 2.5.h),

                        // Boutons Sociaux
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SocialPillButton(
                              // Remplace par FontAwesomeIcons.google si tu ajoutes le package font_awesome_flutter
                              icon: Icons.g_translate,
                              label: 'Google',
                              isLoading: _isSocialLoading,
                              onPressed: () =>
                                  _handleSocialSignIn(OAuthProvider.google),
                            ),
                            SizedBox(width: 4.w),
                            _SocialPillButton(
                              icon: Icons.apple_rounded,
                              label: 'Apple',
                              isLoading: _isSocialLoading,
                              onPressed: () =>
                                  _handleSocialSignIn(OAuthProvider.apple),
                            ),
                          ],
                        ),

                        SizedBox(height: 4.h), // Espace pour le clavier

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Pas encore de compte ?',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 3.5.w)),
                            TextButton(
                              onPressed:
                                  isLoading ? null : () => context.toRegister(),
                              child: Text('S\'inscrire',
                                  style: TextStyle(
                                      color: DjassaTheme.accentOrange,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 3.5.w)),
                            ),
                          ],
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
}

// ─────────────────────────────────────────────────────────────────────────
// WIDGETS UI AUXILIAIRES REDESIGNÉS
// ─────────────────────────────────────────────────────────────────────────

class _CleanTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool enabled;
  final String? Function(String?)? validator;

  const _CleanTextField({
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
          fontWeight: FontWeight.w500, fontSize: 3.8.w, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white38, fontSize: 3.5.w),
        prefixIcon: Icon(icon, size: 5.w, color: Colors.white54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05), // Fond très léger
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.w),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.w),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.w),
          borderSide:
              const BorderSide(color: DjassaTheme.accentOrange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.w),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.w),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
      ),
      validator: validator,
    );
  }
}

class _SocialPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SocialPillButton(
      {required this.icon,
      required this.label,
      required this.isLoading,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.03),
          padding: EdgeInsets.symmetric(vertical: 1.5.h),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
        ),
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(icon, size: 5.w),
        label: Text(label,
            style: TextStyle(fontSize: 3.5.w, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _GlowingOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowingOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
            Colors.transparent
          ],
          stops: const [0.2, 0.5, 1.0],
        ),
      ),
    );
  }
}
