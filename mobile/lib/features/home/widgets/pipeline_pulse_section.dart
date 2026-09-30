import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/deal.dart';
import '../../../providers/data_providers.dart';
import 'home_section.dart';

/// Deals going quiet, from the server's deterministic drift detection, plus
/// a count of open deals per stage.
class PipelinePulseSection extends ConsumerWidget {
  const PipelinePulseSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeSection(
      title: 'Pipeline pulse',
      actionLabel: 'Open',
      onAction: () => context.goNamed(AppRoutes.pipeline),
      child: AsyncSectionBody<Board>(
        value: ref.watch(boardProvider),
        builder: (board) {
          if (board.total == 0) {
            return const SectionNotice(
              icon: Icons.view_kanban_outlined,
              message: 'No deals yet. Record a memo after your next call and one appears here.',
            );
          }
          final quiet = board.quietDeals.take(3).toList();
          final textTheme = Theme.of(context).textTheme;
          return SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${board.openCount} open deals', style: textTheme.bodyMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final stage in kDealStages)
                      if (!kClosedStages.contains(stage))
                        _StageChip(label: stageLabel(stage), count: board.countFor(stage)),
                  ],
                ),
                if (quiet.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Going quiet', style: textTheme.bodySmall),
                  for (final deal in quiet)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.trending_down, size: 18, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${deal.contactName} — ${deal.topSignal?.explanation ?? deal.title}',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label $count', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
