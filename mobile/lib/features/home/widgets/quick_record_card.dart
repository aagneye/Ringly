import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../core/theme/app_colors.dart';

/// A large, obvious record entry point. Redundant with the nav button on
/// purpose: capture is the primary action and should never need hunting for.
class QuickRecordCard extends StatelessWidget {
  const QuickRecordCard({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.goNamed(AppRoutes.recorder),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.onAccent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: AppColors.onAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Just finished a call?',
                        style: textTheme.titleMedium?.copyWith(color: AppColors.onAccent),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Talk for a minute. Ringly handles the rest.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.onAccent.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.onAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
