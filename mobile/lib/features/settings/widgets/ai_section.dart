import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/error_message.dart';
import '../../../core/errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_providers.dart';
import '../settings_providers_local.dart';
import 'settings_section.dart';

/// "AI": jump to the models/usage page, toggle the nightly review, and trigger
/// it on demand.
///
/// The run-now button never carries a secret. A deployed server that requires
/// its CRON_SECRET answers 401; we turn that into a "run it from the scheduler"
/// message rather than trying (and failing) to authenticate from the phone.
class AiSection extends ConsumerStatefulWidget {
  const AiSection({super.key});

  @override
  ConsumerState<AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends ConsumerState<AiSection> {
  bool _running = false;

  Future<void> _runReview() async {
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(reviewRepositoryProvider).runNow();
      final summary = result['summary'];
      messenger.showSnackBar(SnackBar(
        content: Text(
          summary is String && summary.isNotEmpty
              ? summary
              : 'Nightly review finished.',
        ),
      ));
    } on RinglyApiException catch (e) {
      final message = e.statusCode == 401
          ? 'The server requires its cron secret for this — run it from the scheduler.'
          : friendlyError(e);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(currentSettingsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return SettingsSection(
      title: 'AI',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.insights_outlined),
          title: const Text('Models & usage'),
          subtitle: const Text('Live Nemotron tier counts, tokens and latency'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.goNamed(AppRoutes.models),
        ),
        const Divider(height: 1, color: AppColors.border),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Nightly review'),
          subtitle: const Text('Review the pipeline overnight and queue drafts'),
          value: settings.nightlyReviewEnabled,
          onChanged: (v) =>
              controller.apply((s) => s.copyWith(nightlyReviewEnabled: v)),
        ),
        const Divider(height: 1, color: AppColors.border),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Run nightly review now'),
          subtitle: const Text('Trigger the pipeline review immediately'),
          trailing: _running
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          onTap: _running ? null : _runReview,
        ),
      ],
    );
  }
}
