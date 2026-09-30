import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/settings/app_settings.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/transcription_providers.dart';
import '../../transcription/model_download_tile.dart';
import '../settings_providers_local.dart';
import 'settings_section.dart';

/// The "Voice & Transcription" group: pick where transcription runs, download
/// on-device models, and toggle silence trimming.
///
/// On-device and Auto are disabled until a model is downloaded AND a native
/// engine is available — otherwise the option would be a lie. The subtitle
/// explains which of the two is missing.
class VoiceSection extends ConsumerWidget {
  const VoiceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final engineAvailable = ref.watch(onDeviceEngineProvider).isAvailable;
    final installed = ref.watch(installedModelIdsProvider).value ?? const [];
    final manifest = ref.watch(whisperManifestProvider);

    final modelPresent = installed.contains(settings.whisperModelId) ||
        installed.isNotEmpty;
    final onDeviceReady = modelPresent && engineAvailable;

    String? disabledReason() {
      if (onDeviceReady) return null;
      if (!engineAvailable) {
        return 'Needs the on-device engine, which isn\'t in this build yet.';
      }
      return 'Download a model below to enable this.';
    }

    void setMode(TranscriptionMode mode) =>
        controller.apply((s) => s.copyWith(transcriptionMode: mode));

    return SettingsSection(
      title: 'Voice & transcription',
      children: [
        _ModeTile(
          mode: TranscriptionMode.cloud,
          groupValue: settings.transcriptionMode,
          title: 'Cloud',
          subtitle: 'Nemotron Omni on Nebius — best accuracy',
          onChanged: setMode,
        ),
        _ModeTile(
          mode: TranscriptionMode.onDevice,
          groupValue: settings.transcriptionMode,
          title: 'On-device',
          subtitle: onDeviceReady
              ? 'Whisper on your phone — works offline, audio never leaves the device'
              : disabledReason()!,
          enabled: onDeviceReady,
          onChanged: setMode,
        ),
        _ModeTile(
          mode: TranscriptionMode.auto,
          groupValue: settings.transcriptionMode,
          title: 'Auto',
          subtitle: onDeviceReady
              ? 'On-device when offline, cloud otherwise'
              : disabledReason()!,
          enabled: onDeviceReady,
          onChanged: setMode,
        ),
        const Divider(height: 1, color: AppColors.border),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-trim silence'),
          subtitle: const Text('Cut quiet gaps from recordings before saving'),
          value: settings.autoTrimSilence,
          onChanged: (v) => controller.apply((s) => s.copyWith(autoTrimSilence: v)),
        ),
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: manifest.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Couldn\'t load the model list.'),
            ),
            data: (m) => Column(
              children: [
                for (final model in m.models) ModelDownloadTile(model: model),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A radio-style row for one transcription mode.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.onChanged,
    this.enabled = true,
  });

  final TranscriptionMode mode;
  final TranscriptionMode groupValue;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<TranscriptionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<TranscriptionMode>(
      contentPadding: EdgeInsets.zero,
      value: mode,
      groupValue: groupValue,
      title: Text(title),
      subtitle: Text(subtitle),
      onChanged: enabled ? (v) => onChanged(v as TranscriptionMode) : null,
    );
  }
}
