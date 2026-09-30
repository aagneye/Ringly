import '../json.dart';

/// Aggregate usage for one Nemotron tier, from GET /api/usage.
class TierUsage {
  const TierUsage({
    required this.tier,
    required this.model,
    required this.label,
    required this.rationale,
    required this.calls,
    required this.promptTokens,
    required this.completionTokens,
    required this.avgLatencyMs,
    required this.failures,
  });

  /// FAST, BALANCED, REASONING or OMNI.
  final String tier;
  final String model;
  final String label;
  final String rationale;
  final int calls;
  final int promptTokens;
  final int completionTokens;
  final int avgLatencyMs;
  final int failures;

  factory TierUsage.fromJson(Json json) => TierUsage(
        tier: readString(json, 'tier'),
        model: readString(json, 'model'),
        label: readString(json, 'label'),
        rationale: readString(json, 'rationale'),
        calls: readInt(json, 'calls'),
        promptTokens: readInt(json, 'promptTokens'),
        completionTokens: readInt(json, 'completionTokens'),
        avgLatencyMs: readInt(json, 'avgLatencyMs'),
        failures: readInt(json, 'failures'),
      );

  int get totalTokens => promptTokens + completionTokens;
}

/// One recent model call, newest first.
class RecentTrace {
  const RecentTrace({
    required this.task,
    required this.tier,
    required this.latencyMs,
    required this.failed,
    required this.createdAt,
  });

  final String task;
  final String tier;
  final int latencyMs;
  final bool failed;
  final DateTime? createdAt;

  factory RecentTrace.fromJson(Json json) => RecentTrace(
        task: readString(json, 'task'),
        tier: readString(json, 'tier'),
        latencyMs: readInt(json, 'latencyMs'),
        failed: readBool(json, 'failed'),
        createdAt: readDate(json, 'createdAt'),
      );
}

class UsageSummary {
  const UsageSummary({
    required this.tiers,
    required this.recent,
    required this.totalCalls,
    required this.totalPromptTokens,
    required this.totalCompletionTokens,
  });

  final List<TierUsage> tiers;
  final List<RecentTrace> recent;
  final int totalCalls;
  final int totalPromptTokens;
  final int totalCompletionTokens;

  factory UsageSummary.fromJson(Json json) {
    final totals = readObject(json, 'totals');
    return UsageSummary(
      tiers: readList(json, 'tiers', TierUsage.fromJson),
      recent: readList(json, 'recent', RecentTrace.fromJson),
      totalCalls: readInt(totals, 'calls'),
      totalPromptTokens: readInt(totals, 'promptTokens'),
      totalCompletionTokens: readInt(totals, 'completionTokens'),
    );
  }

  int get totalTokens => totalPromptTokens + totalCompletionTokens;

  /// Calls per tier, merging rows the server split by model id.
  int callsFor(String tier) =>
      tiers.where((t) => t.tier == tier).fold(0, (n, t) => n + t.calls);
}
