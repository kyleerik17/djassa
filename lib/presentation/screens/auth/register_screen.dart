import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_navigation.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/user_role.dart';

import '../../../domain/entities/user.dart';

import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

import '../../widgets/buttons/djassa_button.dart';
import '../../widgets/inputs/djassa_text_field.dart';

/// Écran d'inscription Djassa — version multi-étapes.
///
/// Étape 1 : Informations personnelles (nom, prénom, téléphone, email)
/// Étape 2 : Type de profil (client / livreur / vendeur)
/// Étape 3 : Sécurité (mot de passe + conditions d'utilisation)
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const int _stepCount = 3;

  final _pageController = PageController();
  int _currentStep = 0;

  // Une clé de formulaire distincte par étape : on ne valide que les
  // champs visibles à l'écran, pas tout le formulaire d'un coup.
  final _step1FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

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
    _pageController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Navigation entre étapes ──────────────────────────────────────────────

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: DjassaMotion.normal,
      curve: DjassaMotion.emphasized,
    );
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (!_step1FormKey.currentState!.validate()) return;
      _goToStep(1);
      return;
    }
    if (_currentStep == 1) {
      // Pas de validation de formulaire ici : un rôle est toujours
      // sélectionné par défaut (SegmentedButton à choix unique).
      _goToStep(2);
      return;
    }
    // Étape 3 : dernière étape, on soumet.
    _handleRegister();
  }

  void _handleBack() {
    if (_currentStep == 0) {
      context.pop();
      return;
    }
    _goToStep(_currentStep - 1);
  }

  // ── REGISTER USER ────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!_step3FormKey.currentState!.validate()) {
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

            context.go(UserRole.homeRoute(user));
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
        title: const Text('Créer un compte'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepProgressBar(
              currentStep: _currentStep,
              stepCount: _stepCount,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _Step1PersonalInfo(
                    formKey: _step1FormKey,
                    nameController: _nameController,
                    surnameController: _surnameController,
                    phoneController: _phoneController,
                    emailController: _emailController,
                  ),
                  _Step2ProfileType(
                    selectedRole: _selectedRole,
                    onRoleChanged: (role) =>
                        setState(() => _selectedRole = role),
                  ),
                  _Step3Security(
                    formKey: _step3FormKey,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    obscurePassword: _obscurePassword,
                    obscureConfirmPassword: _obscureConfirmPassword,
                    onTogglePassword: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    onToggleConfirmPassword: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    acceptTerms: _acceptTerms,
                    onAcceptTermsChanged: (value) =>
                        setState(() => _acceptTerms = value),
                  ),
                ],
              ),
            ),

            // ── Barre d'action bas de page ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  DjassaButton(
                    text: _currentStep == _stepCount - 1
                        ? "S'inscrire"
                        : 'Continuer',
                    isLoading: authState.isLoading,
                    onPressed: _handleNext,
                  ),
                  if (_currentStep == 0) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Déjà un compte ?',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => context.toLogin(),
                          child: const Text('Se connecter'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre de progression ────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.currentStep,
    required this.stepCount,
  });

  final int currentStep;
  final int stepCount;

  static const _labels = ['Informations', 'Profil', 'Sécurité'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        children: [
          Row(
            children: List.generate(stepCount, (index) {
              final isActive = index <= currentStep;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == stepCount - 1 ? 0 : 8,
                  ),
                  child: AnimatedContainer(
                    duration: DjassaMotion.fast,
                    curve: DjassaMotion.emphasized,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isActive
                          ? DjassaTheme.accentOrange
                          : DjassaTheme.borderMedium,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Étape ${currentStep + 1}/$stepCount · ${_labels[currentStep]}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DjassaTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Étape 1 : Informations personnelles ─────────────────────────────────────

class _Step1PersonalInfo extends StatelessWidget {
  const _Step1PersonalInfo({
    required this.formKey,
    required this.nameController,
    required this.surnameController,
    required this.phoneController,
    required this.emailController,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController surnameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vos informations',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre compte pour accéder à nos pièces premium',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),

            /// NOM
            DjassaTextField(
              controller: nameController,
              label: 'Nom',
              prefixIcon: const Icon(Icons.person_outline),
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
              controller: surnameController,
              label: 'Prénom',
              prefixIcon: const Icon(Icons.person_outline),
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
              controller: phoneController,
              label: 'Numéro de téléphone',
              prefixIcon: const Icon(Icons.phone_outlined),
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
              controller: emailController,
              label: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
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
          ],
        ),
      ),
    );
  }
}

// ── Étape 2 : Type de profil ────────────────────────────────────────────────

class _Step2ProfileType extends StatelessWidget {
  const _Step2ProfileType({
    required this.selectedRole,
    required this.onRoleChanged,
  });

  final String selectedRole;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quel est votre profil ?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez comment vous allez utiliser Djassa.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          _RoleCard(
            icon: Icons.person_outline_rounded,
            title: 'Client',
            subtitle: 'Commandes, favoris et adresses de livraison.',
            selected: selectedRole == UserRole.client,
            onTap: () => onRoleChanged(UserRole.client),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.delivery_dining_rounded,
            title: 'Livreur',
            subtitle: 'Permis et véhicule sur votre espace dédié.',
            selected: selectedRole == UserRole.courier,
            onTap: () => onRoleChanged(UserRole.courier),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.storefront_outlined,
            title: 'Vendeur',
            subtitle: 'Votre boutique est liée via la table structures.',
            selected: selectedRole == UserRole.vendor,
            onTap: () => onRoleChanged(UserRole.vendor),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: DjassaMotion.fast,
        curve: DjassaMotion.emphasized,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? DjassaTheme.accentOrange.withValues(alpha: .1)
              : DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? DjassaTheme.accentOrange : DjassaTheme.borderMedium,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected
                  ? DjassaTheme.accentOrange.withValues(alpha: .18)
                  : DjassaTheme.secondaryWhite,
              child: Icon(
                icon,
                color: selected
                    ? DjassaTheme.accentOrange
                    : DjassaTheme.textSecondary,
              ),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? DjassaTheme.accentOrange
                  : DjassaTheme.borderMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Étape 3 : Sécurité ───────────────────────────────────────────────────────

class _Step3Security extends StatelessWidget {
  const _Step3Security({
    required this.formKey,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.acceptTerms,
    required this.onAcceptTermsChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final bool acceptTerms;
  final ValueChanged<bool> onAcceptTermsChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sécurisez votre compte',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choisissez un mot de passe pour protéger votre compte.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),

            /// PASSWORD
            DjassaTextField(
              controller: passwordController,
              label: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              obscureText: obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onTogglePassword,
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
              controller: confirmPasswordController,
              label: 'Confirmer le mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              obscureText: obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleConfirmPassword,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez confirmer votre mot de passe';
                }
                if (value != passwordController.text) {
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
                  value: acceptTerms,
                  onChanged: (value) => onAcceptTermsChanged(value ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onAcceptTermsChanged(!acceptTerms),
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
                          TextSpan(text: ' et la '),
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
          ],
        ),
      ),
    );
  }
}
