import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_message.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/today.dart';
import '../../providers/data_providers.dart';
import '../home/widgets/home_section.dart';
import 'actions_controller.dart';
import 'widgets/draft_card.dart';
import 'widgets/edit_draft_sheet.dart';
import 'widgets/reminder_tile.dart';

/// The approval queue: the only screen where an irreversible action (sending
/// an email) can begin, and even then only after the user taps Send in their
/// own mail client. Reminders can be marked Done or Dismissed here too.
class ActionsScreen extends ConsumerWidget {
  const ActionsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(todayProvider);
    await ref.read(todayProvider.future).then<void>((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(todayProvider);

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 68, 20, 24),
        children: [
          Text('Actions', style: textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Nothing here is sent until you tap.', style: textTheme.bodySmall),
          const SizedBox(height: 20),
          AsyncSectionBody<TodaySnapshot>(
            value: async,
            builder: (today) => _Queue(today: today),
          ),
        ],
      ),
    );
  }
}

class _Queue extends ConsumerWidget {
  const _Queue({required this.today});

  final TodaySnapshot today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(resolvedIdsProvider);
    final drafts = today.drafts.where((d) => !resolved.contains(d.id)).toList();
    final reminders =
        today.reminders.where((r) => !resolved.contains(r.id)).toList();

    if (drafts.isEmpty && reminders.isEmpty) {
      return const SectionCard(
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.accent),
            SizedBox(width: 12),
            Expanded(child: Text('You\'re all caught up')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (drafts.isNotEmpty) ...[
          _SectionHeader(title: 'Emails to approve', count: drafts.length),
          for (final draft in drafts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DraftCardHost(draft: draft),
            ),
        ],
        if (reminders.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionHeader(title: 'Reminders due', count: reminders.length),
          for (final reminder in reminders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReminderHost(reminder: reminder, now: today.now),
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$title ($count)', style: textTheme.titleMedium),
    );
  }
}

/// Hosts one [DraftCard], keeping the (possibly edited) local copy of the draft
/// and the busy/error state for this row only.
class _DraftCardHost extends ConsumerStatefulWidget {
  const _DraftCardHost({required this.draft});

  final PendingDraft draft;

  @override
  ConsumerState<_DraftCardHost> createState() => _DraftCardHostState();
}

class _DraftCardHostState extends ConsumerState<_DraftCardHost> {
  late PendingDraft _draft = widget.draft;
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    final controller = ref.read(actionsControllerProvider);
    final edited = _draft.subject != widget.draft.subject ||
        _draft.body != widget.draft.body;
    try {
      await controller.approve(
        _draft,
        editedSubject: edited ? _draft.subject : null,
        editedBody: edited ? _draft.body : null,
      );
    } catch (error) {
      if (mounted) setState(() => _busy = false);
      _snack(error is MailLaunchException ? error.toString() : friendlyError(error));
    }
  }

  Future<void> _edit() async {
    final updated = await showEditDraftSheet(context, _draft);
    if (updated != null) setState(() => _draft = updated);
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this draft?'),
        content: const Text('The email will be thrown away. It was never sent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(actionsControllerProvider).discard(_draft);
    } catch (error) {
      if (mounted) setState(() => _busy = false);
      _snack(friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraftCard(
      draft: _draft,
      busy: _busy,
      onApprove: _approve,
      onEdit: _edit,
      onDiscard: _discard,
    );
  }
}

/// Hosts one [ReminderTile] with its own busy/error state.
class _ReminderHost extends ConsumerStatefulWidget {
  const _ReminderHost({required this.reminder, required this.now});

  final TodayReminder reminder;
  final DateTime now;

  @override
  ConsumerState<_ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends ConsumerState<_ReminderHost> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(actionsControllerProvider);
    return ReminderTile(
      reminder: widget.reminder,
      now: widget.now,
      busy: _busy,
      onDone: () => _run(() => controller.completeReminder(widget.reminder)),
      onDismiss: () => _run(() => controller.dismissReminder(widget.reminder)),
    );
  }
}
