import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../core/error_message.dart';
import '../../core/theme/app_colors.dart';
import '../../data/memo/local_memo.dart';
import '../../data/models/deal.dart';
import '../../data/models/memo_result.dart';
import '../../data/models/usage.dart';
import '../../providers/api_providers.dart';
import '../../providers/data_providers.dart';
import '../contacts/contact_suggestion.dart';
import 'submission_controller.dart';
import 'widgets/action_tile.dart';

/// "What happened" — the screen after a memo is sent.
///
/// Shows what was heard, what was understood, who it was filed against, and
/// every action the agent took, with undo where the API can reverse it. When
/// the agent chose to do nothing, that is shown as a result, not a failure.
class MemoResultScreen extends ConsumerWidget {
  const MemoResultScreen({super.key, required this.memoId});

  final String memoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memo = ref.watch(memoByIdProvider(memoId));
    final submission = ref.watch(submissionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('What happened'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: memo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Centered(message: friendlyError(error)),
        data: (memo) {
          if (memo == null) return const _Centered(message: 'This memo is no longer on your phone.');
          if (submission.isSending(memo.id) || memo.status == MemoStatus.syncing) {
            return _SendingView(progress: submission.isSending(memo.id) ? submission.progress : 1);
          }
          if (memo.status == MemoStatus.synced && memo.resultJson != null) {
            return _ResultView(result: MemoResult.fromJson(memo.resultJson!));
          }
          return _NotSentView(
            memo: memo,
            onRetry: () => ref.read(submissionControllerProvider.notifier).submit(memo),
          );
        },
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}

class _SendingView extends StatelessWidget {
  const _SendingView({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final uploading = progress < 1;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                value: uploading ? progress : null,
                backgroundColor: AppColors.border,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              uploading ? 'Sending your memo…' : 'Nemotron is working out what to do…',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'It\'s already saved on your phone, so you can leave this screen.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotSentView extends StatelessWidget {
  const _NotSentView({required this.memo, required this.onRetry});

  final LocalMemo memo;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final failed = memo.status == MemoStatus.failed;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  failed ? Icons.error_outline : Icons.cloud_upload_outlined,
                  color: failed ? Colors.red.shade400 : AppColors.accent,
                ),
                const SizedBox(height: 12),
                Text(
                  failed ? 'Ringly couldn\'t process this memo' : 'Saved on your phone',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  memo.lastError ??
                      'It will be sent automatically as soon as you\'re back online.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Try again now')),
              ],
            ),
          ),
        ),
        if (memo.transcript != null) ...[
          const SizedBox(height: 16),
          _TranscriptCard(text: memo.transcript!, source: 'Your note'),
        ],
      ],
    );
  }
}

class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({required this.result});

  final MemoResult result;

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  final Set<int> _undone = {};
  int? _busy;

  Future<void> _undo(int index, UndoKind kind, ExecutedAction action) async {
    setState(() => _busy = index);
    try {
      switch (kind) {
        case UndoKind.dismissReminder:
          await ref.read(remindersRepositoryProvider).dismiss(action.reminderId!);
        case UndoKind.discardDraft:
          await ref.read(draftsRepositoryProvider).discard(action.draftId!);
      }
      ref.invalidate(todayProvider);
      setState(() => _undone.add(index));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final textTheme = Theme.of(context).textTheme;
    final applied = result.actions.where((a) => a.isApplied).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (result.tookNoAction)
          _Banner(
            icon: Icons.check_circle_outline,
            title: 'Nothing needed doing',
            body: result.noActionReason ?? 'Ringly filed the note and left everything else as it was.',
          )
        else
          _Banner(
            icon: Icons.auto_awesome,
            title: applied == 1 ? 'Ringly did 1 thing' : 'Ringly did $applied things',
            body: result.awaitingApprovalCount > 0
                ? '${result.awaitingApprovalCount} waiting for your approval — nothing was sent.'
                : 'Everything below is already done. Undo anything that\'s wrong.',
          ),
        const SizedBox(height: 16),
        _TargetCard(target: result.target),
        ContactSuggestion(target: result.target, extraction: result.extraction),
        if (result.actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Actions', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < result.actions.length; i++)
                  Builder(builder: (context) {
                    final action = result.actions[i];
                    final undo = undoFor(action);
                    return ActionTile(
                      action: action,
                      undone: _undone.contains(i),
                      busy: _busy == i,
                      onUndo: undo == null || _busy != null ? null : () => _undo(i, undo, action),
                    );
                  }),
              ],
            ),
          ),
          if (result.awaitingApprovalCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                onPressed: () => context.goNamed(AppRoutes.actions),
                icon: const Icon(Icons.task_alt),
                label: const Text('Review in Actions'),
              ),
            ),
        ],
        if (result.extraction.fields.isNotEmpty || result.extraction.gist.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('What Ringly understood', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          _ExtractionCard(extraction: result.extraction),
        ],
        const SizedBox(height: 20),
        _TranscriptCard(text: result.transcript, source: _providerLabel(result.transcriptionProvider)),
        if (result.traces.isNotEmpty) ...[
          const SizedBox(height: 20),
          _TraceStrip(traces: result.traces),
        ],
      ],
    );
  }

  static String _providerLabel(String provider) => switch (provider) {
        'nemotron-omni' => 'Heard by Nemotron Omni',
        'audio-endpoint' => 'Transcribed on Nebius',
        'client-text' => 'Sent as text',
        _ => 'Transcript',
      };
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(body, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.target});

  final MemoTarget target;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final who = [target.contactName, if (target.company != null) target.company!].join(' · ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline, color: AppColors.textSecondary),
        title: Text(who, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            target.dealTitle,
            stageLabel(target.stage),
            if (target.createdContact) 'new contact',
            if (!target.createdContact && target.isUncertain) 'check this is the right person',
          ].join(' · '),
          style: textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () => context.goNamed(AppRoutes.pipeline),
      ),
    );
  }
}

class _ExtractionCard extends StatelessWidget {
  const _ExtractionCard({required this.extraction});

  final MemoExtraction extraction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (extraction.gist.isNotEmpty) Text(extraction.gist, style: textTheme.bodyMedium),
            for (final (label, value) in extraction.fields)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 88, child: Text(label, style: textTheme.bodySmall)),
                    Expanded(child: Text(value, style: textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.text, required this.source});

  final String text;
  final String source;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source, style: textTheme.bodySmall),
            const SizedBox(height: 8),
            SelectableText(text.isEmpty ? '—' : text, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Which Nemotron tier handled each step — visible proof of the tiering.
class _TraceStrip extends StatelessWidget {
  const _TraceStrip({required this.traces});

  final List<TraceLine> traces;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nemotron on Nebius Token Factory', style: textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final trace in traces)
              Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                label: Text(
                  '${tierShortName(trace.tier)} · ${trace.task.replaceAll('_', ' ')} · '
                  '${trace.latencyMs < 1000 ? '${trace.latencyMs} ms' : '${(trace.latencyMs / 1000).toStringAsFixed(1)} s'}',
                  style: textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Opens the result screen for [memo] (used by the recorder and memo lists).
void openMemoResult(BuildContext context, LocalMemo memo) =>
    context.pushNamed(AppRoutes.memoResult, pathParameters: {'id': memo.id});
