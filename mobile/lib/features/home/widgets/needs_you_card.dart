import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/today.dart';
import '../../../providers/data_providers.dart';
import 'home_section.dart';

/// "What needs me right now" — a count-led card that opens the Actions queue.
/// Collapses to one calm line when nothing is waiting.
class NeedsYouCard extends ConsumerWidget {
  const NeedsYouCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeSection(
      title: 'Needs you now',
      child: AsyncSectionBody<TodaySnapshot>(
        value: ref.watch(todayProvider),
        builder: (today) {
          if (today.pendingActionCount == 0) {
            return const SectionNotice(
              icon: Icons.check_circle_outline,
              message: 'You\'re all caught up. Nothing is waiting on you.',
            );
          }
          return SectionCard(
            onTap: () => context.goNamed(AppRoutes.actions),
            child: Row(
              children: [
                _Count(value: today.drafts.length, label: 'drafts to approve'),
                const SizedBox(width: 16),
                _Count(value: today.reminders.length, label: 'reminders due'),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: textTheme.headlineMedium?.copyWith(
            color: value > 0 ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}
