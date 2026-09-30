import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import 'nav_destinations.dart';

/// The slide-in drawer opened by the circular menu button.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text('Ringly', style: textTheme.headlineMedium),
            ),
            const Divider(height: 1, color: AppColors.border),
            for (final d in kNavDestinations)
              ListTile(
                leading: Icon(d.icon, color: AppColors.textSecondary),
                title: Text(d.label, style: textTheme.bodyMedium),
                onTap: () {
                  Navigator.of(context).pop();
                  context.goNamed(d.routeName);
                },
              ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.textSecondary),
              title: Text('Sign out', style: textTheme.bodyMedium),
              onTap: () {
                Navigator.of(context).pop();
                context.goNamed(AppRoutes.login);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
