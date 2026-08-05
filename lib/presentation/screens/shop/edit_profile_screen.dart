import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../core/utils/constants.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shop/shop_widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _avatarBytes;
  XFile? _pickedAvatar;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).user;
    _nameController.text = user?.name ?? '';
    _surnameController.text = user?.surname ?? '';
    _phoneController.text = user?.phone ?? '';
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 900,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _pickedAvatar = file;
      _avatarBytes = bytes;
    });
  }

  /// Upload la photo dans Supabase Storage et retourne l'URL publique.
  /// Supprime l'ancien avatar si un nouveau est sélectionné.
  Future<String?> _uploadAvatar(User user) async {
    if (_pickedAvatar == null || _avatarBytes == null) {
      return user.avatarUrl;
    }

    final extension = _pickedAvatar!.name.split('.').last.toLowerCase();
    final safeExtension =
        ['jpg', 'jpeg', 'png', 'webp'].contains(extension) ? extension : 'jpg';
    final path =
        '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    // Upload du nouveau fichier
    await SupabaseService.client.storage.from('avatars').uploadBinary(
          path,
          _avatarBytes!,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _pickedAvatar!.mimeType ?? 'image/$safeExtension',
          ),
        );

    final publicUrl =
        SupabaseService.client.storage.from('avatars').getPublicUrl(path);

    // Mise à jour directe de avatar_url dans profiles
    await SupabaseService.client
        .from('profiles')
        .update({'avatar_url': publicUrl}).eq('id', user.id);

    return publicUrl;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(authNotifierProvider).user;
    if (currentUser == null) {
      context.go(AppConstants.loginRoute);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Upload avatar et récupérer l'URL (déjà persistée dans profiles)
      final avatarUrl = await _uploadAvatar(currentUser);

      // 2. Construire l'utilisateur mis à jour avec la nouvelle URL
      final updatedUser = currentUser.copyWith(
        name: _nameController.text.trim(),
        surname: _surnameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        avatarUrl: avatarUrl,
      );

      // 3. Mettre à jour le reste du profil via le repository
      final result = await ref.read(updateProfileProvider)(updatedUser);

      if (!mounted) return;

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        },
        (user) {
          ref.read(authNotifierProvider.notifier).updateUser(user);
          ref.invalidate(ordersProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour'),
              backgroundColor: Colors.green,
            ),
          );
          context.go(AppConstants.profileRoute);
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final displayName = [_nameController.text.trim(), _surnameController.text.trim()]
        .where((part) => part.isNotEmpty)
        .join(' ');

    return ShopScaffold(
      currentIndex: 4,
      showSellButton: false,
      title: 'Modifier profil',
      showBackButton: true,
      child: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _AvatarPicker(
              avatarBytes: _avatarBytes,
              avatarUrl: user?.avatarUrl,
              displayName: displayName.isEmpty ? user?.email : displayName,
              onTap: _pickAvatar,
            ),
            const SizedBox(height: 32),

            const SectionTitle(title: 'Informations personnelles'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ProfileField(
                    controller: _nameController,
                    label: 'Nom',
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProfileField(
                    controller: _surnameController,
                    label: 'Prénom',
                    icon: Icons.badge_outlined,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const SectionTitle(title: 'Coordonnées'),
            const SizedBox(height: 12),
            _ProfileField(
              controller: _phoneController,
              label: 'Téléphone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            _ProfileField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DjassaTheme.accentOrange,
                  disabledBackgroundColor:
                      DjassaTheme.accentOrange.withValues(alpha: .5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving ? 'Sauvegarde...' : 'Enregistrer',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}

/// Avatar mis en valeur : anneau dégradé, ombre douce, bouton caméra
/// détaché avec sa propre ombre, et petit rappel du nom en dessous
/// pour donner un retour visuel immédiat pendant la saisie.
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.avatarBytes,
    required this.avatarUrl,
    required this.displayName,
    required this.onTap,
  });

  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final String? displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasNetworkAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final hasAnyAvatar = avatarBytes != null || hasNetworkAvatar;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        DjassaTheme.accentOrange,
                        DjassaTheme.accentOrange.withValues(alpha: .35),
                      ],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: DjassaTheme.primaryWhite,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor:
                          DjassaTheme.accentOrange.withValues(alpha: .12),
                      backgroundImage: avatarBytes != null
                          ? MemoryImage(avatarBytes!)
                          : hasNetworkAvatar
                              ? NetworkImage(avatarUrl!) as ImageProvider
                              : null,
                      child: hasAnyAvatar
                          ? null
                          : const Icon(
                              Icons.person_rounded,
                              color: DjassaTheme.accentOrange,
                              size: 48,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DjassaTheme.primaryWhite,
                      boxShadow: DjassaTheme.shadowLight,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: DjassaTheme.accentOrange,
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName?.trim().isNotEmpty == true
                ? displayName!.trim()
                : 'Ajouter une photo de profil',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: DjassaTheme.textPrimary.withValues(alpha: .85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Touchez la photo pour la modifier',
            style: TextStyle(
              fontSize: 12,
              color: DjassaTheme.textSecondary.withValues(alpha: .8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textInputAction: textInputAction,
        style: const TextStyle(fontWeight: FontWeight.w600),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Champ obligatoire';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: DjassaTheme.textPrimary.withValues(alpha: .45),
            size: 20,
          ),
          filled: true,
          fillColor: DjassaTheme.primaryWhite,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: DjassaTheme.borderMedium),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: DjassaTheme.borderMedium),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: DjassaTheme.accentOrange, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade300),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.6),
          ),
        ),
      ),
    );
  }
}