import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import 'recorder_controller.dart';
import 'widgets/recent_memos_list.dart';
import 'widgets/waveform.dart';

/// The core loop: tap, talk for a minute, tap again.
class RecorderScreen extends ConsumerWidget {
  const RecorderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recorderControllerProvider);
    final controller = ref.read(recorderControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 68, 20, 24),
      children: [
        Text('Record a memo', style: textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Say who you spoke to, what happened, and what comes next.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              children: [
                Text(
                  formatDuration(state.elapsed),
                  style: textTheme.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                Waveform(levels: state.levels),
                const SizedBox(height: 24),
                _RecordButton(
                  recording: state.isRecording,
                  busy: state.phase == RecorderPhase.requestingPermission ||
                      state.phase == RecorderPhase.stopping,
                  onPressed: state.isRecording ? controller.stop : controller.start,
                ),
                const SizedBox(height: 16),
                Text(_hint(state), textAlign: TextAlign.center, style: textTheme.bodySmall),
                if (state.isRecording)
                  TextButton(
                    onPressed: controller.cancel,
                    child: const Text('Discard'),
                  ),
              ],
            ),
          ),
        ),
        if (state.phase == RecorderPhase.error && state.error != null) ...[
          const SizedBox(height: 16),
          _ErrorCard(
            message: state.error!,
            showSettings: state.permanentlyDenied,
            onSettings: controller.openSettings,
            onDismiss: controller.reset,
          ),
        ],
        const SizedBox(height: 28),
        Text('Recent memos', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        const RecentMemosList(),
      ],
    );
  }

  static String _hint(RecorderState state) => switch (state.phase) {
        RecorderPhase.idle => 'Tap to start. Around a minute is plenty.',
        RecorderPhase.requestingPermission => 'Waiting for microphone access…',
        RecorderPhase.recording when state.nearLimit =>
          'Wrap it up — recording stops automatically at 2:30.',
        RecorderPhase.recording => 'Listening. Tap to finish.',
        RecorderPhase.stopping => 'Saving…',
        RecorderPhase.saved => 'Saved on your phone. Ringly is on it.',
        RecorderPhase.error => 'Tap to try again.',
      };
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.busy, required this.onPressed});

  final bool recording;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: recording ? 'Stop recording' : 'Start recording',
      child: Material(
        color: recording ? Colors.red.shade400 : AppColors.accent,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            width: 88,
            height: 88,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onAccent),
                  )
                : Icon(
                    recording ? Icons.stop_rounded : Icons.mic,
                    size: 40,
                    color: AppColors.onAccent,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.showSettings,
    required this.onSettings,
    required this.onDismiss,
  });

  final String message;
  final bool showSettings;
  final VoidCallback onSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showSettings)
                  TextButton(onPressed: onSettings, child: const Text('Open settings')),
                TextButton(onPressed: onDismiss, child: const Text('OK')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
