import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/djassa_theme.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

// Réutilisation des tokens pour la cohérence (ou importe-les depuis l'autre fichier)
class _Radius {
  static const sm = 16.0;
  static const lg = 24.0;
}

class _Gap {
  static const sm = 8.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

class VendorEditProfileScreen extends ConsumerStatefulWidget {
  const VendorEditProfileScreen({super.key});

  @override
  ConsumerState<VendorEditProfileScreen> createState() => _VendorEditProfileScreenState();
}

class _VendorEditProfileScreenState extends ConsumerState<VendorEditProfileScreen> {
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
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 900);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedAvatar = file;
      _avatarBytes = bytes;
    });
  }

  Future<String?> _uploadAvatar(User user) async {
    if (_pickedAvatar == null || _avatarBytes == null) return user.avatarUrl;

    final extension = _pickedAvatar!.name.split('.').last.toLowerCase();
    final safeExtension = ['jpg', 'jpeg', 'png', 'webp'].contains(extension) ? extension : 'jpg';
    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await SupabaseService.client.storage.from('avatars').uploadBinary(
      path,
      _avatarBytes!,
      fileOptions: FileOptions(contentType: 'image/$safeExtension', upsert: true),
    );

    return SupabaseService.client.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final current = ref.read(authNotifierProvider).user;
    if (current == null) return;

    setState(() => _isSaving = true);
    try {
      final avatarUrl = await _uploadAvatar(current);
      final updated = current.copyWith(
        name: _nameController.text.trim(),
        surname: _surnameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        avatarUrl: avatarUrl,
      );

      final result = await ref.read(updateProfileProvider)(updated);
      result.fold(
        (failure) => throw Exception(failure.message),
        (_) {},
      );
      await ref.read(authNotifierProvider.notifier).refreshUser();

      if (!mounted) return;
      Navigator.pop(context); // Retour à l'écran précédent avec animation inverse
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1FA463),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_Radius.sm)),
          content: const Text('Profil mis à jour avec succès', style: TextStyle(color: Colors.white)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE0453C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_Radius.sm)),
          content: Text('Erreur : $e', style: const TextStyle(color: Colors.white)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Modifier le profil', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: DjassaTheme.primaryWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(_Gap.lg),
        children: [
          Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(_Gap.lg),
              decoration: BoxDecoration(
                color: DjassaTheme.primaryWhite,
                borderRadius: BorderRadius.circular(_Radius.lg),
                border: Border.all(color: DjassaTheme.borderMedium),
              ),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: DjassaTheme.accentOrange.withValues(alpha: .13),
                          backgroundImage: _avatarBytes != null
                              ? MemoryImage(_avatarBytes!)
                              : (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(user.avatarUrl!) as ImageProvider
                                  : null,
                          child: _avatarBytes == null && (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                              ? const Icon(Icons.storefront_rounded, color: DjassaTheme.accentOrange, size: 48)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: DjassaTheme.accentOrange),
                            onPressed: _pickAvatar,
                            icon: const Icon(Icons.camera_alt_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _Gap.xl),
                  _Field(controller: _nameController, label: 'Nom', icon: Icons.person_outline_rounded),
                  _Field(controller: _surnameController, label: 'Prénom', icon: Icons.badge_outlined),
                  _Field(
                    controller: _phoneController,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  _Field(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: _Gap.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: DjassaTheme.accentOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_Radius.sm)),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer les modifications'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, required this.icon, this.keyboardType});

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _Gap.lg),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: DjassaTheme.accentOrange),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(_Radius.sm)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_Radius.sm),
            borderSide: const BorderSide(color: DjassaTheme.accentOrange, width: 2),
          ),
        ),
      ),
    );
  }
}