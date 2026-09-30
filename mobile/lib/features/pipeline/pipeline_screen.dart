import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error_message.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/deal.dart';
import '../../providers/data_providers.dart';
import 'pipeline_grouping.dart';
import 'widgets/deal_card.dart';

/// The Pipeline tab: every deal, grouped by stage, quiet ones first.
///
/// A vertical grouped list rather than a horizontal kanban — on a phone,
/// scrolling down through "Proposal · 3" then its cards beats swiping between
/// columns you can only half-see.
class PipelineScreen extends ConsumerStatefulWidget {
  const PipelineScreen({super.key});

  @override
  ConsumerState<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends ConsumerState<PipelineScreen> {
  bool _quietOnly = false;
  bool _showClosed = false;

  Future<void> _refresh() async {
    ref.invalidate(boardProvider);
    await ref.read(boardProvider.future).then<void>((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(boardProvider);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: board.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Scrollable(
          child: _Notice(message: friendlyError(error)),
        ),
        data: (data) => _PipelineBody(
          board: data,
          quietOnly: _quietOnly,
          showClosed: _showClosed,
          onQuietChanged: (v) => setState(() => _quietOnly = v),
          onShowClosedChanged: (v) => setState(() => _showClosed = v),
        ),
      ),
    );
  }
}

class _PipelineBody extends StatelessWidget {
  const _PipelineBody({
    required this.board,
    required this.quietOnly,
    required this.showClosed,
    required this.onQuietChanged,
    required this.onShowClosedChanged,
  });

  final Board board;
  final bool quietOnly;
  final bool showClosed;
  final ValueChanged<bool> onQuietChanged;
  final ValueChanged<bool> onShowClosedChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (board.total == 0) {
      return _Scrollable(
        child: _Notice(
          message: 'No deals yet — record a memo after your next call.',
        ),
      );
    }

    var groups = groupForPipeline(board, showClosed: showClosed);
    if (quietOnly) {
      groups = [
        for (final group in groups)
          if (group.deals.any((d) => d.isQuiet))
            StageGroup(
              stage: group.stage,
              deals: group.deals.where((d) => d.isQuiet).toList(),
            ),
      ];
    }

    final openCount = totalOpen(board);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 68, 20, 24),
      children: [
        Text('Pipeline', style: textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          openCount == 1 ? '1 open deal' : '$openCount open deals',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: !quietOnly,
              onSelected: (_) => onQuietChanged(false),
            ),
            FilterChip(
              label: const Text('Going quiet'),
              selected: quietOnly,
              onSelected: (_) => onQuietChanged(true),
            ),
            FilterChip(
              label: const Text('Show closed'),
              selected: showClosed,
              onSelected: onShowClosedChanged,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (groups.isEmpty)
          _Notice(
            message: quietOnly
                ? 'Nothing going quiet — every deal has had recent contact.'
                : 'No deals in these stages.',
          )
        else
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${group.label} · ${group.count}',
                style: textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            for (final deal in group.deals) DealCard(deal: deal),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 68, 20, 24),
        children: [child],
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
}
