import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/usage.dart';
import '../../../providers/data_providers.dart';
import 'home_section.dart';

/// A glance at which Nemotron tiers did the work — evidence, on the home
/// screen, that every decision runs on Nebius Token Factory.
class AiActivitySection extends ConsumerWidget {
  const AiActivitySection({super.key});

  static const _tiers = [
    ('FAST', 'Lightning'),
    ('BALANCED', 'Super'),
    ('REASONING', 'Ultra'),
    ('OMNI', 'Omni'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeSection(
      title: 'AI activity',
      actionLabel: 'Details',
      onAction: () => context.goNamed(AppRoutes.models),
      child: AsyncSectionBody<UsageSummary>(
        value: ref.watch(usageProvider),
        builder: (usage) {
          final textTheme = Theme.of(context).textTheme;
          return SectionCard(
            onTap: () => context.goNamed(AppRoutes.models),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${compactNumber(usage.totalCalls)} Nemotron calls · '
                  '${compactNumber(usage.totalTokens)} tokens',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final (tier, label) in _tiers)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              compactNumber(usage.callsFor(tier)),
                              style: textTheme.titleMedium?.copyWith(color: AppColors.accent),
                            ),
                            Text(label, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
