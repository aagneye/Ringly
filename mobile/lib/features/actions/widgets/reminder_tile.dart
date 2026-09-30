import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/today.dart';
import '../../home/widgets/home_section.dart';

/// One reminder in the "Reminders due" section: what it's about, which deal
/// and contact it belongs to, when it's due, and Done / Dismiss buttons.
///
/// There is no snooze endpoint on the server, so this offers only the two
/// honest choices the API supports: mark it Done or Dismiss it.
class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.reminder,
    required this.now,
    required this.busy,
    required this.onDone,
    required this.onDismiss,
  });

  final TodayReminder reminder;
  final DateTime now;
  final bool busy;
  final VoidCallback onDone;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final overdue = reminder.isOverdue(now);
    final dueLabel = overdue
        ? 'Overdue'
        : reminder.dueAt == null
            ? 'No due date'
            : formatRelative(reminder.dueAt!, now);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(reminder.message, style: textTheme.bodyMedium),
              ),
              const SizedBox(width: 12),
              Text(
                dueLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: overdue ? Colors.red.shade400 : AppColors.textSecondary,
                  fontWeight: overdue ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${reminder.contactName} · ${reminder.dealTitle}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onDone, child: const Text('Done')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
