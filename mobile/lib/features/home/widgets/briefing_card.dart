import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/briefing.dart';
import '../../../providers/api_providers.dart';
import '../../../providers/data_providers.dart';
import 'home_section.dart';

/// The hero card: Nemotron Ultra's pick of the two or three things that matter
/// today. The refresh button forces a fresh Ultra generation (the server
/// otherwise caches one briefing per day).
class BriefingCard extends ConsumerStatefulWidget {
  const BriefingCard({super.key});

  @override
  ConsumerState<BriefingCard> createState() => _BriefingCardState();
}

class _BriefingCardState extends ConsumerState<BriefingCard> {
  bool _regenerating = false;

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    try {
      await ref.read(briefingRepositoryProvider).fetch(force: true);
      ref.invalidate(briefingProvider);
      await ref.read(briefingProvider.future);
    } catch (_) {
      // The provider re-fetch surfaces the error in the card itself.
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final briefing = ref.watch(briefingProvider);
    final textTheme = Theme.of(context).textTheme;

    return HomeSection(
      title: 'Morning briefing',
      actionLabel: _regenerating ? 'Thinking…' : 'Regenerate',
      onAction: _regenerating ? null : _regenerate,
      child: AsyncSectionBody<Briefing>(
        value: briefing,
        loadingHeight: 110,
        builder: (data) => SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    data.empty
                        ? 'Quiet day'
                        : data.cached
                            ? 'Nemotron Ultra · today'
                            : 'Nemotron Ultra · just now',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(data.headline, style: textTheme.titleMedium),
              if (data.spokenText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(data.spokenText, style: textTheme.bodyMedium),
              ],
              for (final item in data.items) ...[
                const SizedBox(height: 12),
                _BriefingItemRow(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BriefingItemRow extends StatelessWidget {
  const _BriefingItemRow({required this.item});

  final BriefingItem item;

  IconData get _icon => switch (item.kind) {
        'meeting' => Icons.event_outlined,
        'reminder' => Icons.alarm_outlined,
        'draft' => Icons.mail_outline,
        _ => Icons.trending_down,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(item.detail, style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
