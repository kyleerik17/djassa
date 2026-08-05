import 'package:djassa/core/theme/djassa_theme.dart';
import 'package:djassa/presentation/screens/profile/widgets/profile_string.dart';
import 'package:flutter/material.dart';



Future<void> showLogoutSheet(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (ctx) => LogoutSheet(
      onConfirm: () {
        Navigator.of(ctx).pop();
        onConfirm();
      },
      onCancel: () => Navigator.of(ctx).pop(),
    ),
  );
}

class LogoutSheet extends StatefulWidget {
  const LogoutSheet({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<LogoutSheet> createState() => _LogoutSheetState();
}

class _LogoutSheetState extends State<LogoutSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: DjassaTheme.primaryWhite,
            borderRadius: BorderRadius.circular(28),
            boxShadow: DjassaTheme.shadowHeavy,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: DjassaTheme.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.red.withValues(alpha: .10),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ProfileStrings.logoutConfirmTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                ProfileStrings.logoutConfirmBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DjassaTheme.primaryBlack.withValues(alpha: .55),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: widget.onCancel,
                      child: const Text(ProfileStrings.logoutStay),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: widget.onConfirm,
                      child: const Text(ProfileStrings.logout),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}