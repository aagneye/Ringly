/// The four Nemotron tiers, described for the Models page.
///
/// This is deliberately static, hardcoded metadata: it renders even when the
/// live `/api/usage` call fails, so a judge always sees the model story. Live
/// call counts and token totals are merged in from usageProvider at render
/// time by tier id — this file only holds the fixed "what and why".
///
/// The tier ids (FAST/BALANCED/REASONING/OMNI), model strings and rationale
/// mirror src/lib/nebius/models.ts on the server and the README table.
library;

class TierInfo {
  const TierInfo({
    required this.tier,
    required this.label,
    required this.model,
    required this.role,
    required this.why,
  });

  /// FAST, BALANCED, REASONING or OMNI — the key used to merge live usage.
  final String tier;

  /// Product name shown as the card title, e.g. "Lightning".
  final String label;

  /// The model id, shown in monospace.
  final String model;

  /// What this tier is used for.
  final String role;

  /// Why this tier, not a bigger or smaller one.
  final String why;
}

/// In display order: fastest first, omni (audio) last.
const List<TierInfo> kTierCatalog = [
  TierInfo(
    tier: 'FAST',
    label: 'Lightning',
    model: 'nvidia/Nemotron-3_5-Lightning',
    role: 'Extracts fields from every memo',
    why: 'Latency matters more than depth — runs on every memo',
  ),
  TierInfo(
    tier: 'BALANCED',
    label: 'Super',
    model: 'nvidia/nemotron-3-super-120b-a12b',
    role: 'Decides which tools to call, drafts emails, pre-call briefs',
    why: 'Tone and judgement matter; single-turn',
  ),
  TierInfo(
    tier: 'REASONING',
    label: 'Ultra',
    model: 'nvidia/Nemotron-3-Ultra-550b-a55b',
    role: 'Morning briefing and nightly pipeline review',
    why: 'The only genuinely hard multi-step judgement',
  ),
  TierInfo(
    tier: 'OMNI',
    label: 'Omni',
    model: 'nvidia/nemotron-3-nano-omni',
    role: 'Transcribes voice memos',
    why: 'Native audio understanding (Parakeet encoder)',
  ),
];
