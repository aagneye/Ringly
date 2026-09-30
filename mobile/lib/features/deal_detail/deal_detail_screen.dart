import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../core/error_message.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/deal.dart';
import '../../data/models/deal_detail.dart';
import '../../providers/api_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/deal_providers.dart';
import 'widgets/precall_brief_sheet.dart';

/// Everything about one deal, on its own full-screen page: the record, the
/// pre-call brief button, a stage changer, company facts from the web, and a
/// single merged timeline of what Ringly and the user each did.
class DealDetailScreen extends ConsumerWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(dealDetailProvider(dealId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.maybeWhen(data: (d) => d.deal.title, orElse: () => 'Deal'),
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(dealDetailProvider(dealId)),
        ),
        data: (data) => _DetailBody(dealId: dealId, detail: data),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

/// A merged timeline entry, so notes, actions, reminders and events sort into
/// one honest newest-first list.
class _TimelineEntry {
  const _TimelineEntry({
    required this.when,
    required this.icon,
    required this.text,
    required this.source,
  });

  final DateTime when;
  final IconData icon;
  final String text;

  /// 'Ringly', 'You', or null (calendar/reminder rows).
  final String? source;
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.dealId, required this.detail});

  final String dealId;
  final DealDetail detail;

  Future<void> _changeStage(BuildContext context, WidgetRef ref, String stage) async {
    try {
      await ref.read(dealsRepositoryProvider).updateStage(dealId, stage);
      ref
        ..invalidate(dealDetailProvider(dealId))
        ..invalidate(boardProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final deal = detail.deal;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _HeaderCard(detail: detail),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => showPrecallBrief(context, dealId),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Brief me'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.accent,
          ),
        ),
        const SizedBox(height: 20),
        Text('Stage', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        _StageChips(
          current: deal.stage,
          onSelect: (stage) => _changeStage(context, ref, stage),
        ),
        const SizedBox(height: 20),
        _FactsRows(deal: deal),
        if (detail.facts.isNotEmpty) ...[
          const SizedBox(height: 20),
          _CompanyFactsCard(facts: detail.facts),
        ],
        if (detail.pendingDraftCount > 0) ...[
          const SizedBox(height: 16),
          _DraftsLink(count: detail.pendingDraftCount),
        ],
        const SizedBox(height: 24),
        Text('Timeline', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        _Timeline(detail: detail, now: now),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final DealDetail detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final deal = detail.deal;
    final who = [
      if (deal.role != null && deal.role!.isNotEmpty) deal.role!,
      if (deal.company != null && deal.company!.isNotEmpty) deal.company!,
    ].join(' · ');
    final signal = detail.topSignal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deal.contactName,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (who.isNotEmpty)
                        Text(who, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                _HealthDot(health: detail.health),
              ],
            ),
            if (deal.email != null && deal.email!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(deal.email!, style: textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(stageLabel(deal.stage)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.surfaceMuted,
                  side: BorderSide.none,
                ),
              ],
            ),
            if (signal != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.trending_down, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(signal.explanation, style: textTheme.bodyMedium),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A health dot coloured by score: green healthy, amber slipping, red at risk.
class _HealthDot extends StatelessWidget {
  const _HealthDot({required this.health});

  final int health;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: healthColor(health), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$health', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Green ≥ 70, amber 40–69, red below 40.
Color healthColor(int health) {
  if (health >= 70) return const Color(0xFF2E7D32);
  if (health >= 40) return const Color(0xFFF9A825);
  return const Color(0xFFC62828);
}

class _StageChips extends StatelessWidget {
  const _StageChips({required this.current, required this.onSelect});

  final String current;
  final void Function(String stage) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final stage in kDealStages)
          ChoiceChip(
            label: Text(stageLabel(stage)),
            selected: stage == current,
            onSelected: stage == current ? null : (_) => onSelect(stage),
            selectedColor: AppColors.accent,
            labelStyle: TextStyle(
              color: stage == current ? AppColors.onAccent : AppColors.textPrimary,
            ),
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
          ),
      ],
    );
  }
}

class _FactsRows extends StatelessWidget {
  const _FactsRows({required this.deal});

  final DealInfo deal;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (deal.nextAction != null && deal.nextAction!.isNotEmpty)
        ('Next action', deal.nextAction!),
      if (deal.deadline != null) ('Deadline', formatRelative(deal.deadline!, DateTime.now())),
      if (deal.budget != null && deal.budget!.isNotEmpty) ('Budget', deal.budget!),
      if (deal.concerns != null && deal.concerns!.isNotEmpty) ('Concerns', deal.concerns!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 96, child: Text(label, style: textTheme.bodySmall)),
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

class _CompanyFactsCard extends StatelessWidget {
  const _CompanyFactsCard({required this.facts});

  final List<CompanyFact> facts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('Company facts', style: textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text('From the web via Tavily', style: textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final fact in facts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fact.fact, style: textTheme.bodyMedium),
                    if (fact.sourceHost != null)
                      Text(
                        fact.sourceHost!,
                        style: textTheme.bodySmall?.copyWith(color: AppColors.accent),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DraftsLink extends StatelessWidget {
  const _DraftsLink({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.goNamed(AppRoutes.actions),
      icon: const Icon(Icons.drafts_outlined),
      label: Text(count == 1 ? '1 draft waiting for you' : '$count drafts waiting for you'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.detail, required this.now});

  final DealDetail detail;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final entries = <_TimelineEntry>[
      for (final note in detail.notes)
        if (note.createdAt != null)
          _TimelineEntry(
            when: note.createdAt!,
            icon: note.source == 'text' ? Icons.notes_outlined : Icons.mic_none,
            text: note.display,
            source: null,
          ),
      for (final action in detail.actions)
        if (action.createdAt != null)
          _TimelineEntry(
            when: action.createdAt!,
            icon: action.isManual ? Icons.touch_app_outlined : Icons.auto_awesome,
            text: action.summary,
            source: action.isManual ? 'You' : 'Ringly',
          ),
      for (final reminder in detail.reminders)
        if (reminder.dueAt != null)
          _TimelineEntry(
            when: reminder.dueAt!,
            icon: Icons.notifications_none,
            text: reminder.message,
            source: null,
          ),
      for (final event in detail.events)
        if (event.startsAt != null)
          _TimelineEntry(
            when: event.startsAt!,
            icon: Icons.event_outlined,
            text: event.title,
            source: null,
          ),
    ]..sort((a, b) => b.when.compareTo(a.when));

    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nothing on the timeline yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Column(
        children: [
          for (final entry in entries)
            ListTile(
              leading: Icon(entry.icon, color: AppColors.textSecondary),
              title: Text(entry.text, style: textTheme.bodyMedium),
              subtitle: Text(
                [
                  if (entry.source != null) entry.source!,
                  formatRelative(entry.when, now),
                ].join(' · '),
                style: textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
