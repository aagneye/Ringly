import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_message.dart';
import '../../core/theme/app_colors.dart';
import '../../core/transcription/model_download_service.dart';
import '../../core/transcription/whisper_manifest.dart';
import '../../features/settings/settings_providers_local.dart';
import '../../providers/transcription_providers.dart';

/// A row for one downloadable Whisper model.
///
/// Shows size and RAM, and one of three states: not downloaded (Download
/// button, which warns about size first), downloading (progress bar + cancel),
/// or installed (Delete button). When no on-device engine ships in this build
/// it adds a subtitle making clear the model can't be used yet.
class ModelDownloadTile extends ConsumerStatefulWidget {
  const ModelDownloadTile({super.key, required this.model});

  final WhisperModelInfo model;

  @override
  ConsumerState<ModelDownloadTile> createState() => _ModelDownloadTileState();
}

class _ModelDownloadTileState extends ConsumerState<ModelDownloadTile> {
  double? _progress; // null unless a download is in flight
  CancelToken? _cancel;
  String? _error;

  WhisperModelInfo get model => widget.model;

  Future<void> _confirmAndDownload() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download model'),
        content: Text('This downloads ${model.sizeMb} MB. Use Wi-Fi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    await _download();
  }

  Future<void> _download() async {
    final downloader = await ref.read(modelDownloadServiceProvider.future);
    final cancel = CancelToken();
    setState(() {
      _progress = 0;
      _cancel = cancel;
      _error = null;
    });
    try {
      await downloader.download(
        model,
        cancelToken: cancel,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _progress = received / total);
          }
        },
      );
      ref.invalidate(installedModelIdsProvider);
    } on ChecksumMismatchException {
      if (mounted) {
        setState(() => _error = 'Downloaded file was corrupt. Try again.');
      }
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e) && mounted) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _progress = null;
          _cancel = null;
        });
      }
    }
  }

  Future<void> _delete() async {
    final downloader = await ref.read(modelDownloadServiceProvider.future);
    await downloader.delete(model.id);
    ref.invalidate(installedModelIdsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final engineAvailable = ref.watch(onDeviceEngineProvider).isAvailable;
    final installed = ref.watch(installedModelIdsProvider).value ?? const [];
    final isInstalled = installed.contains(model.id);
    final downloading = _progress != null;

    final subtitleLines = <String>['${model.sizeMb} MB · needs ${model.ramMb} MB RAM'];
    if (!engineAvailable) {
      subtitleLines.add(
        'Downloaded models will be used once the on-device engine ships in this build.',
      );
    }
    if (_error != null) subtitleLines.add(_error!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(model.label, style: textTheme.bodyLarge),
          subtitle: Text(subtitleLines.join('\n'), style: textTheme.bodySmall),
          isThreeLine: subtitleLines.length > 1,
          trailing: _trailing(isInstalled, downloading),
        ),
        if (downloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              backgroundColor: AppColors.surfaceMuted,
            ),
          ),
      ],
    );
  }

  Widget _trailing(bool isInstalled, bool downloading) {
    if (downloading) {
      return IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel',
        onPressed: () => _cancel?.cancel(),
      );
    }
    if (isInstalled) {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: _delete,
      );
    }
    return TextButton(
      onPressed: _confirmAndDownload,
      child: const Text('Download'),
    );
  }
}
