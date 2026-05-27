import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/djassa_theme.dart';
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
        .update({'avatar_url': publicUrl})
        .eq('id', user.id);

    return publicUrl;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(authNotifierProvider).user;
    if (currentUser == null) {
      context.go('/login');
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
          context.go('/profile');
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

    return ShopScaffold(
      currentIndex: 4,
      title: 'Modifier profil',
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 58,
                    backgroundColor:
                        DjassaTheme.accentOrange.withValues(alpha: .13),
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (user?.avatarUrl != null &&
                                user!.avatarUrl!.trim().isNotEmpty)
                            ? NetworkImage(user.avatarUrl!) as ImageProvider
                            : null,
                    child: _avatarBytes == null &&
                            (user?.avatarUrl == null ||
                                user!.avatarUrl!.trim().isEmpty)
                        ? const Icon(
                            Icons.person_rounded,
                            color: DjassaTheme.accentOrange,
                            size: 54,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: DjassaTheme.accentOrange,
                      ),
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.camera_alt_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ProfileField(
              controller: _nameController,
              label: 'Nom',
              icon: Icons.person_outline_rounded,
            ),
            _ProfileField(
              controller: _surnameController,
              label: 'Prénom',
              icon: Icons.badge_outlined,
            ),
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
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DjassaTheme.accentOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Sauvegarde...' : 'Enregistrer'),
              ),
            ),
            const SizedBox(height: 88),
          ],
        ),
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
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Champ obligatoire';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          fillColor: DjassaTheme.primaryWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}