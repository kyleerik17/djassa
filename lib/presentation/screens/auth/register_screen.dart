import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';

import '../../../domain/entities/user.dart';

import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

import '../../widgets/buttons/djassa_button.dart';
import '../../widgets/inputs/djassa_text_field.dart';

/// Écran d'inscription Djassa
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  String _selectedRole = 'client';

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  /// REGISTER USER
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez accepter les conditions d\'utilisation',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    try {
      final authNotifier = ref.read(
        authNotifierProvider.notifier,
      );

      final result = await ref.read(registerUserProvider).call(
            name: _nameController.text.trim(),
            surname: _surnameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text.trim(),
            role: _selectedRole,
          );

      result.fold(
        /// ERROR
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                failure.message,
              ),
              backgroundColor: Colors.red,
            ),
          );
        },

        /// SUCCESS
        (data) async {
          try {
            /// ICI user est déjà un UserModel
            final userModel = data['user'];

            /// Conversion vers Entity User
            final user = User(
              id: userModel.id,
              name: userModel.name,
              surname: userModel.surname,
              phone: userModel.phone,
              email: userModel.email,
              avatarUrl: userModel.avatarUrl,
              isVerified: userModel.isVerified,
              role: userModel.role,
              createdAt: userModel.createdAt,
            );

            /// SAVE USER
            await authNotifier.loginUser(
              user,
            );

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Compte créé avec succès',
                ),
                backgroundColor: Colors.green,
              ),
            );

            /// REDIRECT
            context.go(user.isCourier ? '/courier' : '/home');
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Erreur utilisateur : $e',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur : $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(
      authNotifierProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Créer un compte',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// HEADER
                Column(
                  children: [
                    Text(
                      'Rejoignez Djassa',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Créez votre compte pour accéder à nos pièces premium',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                /// NOM
                DjassaTextField(
                  controller: _nameController,
                  label: 'Nom',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre nom';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                /// PRENOM
                DjassaTextField(
                  controller: _surnameController,
                  label: 'Prénom',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre prénom';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                /// PHONE
                DjassaTextField(
                  controller: _phoneController,
                  label: 'Numéro de téléphone',
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre numéro';
                    }

                    if (value.length < 8) {
                      return 'Numéro invalide';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                /// EMAIL
                DjassaTextField(
                  controller: _emailController,
                  label: 'Email',
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return 'Veuillez entrer votre email';
                    }

                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(email)) {
                      return 'Email invalide';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                /// TYPE DE PROFIL
                Text(
                  'Type de profil',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'client',
                      icon: Icon(Icons.person_outline_rounded),
                      label: Text('Client'),
                    ),
                    ButtonSegment(
                      value: 'courier',
                      icon: Icon(Icons.delivery_dining_rounded),
                      label: Text('Livreur'),
                    ),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedRole = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedRole == 'courier'
                      ? 'Le profil livreur re?oit les commandes disponibles et peut les accepter.'
                      : 'Le profil client permet de passer des commandes.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                const SizedBox(height: 16),

                /// PASSWORD
                DjassaTextField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un mot de passe';
                    }

                    if (value.length < 6) {
                      return 'Le mot de passe doit contenir au moins 6 caractères';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                /// CONFIRM PASSWORD
                DjassaTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez confirmer votre mot de passe';
                    }

                    if (value != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 24),

                /// TERMS
                Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() {
                          _acceptTerms = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _acceptTerms = !_acceptTerms;
                          });
                        },
                        child: RichText(
                          text: TextSpan(
                            text: "J'accepte les ",
                            style: Theme.of(context).textTheme.bodySmall,
                            children: const [
                              TextSpan(
                                text: 'conditions d\'utilisation',
                                style: TextStyle(
                                  color: DjassaTheme.accentOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: ' et la ',
                              ),
                              TextSpan(
                                text: 'politique de confidentialité',
                                style: TextStyle(
                                  color: DjassaTheme.accentOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                /// BUTTON
                DjassaButton(
                  text: "S'inscrire",
                  isLoading: authState.isLoading,
                  onPressed: _handleRegister,
                ),

                const SizedBox(height: 24),

                /// LOGIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Déjà un compte ?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        context.go(
                          '/login',
                        );
                      },
                      child: const Text(
                        'Se connecter',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
