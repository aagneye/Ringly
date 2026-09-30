import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_message.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/usage.dart';
import '../../providers/data_providers.dart';
import '../home/widgets/home_section.dart';
import 'tier_catalog.dart';

/// The Models page: the evidence panel for judges.
///
/// The static tier catalogue always renders — even when `/api/usage` is
/// unreachable — so the "which model, and why" story is never blank. Live
/// counts, tokens and latency are merged in per tier from usageProvider when
/// available; when it fails, stats show "—" and a calm notice explains why.
class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(usageProvider);
    await ref.read(usageProvider.future).then<void>((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(usageProvider);
    final usage = async.value;
    final hasError = async.hasError && usage == null;

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 68, 20, 24),
        children: [
          Text('Models', style: textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Every decision runs on NVIDIA Nemotron, served by Nebius Token Factory.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          // Totals — dashes until the live numbers arrive.
          _TotalsCard(usage: usage),
          const SizedBox(height: 16),

          if (hasError) ...[
            SectionNotice(
              icon: Icons.cloud_off_outlined,
              message: friendlyError(async.error!),
            ),
            const SizedBox(height: 16),
          ],

          // The always-present tier catalogue.
          for (final info in kTierCatalog)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TierCard(info: info, usage: usage),
            ),

          const SizedBox(height: 8),
          const _OnDeviceRow(),

          if (usage != null && usage.recent.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Recent calls', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _RecentList(recent: usage.recent),
          ],
        ],
      ),
    );
  }
}

/// Total calls and tokens across every tier.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.usage});

  final UsageSummary? usage;

  @override
  Widget build(BuildContext context) {
    final calls = usage == null ? '—' : '${usage!.totalCalls}';
    final tokens = usage == null ? '—' : compactNumber(usage!.totalTokens);
    return SectionCard(
      child: Row(
        children: [
          Expanded(child: _Stat(value: calls, label: 'total calls')),
          Expanded(child: _Stat(value: tokens, label: 'total tokens')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: textTheme.headlineMedium?.copyWith(color: AppColors.accent)),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

/// One tier: its label, model id, role, why, and live stats when present.
class _TierCard extends StatelessWidget {
  const _TierCard({required this.info, required this.usage});

  final TierInfo info;
  final UsageSummary? usage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final merged = usage == null ? null : _MergedTier.from(usage!, info.tier);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  info.label,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _CallsPill(calls: merged?.calls),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            info.model,
            style: textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(info.role, style: textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            info.why,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(label: 'tokens', value: merged == null ? '—' : compactNumber(merged.tokens)),
              const SizedBox(width: 20),
              _MiniStat(label: 'avg latency', value: merged == null ? '—' : _latency(merged.avgLatencyMs)),
              if (merged != null && merged.failures > 0) ...[
                const SizedBox(width: 20),
                _MiniStat(
                  label: 'failures',
                  value: '${merged.failures}',
                  color: Colors.red.shade400,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Small "N calls" pill; shows "—" until live data arrives.
class _CallsPill extends StatelessWidget {
  const _CallsPill({required this.calls});

  final int? calls;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        calls == null ? '— calls' : '$calls calls',
        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        )),
        Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _OnDeviceRow extends StatelessWidget {
  const _OnDeviceRow();

  @override
  Widget build(BuildContext context) {
    return const SectionNotice(
      icon: Icons.phonelink_lock_outlined,
      message:
          'Speech-to-text on your phone: optional, off by default — reasoning never leaves Nebius.',
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.recent});

  final List<RecentTrace> recent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final rows = recent.take(10).toList();
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        children: [
          for (final trace in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tierShortName(trace.tier)} · ${trace.task}',
                      style: textTheme.bodySmall?.copyWith(
                        color: trace.failed ? Colors.red.shade400 : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _latency(trace.latencyMs),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    trace.createdAt == null ? '' : formatRelative(trace.createdAt!, now),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Live usage for one tier, summing the rows the server may split by model id.
class _MergedTier {
  const _MergedTier({
    required this.calls,
    required this.tokens,
    required this.avgLatencyMs,
    required this.failures,
  });

  final int calls;
  final int tokens;
  final int avgLatencyMs;
  final int failures;

  factory _MergedTier.from(UsageSummary usage, String tier) {
    final rows = usage.tiers.where((t) => t.tier == tier).toList();
    var calls = 0;
    var tokens = 0;
    var failures = 0;
    var latencyWeighted = 0;
    for (final row in rows) {
      calls += row.calls;
      tokens += row.totalTokens;
      failures += row.failures;
      latencyWeighted += row.avgLatencyMs * row.calls;
    }
    final avg = calls > 0 ? (latencyWeighted / calls).round() : 0;
    return _MergedTier(calls: calls, tokens: tokens, avgLatencyMs: avg, failures: failures);
  }
}

/// Milliseconds as "820ms" or "1.4s".
String _latency(int ms) {
  if (ms < 1000) return '${ms}ms';
  final seconds = ms / 1000;
  final fixed = seconds.toStringAsFixed(1);
  final trimmed = fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  return '${trimmed}s';
}
