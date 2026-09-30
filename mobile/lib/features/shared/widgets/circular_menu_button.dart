import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// A circular white button that floats in the top-left of a page.
///
/// Pure white with a soft border and a gentle shadow so it reads as a raised
/// control on the off-white background. Tapping it opens the app drawer via
/// [onTap] (wired by [AppShell] to `Scaffold.openDrawer`).
class CircularMenuButton extends StatelessWidget {
  const CircularMenuButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.menu, size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
