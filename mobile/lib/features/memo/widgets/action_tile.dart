import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo_result.dart';

/// What "undo" means for an action, where the API supports reversing it.
enum UndoKind {
  /// set_reminder → PATCH the reminder to dismissed.
  dismissReminder,

  /// draft_email → POST discard. The email was never sent, so this is safe.
  discardDraft,
}

/// Which undo applies to [action], or null when the backend has no endpoint
/// that can reverse it (deal updates, calendar events, company lookups) —
/// those get a link instead of a fake button.
UndoKind? undoFor(ExecutedAction action) {
  if (action.tool == 'set_reminder' && action.isApplied && action.reminderId != null) {
    return UndoKind.dismissReminder;
  }
  if (action.tool == 'draft_email' && action.awaitsApproval && action.draftId != null) {
    return UndoKind.discardDraft;
  }
  return null;
}

IconData iconForTool(String tool) => switch (tool) {
      'update_deal' => Icons.view_kanban_outlined,
      'set_reminder' => Icons.alarm_outlined,
      'schedule_event' => Icons.event_outlined,
      'draft_email' => Icons.mail_outline,
      'lookup_company' => Icons.travel_explore,
      _ => Icons.bolt_outlined,
    };

/// One line in the "what happened" list: the tool, what it did, and its
/// status — applied, waiting for approval, failed, or undone.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.action,
    this.undone = false,
    this.busy = false,
    this.onUndo,
  });

  final ExecutedAction action;
  final bool undone;
  final bool busy;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (statusLabel, statusColor) = undone
        ? ('Undone', AppColors.textSecondary)
        : action.failed
            ? ('Failed', Colors.red.shade400)
            : action.awaitsApproval
                ? ('Needs your OK', AppColors.accent)
                : ('Done', AppColors.accent);

    return ListTile(
      leading: Icon(
        action.failed ? Icons.error_outline : iconForTool(action.tool),
        color: action.failed ? Colors.red.shade400 : AppColors.textSecondary,
      ),
      title: Text(
        action.summary,
        style: textTheme.bodyMedium?.copyWith(
          decoration: undone ? TextDecoration.lineThrough : null,
          color: undone ? AppColors.textSecondary : null,
        ),
      ),
      subtitle: Text(
        action.failed && action.error != null ? action.error! : statusLabel,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(color: statusColor),
      ),
      trailing: onUndo == null || undone
          ? null
          : busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(onPressed: onUndo, child: const Text('Undo')),
    );
  }
}
