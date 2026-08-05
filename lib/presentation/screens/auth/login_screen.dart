// ignore_for_file: deprecated_member_use

import 'package:djassa/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_navigation.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSocialLoading = false;
  bool _isSubmitting = false;
  
  // Animation Controller pour les effets d'entrée
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
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

  UserModel _convertSupabaseUserToModel(User? supabaseUser, {Map<String, dynamic>? extraData}) {
    if (supabaseUser == null) {
      return UserModel(
        id: '', name: 'Inconnu', surname: '', phone: '', 
        email: null, role: 'client', createdAt: DateTime.now(),
      );
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
    FocusScope.of(context).unfocus(); // Ferme le clavier

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final identifier = _identifierController.text.trim();

      final result = await ref.read(userRepositoryProvider).login(
            identifier: identifier,
            password: _passwordController.text,
          );

      if (!mounted) return;

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
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
              email: data['email'] ?? (_isEmail(identifier) ? identifier : null),
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
      await supabase.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.djassa://login-callback/',
      );
      final sbUser = supabase.auth.currentUser;
      if (sbUser != null && mounted) {
        final userModel = _convertSupabaseUserToModel(sbUser);
        await ref.read(authNotifierProvider.notifier).loginUser(userModel);
        if (mounted) context.go(UserRole.homeRoute(userModel));
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Erreur de connexion sociale'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isSubmitting || _isSocialLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      resizeToAvoidBottomInset: true, // Important pour le clavier
      body: SafeArea(
        child: Stack(
          children: [
            // Fond Dégradé Animé Subtil
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
                ),
              ),
            ),
            
            // Cercles décoratifs flous
            Positioned(
              top: -10.h, right: -15.w,
              child: BlurHashCircle(color: DjassaTheme.accentOrange, size: 50.w),
            ),
            Positioned(
              bottom: -10.h, left: -15.w,
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
                        // Logo avec ombre portée colorée
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          builder: (_, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
                                decoration: BoxDecoration(
                                  color: Colors.white, 
                                  borderRadius: BorderRadius.circular(3.w),
                                  boxShadow: [
                                    BoxShadow(
                                      color: DjassaTheme.accentOrange.withOpacity(0.3 * value), 
                                      blurRadius: 20 * value, 
                                      offset: Offset(0, 6 * value)
                                    )
                                  ],
                                ),
                                child: Image.asset(AppConstants.logoAsset, height: 7.h, fit: BoxFit.contain),
                              ),
                            );
                          },
                        ),
                        
                        SizedBox(height: 1.5.h),
                        
                        Text(
                          "Achetez. Vendez. Partout\nen Côte d'Ivoire.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85), 
                            fontWeight: FontWeight.w600, 
                            fontSize: 3.5.w, 
                            height: 1.3
                          ),
                        ),
                        
                        SizedBox(height: 3.h),
                        
                        // Carte de Formulaire
                        Container(
                          width: double.infinity, 
                          padding: EdgeInsets.all(5.w),
                          decoration: BoxDecoration(
                            color: Colors.white, 
                            borderRadius: BorderRadius.circular(4.w),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2), 
                                blurRadius: 25, 
                                offset: const Offset(0, 10)
                              )
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Connexion', 
                                  style: TextStyle(
                                    color: Colors.black87, 
                                    fontSize: 6.w, 
                                    fontWeight: FontWeight.w900
                                  )
                                ),
                                SizedBox(height: 2.h),
                                
                                _AnimatedTextField(
                                  controller: _identifierController,
                                  label: 'Email ou téléphone',
                                  icon: Icons.alternate_email_rounded,
                                  hint: '+225 07 12 34 56 78',
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !isLoading,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Entrez votre email ou téléphone';
                                    final v = value.trim();
                                    if (!_isEmail(v) && !_isPhone(v)) return 'Format invalide';
                                    return null;
                                  },
                                ),
                                
                                SizedBox(height: 2.h),
                                
                                _AnimatedTextField(
                                  controller: _passwordController,
                                  label: 'Mot de passe',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  enabled: !isLoading,
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 5.w, color: Colors.grey),
                                    onPressed: isLoading ? null : () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Entrez votre mot de passe';
                                    if (value.length < 6) return 'Minimum 6 caractères';
                                    return null;
                                  },
                                ),
                                
                                SizedBox(height: 1.h),
                                
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                   onPressed: isLoading ? null : () => context.toForgotPassword(),
                                    child: Text(
                                      'Mot de passe oublié ?', 
                                      style: TextStyle(
                                        color: DjassaTheme.accentOrange, 
                                        fontWeight: FontWeight.w700, 
                                        fontSize: 3.2.w
                                      )
                                    ),
                                  ),
                                ),
                                
                                SizedBox(height: 1.h),
                                
                                // Bouton Connexion Animé
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2.5.w),
                                    boxShadow: isLoading 
                                      ? [] 
                                      : [BoxShadow(color: DjassaTheme.accentOrange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                                  ),
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: DjassaTheme.accentOrange, 
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.5.w)),
                                    ),
                                    onPressed: isLoading ? null : _handleLogin,
                                    child: isLoading
                                        ? SizedBox(width: 5.w, height: 5.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text('Se connecter', style: TextStyle(fontSize: 4.2.w, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 2.5.h),
                        
                        // Séparateur
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1)),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 3.w), child: Text('ou continuer avec', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 3.2.w))),
                            Expanded(child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1)),
                          ],
                        ),
                        
                        SizedBox(height: 2.h),
                        
                        // Boutons Sociaux
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SocialButton(
                              icon: Icons.g_mobiledata_rounded,
                              label: 'Google',
                              isLoading: _isSocialLoading,
                              onPressed: () => _handleSocialSignIn(OAuthProvider.google),
                            ),
                            SizedBox(width: 4.w),
                            _SocialButton(
                              icon: Icons.apple_rounded,
                              label: 'Apple',
                              isLoading: _isSocialLoading,
                              onPressed: () => _handleSocialSignIn(OAuthProvider.apple),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 2.5.h),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Pas de compte ?', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 3.5.w)),
                            TextButton(
                              onPressed: isLoading ? null : () => context.toRegister(),
                              child: Text('Créer un compte', style: TextStyle(color: DjassaTheme.accentOrange, fontWeight: FontWeight.w800, fontSize: 3.5.w)),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h), // Espace pour le clavier
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
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 3.5.w, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 5.w, color: Colors.grey.shade600),
        suffixIcon: suffixIcon,
        filled: true, 
        fillColor: const Color(0xFFF5F5F7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(2.5.w), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2.5.w), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2.5.w), 
          borderSide: const BorderSide(color: DjassaTheme.accentOrange, width: 2)
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2.5.w), 
          borderSide: BorderSide(color: Colors.red.shade300, width: 1)
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
      ),
      validator: validator,
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
          foregroundColor: Colors.white, 
          backgroundColor: Colors.white.withOpacity(0.05),
          padding: EdgeInsets.symmetric(vertical: 1.5.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.5.w)),
        ),
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(width: 4.w, height: 4.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon, size: 5.5.w),
        label: Flexible(child: Text(label, style: TextStyle(fontSize: 3.5.w, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
      ),
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
