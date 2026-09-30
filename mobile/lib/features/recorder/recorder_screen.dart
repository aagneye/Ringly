import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../memo/memo_result_screen.dart';
import '../memo/submission_controller.dart';
import 'recorder_controller.dart';
import 'widgets/recent_memos_list.dart';
import 'widgets/text_note_sheet.dart';
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
                  onPressed: state.isRecording
                      ? () => _stopAndSend(context, ref)
                      : controller.start,
                ),
                const SizedBox(height: 16),
                Text(_hint(state), textAlign: TextAlign.center, style: textTheme.bodySmall),
                if (state.isRecording)
                  TextButton(
                    onPressed: controller.cancel,
                    child: const Text('Discard'),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _typeNote(context, ref),
                    icon: const Icon(Icons.keyboard_outlined, size: 18),
                    label: const Text('Type a note instead'),
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
        RecentMemosList(onOpen: (memo) => openMemoResult(context, memo)),
      ],
    );
  }

  /// Stop, then hand off: the memo is already on disk, so sending runs in the
  /// background while the result screen shows progress.
  static Future<void> _stopAndSend(BuildContext context, WidgetRef ref) async {
    final memo = await ref.read(recorderControllerProvider.notifier).stop();
    if (memo == null || !context.mounted) return;
    unawaited(ref.read(submissionControllerProvider.notifier).submit(memo));
    ref.read(recorderControllerProvider.notifier).reset();
    openMemoResult(context, memo);
  }

  static Future<void> _typeNote(BuildContext context, WidgetRef ref) async {
    final text = await showTextNoteSheet(context);
    if (text == null || !context.mounted) return;
    final submission = ref.read(submissionControllerProvider.notifier);
    final memo = await submission.saveTextNote(text);
    unawaited(submission.submit(memo));
    if (context.mounted) openMemoResult(context, memo);
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
