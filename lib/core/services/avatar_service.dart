import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de gestion de la photo de profil (avatar).
///
/// - Sélectionne une image depuis la galerie ou l'appareil photo.
/// - Upload dans le bucket `avatars` (chemin : `<uid>/avatar.<ext>`).
/// - Met à jour `profiles.avatar_url` avec l'URL publique.
class AvatarService {
  AvatarService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final ImagePicker _picker = ImagePicker();

  static const String _bucket = 'avatars';

  /// Ouvre la galerie ou la caméra et renvoie le fichier sélectionné.
  Future<File?> pickImage({required ImageSource source}) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Upload l'image dans Storage et met à jour la table `profiles`.
  /// Renvoie l'URL publique de l'avatar.
  Future<String> uploadAvatar(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non connecté.');
    }

    // Chemin : <uid>/avatar.<ext>  → on écrase l'ancienne photo
    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    final safeExt = (ext.isEmpty ? 'jpg' : ext);
    final objectPath = '${user.id}/avatar.$safeExt';

    final storage = _client.storage.from(_bucket);

    await storage.upload(
      objectPath,
      file,
      fileOptions: const FileOptions(
        upsert: true,
        cacheControl: '3600',
      ),
    );

    // URL publique + cache-buster pour forcer le rafraîchissement UI
    final publicUrl = storage.getPublicUrl(objectPath);
    final urlWithBuster =
        '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    await _client
        .from('profiles')
        .update({'avatar_url': urlWithBuster}).eq('id', user.id);

    return urlWithBuster;
  }

  /// Helper : sélection + upload en une seule étape.
  Future<String?> pickAndUpload({required ImageSource source}) async {
    final file = await pickImage(source: source);
    if (file == null) return null;
    return uploadAvatar(file);
  }

  /// Supprime l'avatar courant (Storage + colonne profile).
  Future<void> removeAvatar() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final storage = _client.storage.from(_bucket);
    // On tente les extensions courantes (on ne connaît pas celle uploadée)
    for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
      try {
        await storage.remove(['${user.id}/avatar.$ext']);
      } catch (_) {}
    }
    await _client
        .from('profiles')
        .update({'avatar_url': null}).eq('id', user.id);
  }
}
