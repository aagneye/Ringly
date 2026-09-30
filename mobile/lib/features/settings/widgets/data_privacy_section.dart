import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/memo/local_memo.dart';
import '../../../providers/memo_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/transcription_providers.dart';
import '../settings_providers_local.dart';
import 'settings_section.dart';

/// "Data & privacy": local-only mode, the offline outbox count, and the
/// destructive "delete all memos on this phone" action.
class DataPrivacySection extends ConsumerWidget {
  const DataPrivacySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final engineAvailable = ref.watch(onDeviceEngineProvider).isAvailable;
    final installed = ref.watch(installedModelIdsProvider).value ?? const [];
    final canLocalOnly = engineAvailable && installed.isNotEmpty;

    final memos = ref.watch(memosProvider).value ?? const <LocalMemo>[];
    final pending = memos
        .where((m) =>
            m.status == MemoStatus.pending || m.status == MemoStatus.syncing)
        .length;

    return SettingsSection(
      title: 'Data & privacy',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Local-only mode'),
          subtitle: Text(
            canLocalOnly
                ? 'Audio never leaves this phone. Transcription runs on-device only; memos are refused if it can\'t.'
                : 'Needs an on-device model and engine before it can be turned on.',
          ),
          value: settings.localOnlyMode,
          onChanged: canLocalOnly
              ? (v) => controller.apply((s) => s.copyWith(localOnlyMode: v))
              : null,
        ),
        const Divider(height: 1, color: AppColors.border),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Offline outbox'),
          subtitle: Text(
            pending == 0 ? 'Nothing waiting to send' : '$pending waiting to send',
          ),
          trailing: pending == 0
              ? null
              : CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    '$pending',
                    style: const TextStyle(color: AppColors.onAccent, fontSize: 12),
                  ),
                ),
        ),
        const Divider(height: 1, color: AppColors.border),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Delete all memos on this phone'),
          subtitle: Text('$_memoWord${memos.length}'),
          trailing: const Icon(Icons.delete_outline),
          onTap: memos.isEmpty ? null : () => _confirmDelete(context, ref, memos),
        ),
      ],
    );
  }

  static const _memoWord = 'Local memos: ';

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    List<LocalMemo> memos,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all memos?'),
        content: Text(
          'This removes ${memos.length} memo(s) and their audio from this phone. '
          'Anything already synced to the server is not affected. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final store = await ref.read(memoStoreProvider.future);
    for (final memo in memos) {
      await store.delete(memo.id);
    }
    ref.invalidate(memosProvider);
  }
}
