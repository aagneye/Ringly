import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../providers/data_providers.dart';
import 'widgets/ai_activity_section.dart';
import 'widgets/briefing_card.dart';
import 'widgets/integrations_section.dart';
import 'widgets/needs_you_card.dart';
import 'widgets/pipeline_pulse_section.dart';
import 'widgets/quick_record_card.dart';
import 'widgets/todays_calls_section.dart';

/// The 9am "what needs me" screen.
///
/// Sections are in strict priority order — action before information,
/// information before vanity — so a salesperson with ninety seconds between
/// calls sees the thing that needs them first.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(briefingProvider)
      ..invalidate(todayProvider)
      ..invalidate(boardProvider)
      ..invalidate(healthProvider)
      ..invalidate(usageProvider);
    // Wait for the data, but let each section render its own error.
    await Future.wait<Object?>([
      ref.read(todayProvider.future),
      ref.read(boardProvider.future),
      ref.read(healthProvider.future),
    ].map((f) => f.then<Object?>((v) => v, onError: (_) => null)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        // Top padding clears the floating menu button.
        padding: const EdgeInsets.fromLTRB(20, 68, 20, 24),
        children: [
          Text(greetingFor(DateTime.now()), style: textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Here is what needs you today.', style: textTheme.bodySmall),
          const SizedBox(height: 20),
          const BriefingCard(),
          const NeedsYouCard(),
          const TodaysCallsSection(),
          const QuickRecordCard(),
          const PipelinePulseSection(),
          const IntegrationsSection(),
          const AiActivitySection(),
        ],
      ),
    );
  }
}
