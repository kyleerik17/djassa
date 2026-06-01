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
import '../../widgets/vendor/vendor_scaffold.dart';

/// Édition identité vendeur — séparée du profil client.
class VendorAccountScreen extends ConsumerStatefulWidget {
  const VendorAccountScreen({super.key});

  @override
  ConsumerState<VendorAccountScreen> createState() =>
      _VendorAccountScreenState();
}

class _VendorAccountScreenState extends ConsumerState<VendorAccountScreen> {
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

  Future<String?> _uploadAvatar(User user) async {
    if (_pickedAvatar == null || _avatarBytes == null) return user.avatarUrl;

    final extension = _pickedAvatar!.name.split('.').last.toLowerCase();
    final safeExtension =
        ['jpg', 'jpeg', 'png', 'webp'].contains(extension) ? extension : 'jpg';
    final path =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await SupabaseService.client.storage.from('avatars').uploadBinary(
          path,
          _avatarBytes!,
          fileOptions: FileOptions(
            contentType: 'image/$safeExtension',
            upsert: true,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte vendeur mis à jour.')),
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

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logoutUser();
    if (mounted) context.go(AppConstants.loginRoute);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;

    if (user == null || !user.isVendor) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go(AppConstants.loginRoute),
            child: const Text('Se connecter'),
          ),
        ),
      );
    }

    return VendorScaffold(
      currentIndex: 2,
      title: 'Compte vendeur',
      actions: [
        IconButton(
          tooltip: 'Déconnexion',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: DjassaTheme.primaryBlack,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil vendeur',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DjassaTheme.primaryWhite,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Identité liée à votre boutique (table profiles).',
                  style: TextStyle(
                    color: DjassaTheme.primaryWhite.withValues(alpha: .68),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DjassaTheme.primaryWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: DjassaTheme.borderMedium),
              ),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor:
                              DjassaTheme.accentOrange.withValues(alpha: .13),
                          backgroundImage: _avatarBytes != null
                              ? MemoryImage(_avatarBytes!)
                              : (user.avatarUrl != null &&
                                      user.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(user.avatarUrl!)
                                      as ImageProvider
                                  : null,
                          child: _avatarBytes == null &&
                                  (user.avatarUrl == null ||
                                      user.avatarUrl!.isEmpty)
                              ? const Icon(
                                  Icons.storefront_rounded,
                                  color: DjassaTheme.accentOrange,
                                  size: 48,
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
                  const SizedBox(height: 20),
                  _Field(
                    controller: _nameController,
                    label: 'Nom',
                    icon: Icons.person_outline_rounded,
                  ),
                  _Field(
                    controller: _surnameController,
                    label: 'Prénom',
                    icon: Icons.badge_outlined,
                  ),
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
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: DjassaTheme.accentOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isSaving ? 'Enregistrement…' : 'Enregistrer',
                      ),
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
  const _Field({
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
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
