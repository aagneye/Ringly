import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../core/error_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/deal.dart';
import '../../../providers/api_providers.dart';
import '../../../providers/data_providers.dart';
import '../../deal_detail/deal_detail_screen.dart' show healthColor;

/// One deal in the Pipeline list. Tap to open its detail; long-press to move it
/// to another stage without leaving the list.
class DealCard extends ConsumerWidget {
  const DealCard({super.key, required this.deal});

  final BoardDeal deal;

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final target = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Move to…'),
            ),
            for (final stage in kDealStages)
              if (stage != deal.stage)
                ListTile(
                  title: Text(stageLabel(stage)),
                  onTap: () => Navigator.of(sheetContext).pop(stage),
                ),
          ],
        ),
      ),
    );
    if (target == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Moved to ${stageLabel(target)}')));
    try {
      await ref.read(dealsRepositoryProvider).updateStage(deal.id, target);
      ref.invalidate(boardProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final who = [
      deal.contactName,
      if (deal.company != null && deal.company!.isNotEmpty) deal.company!,
    ].join(' · ');
    final signal = deal.topSignal;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.pushNamed(
          AppRoutes.dealDetail,
          pathParameters: {'id': deal.id},
        ),
        onLongPress: () => _move(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deal.title,
                      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: healthColor(deal.health),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(who, style: textTheme.bodySmall),
              if (deal.nextAction != null && deal.nextAction!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(deal.nextAction!, style: textTheme.bodyMedium),
              ],
              if (signal != null || deal.pendingDraftCount > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (signal != null)
                      _QuietBadge(daysSinceContact: signal.daysSinceContact),
                    if (deal.pendingDraftCount > 0) ...[
                      const Spacer(),
                      const Icon(Icons.drafts_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${deal.pendingDraftCount}', style: textTheme.bodySmall),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A "Quiet 12d" pill built from the top drift signal.
class _QuietBadge extends StatelessWidget {
  const _QuietBadge({required this.daysSinceContact});

  final int? daysSinceContact;

  @override
  Widget build(BuildContext context) {
    final label = daysSinceContact == null ? 'Quiet' : 'Quiet ${daysSinceContact}d';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_down, size: 14, color: Colors.red.shade400),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.red.shade400),
          ),
        ],
      ),
    );
  }
}
