import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/memo/local_memo.dart';
import '../../../providers/memo_providers.dart';

/// Memos stored on the device with their sync status — the proof that a
/// recording survived an app kill or a dead zone.
class RecentMemosList extends ConsumerWidget {
  const RecentMemosList({super.key, this.limit = 5, this.onOpen});

  final int limit;
  final void Function(LocalMemo memo)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memos = ref.watch(memosProvider);
    final textTheme = Theme.of(context).textTheme;

    return memos.when(
      loading: () => const SizedBox(height: 48),
      error: (error, _) => Text('Couldn\'t read saved memos.', style: textTheme.bodySmall),
      data: (list) {
        if (list.isEmpty) {
          return Text('No memos yet. Your first one will appear here.', style: textTheme.bodySmall);
        }
        final now = ref.read(clockProvider)();
        return Card(
          child: Column(
            children: [
              for (final memo in list.take(limit))
                ListTile(
                  onTap: onOpen == null ? null : () => onOpen!(memo),
                  leading: Icon(
                    memo.isTextOnly ? Icons.notes : Icons.graphic_eq,
                    color: AppColors.textSecondary,
                  ),
                  title: Text(
                    memoTitle(memo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    [
                      formatRelative(memo.createdAt, now),
                      if (!memo.isTextOnly) formatDuration(memo.duration),
                    ].join(' · '),
                    style: textTheme.bodySmall,
                  ),
                  trailing: MemoStatusChip(status: memo.status),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The best one-line label for a memo: what the agent understood, else the
/// transcript, else a neutral placeholder.
String memoTitle(LocalMemo memo) {
  final gist = memo.resultJson?['extraction'] is Map
      ? (memo.resultJson!['extraction'] as Map)['gist']
      : null;
  if (gist is String && gist.isNotEmpty) return gist;
  if (memo.transcript != null && memo.transcript!.isNotEmpty) return memo.transcript!;
  return memo.isTextOnly ? 'Typed note' : 'Voice memo';
}

class MemoStatusChip extends StatelessWidget {
  const MemoStatusChip({super.key, required this.status});

  final MemoStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MemoStatus.pending => ('Waiting', AppColors.textSecondary),
      MemoStatus.syncing => ('Sending', AppColors.accent),
      MemoStatus.synced => ('Done', AppColors.accent),
      MemoStatus.failed => ('Failed', Colors.red.shade400),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
