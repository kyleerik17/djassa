import 'package:djassa/core/services/avatar_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';



/// Avatar circulaire cliquable :
/// - Tap → bottom sheet "Galerie / Caméra / Supprimer"
/// - Upload via [AvatarService]
/// - Callback [onUpdated] avec la nouvelle URL (ou null si suppression)
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    required this.currentUrl,
    required this.onUpdated,
    this.radius = 48,
    this.fallbackInitials, required Color fallbackColor, required IconData fallbackIcon, required Color backgroundColor,
  });

  final String? currentUrl;
  final ValueChanged<String?> onUpdated;
  final double radius;
  final String? fallbackInitials;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  final _service = AvatarService();
  bool _busy = false;

  Future<void> _handle(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    await _handle(() async {
      final url = await _service.pickAndUpload(source: source);
      if (url != null) widget.onUpdated(url);
    });
  }

  Future<void> _remove() async {
    await _handle(() async {
      await _service.removeAvatar();
      widget.onUpdated(null);
    });
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            if (widget.currentUrl != null && widget.currentUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer la photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _remove();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.currentUrl;
    final hasImage = url != null && url.isNotEmpty;

    return GestureDetector(
      onTap: _busy ? null : _openMenu,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: hasImage ? NetworkImage(url) : null,
            child: hasImage
                ? null
                : Text(
                    widget.fallbackInitials ?? '?',
                    style: TextStyle(
                      fontSize: widget.radius * 0.6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
            ),
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.camera_alt,
                    size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
