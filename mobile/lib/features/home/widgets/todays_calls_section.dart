import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/today.dart';
import '../../../providers/data_providers.dart';
import 'home_section.dart';

/// Today's meetings, each with a "Brief me" button for the pre-call brief.
class TodaysCallsSection extends ConsumerWidget {
  const TodaysCallsSection({super.key, this.onBriefMe});

  /// Opens the pre-call brief for a deal. Null disables the button.
  final void Function(TodayEvent event)? onBriefMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeSection(
      title: 'Today\'s calls',
      child: AsyncSectionBody<TodaySnapshot>(
        value: ref.watch(todayProvider),
        builder: (today) {
          if (today.events.isEmpty) {
            return const SectionNotice(
              icon: Icons.event_available_outlined,
              message: 'No calls on the calendar today.',
            );
          }
          return SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final event in today.events)
                  _CallRow(event: event, onBriefMe: onBriefMe),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({required this.event, required this.onBriefMe});

  final TodayEvent event;
  final void Function(TodayEvent event)? onBriefMe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final who = [event.contactName, if (event.company != null) event.company!].join(' · ');
    return ListTile(
      leading: SizedBox(
        width: 44,
        child: Text(
          event.startsAt == null ? '—' : formatClock(event.startsAt!),
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(event.title, style: textTheme.bodyMedium),
      subtitle: Text(who, style: textTheme.bodySmall),
      trailing: OutlinedButton(
        onPressed: onBriefMe == null ? null : () => onBriefMe!(event),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.border),
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('Brief me'),
      ),
    );
  }
}
