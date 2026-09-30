import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/mailto.dart';
import '../../data/models/today.dart';
import '../../providers/api_providers.dart';
import '../../providers/data_providers.dart';

/// Opens a URI in an external app. Injectable so tests can substitute a fake
/// that records the URI and returns success/failure without a real launch.
///
/// Defaults to url_launcher's [launchUrl] in external-application mode, which
/// hands a `mailto:` link to the user's own mail client — the one place in
/// Ringly where an irreversible action (sending mail) can begin, and even then
/// only after the human taps Send in their own app.
typedef MailLauncher = Future<bool> Function(Uri uri);

final mailLauncherProvider = Provider<MailLauncher>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The set of draft/reminder ids the user has resolved this session.
///
/// Kept separate from the server snapshot so a tapped item disappears
/// immediately (optimistic removal) while the network call is in flight, and
/// can be restored if that call fails.
class ResolvedIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String id) => state = {...state, id};

  void remove(String id) => state = {...state}..remove(id);
}

final resolvedIdsProvider =
    NotifierProvider<ResolvedIds, Set<String>>(ResolvedIds.new);

/// Actions the approval queue can take. Every method removes the item
/// optimistically, performs the network call, and either commits (invalidating
/// [todayProvider] so the badge and lists refresh) or restores the item and
/// rethrows so the screen can show an error.
class ActionsController {
  ActionsController(this._ref);

  final Ref _ref;

  ResolvedIds get _resolved => _ref.read(resolvedIdsProvider.notifier);

  /// Approve an email draft: open the user's mail client first, and only if
  /// that launch succeeds record the approval on the server. If the launch
  /// fails we do NOT mark it approved — nothing was sent — and rethrow so the
  /// screen tells the user. [editedSubject]/[editedBody] override the draft's
  /// stored text when the user edited it before approving.
  Future<void> approve(
    PendingDraft draft, {
    String? editedSubject,
    String? editedBody,
  }) async {
    final subject = editedSubject ?? draft.subject;
    final body = editedBody ?? draft.body;

    final uri = buildMailto(to: draft.contactEmail, subject: subject, body: body);
    final launched = await _ref.read(mailLauncherProvider)(uri);
    if (!launched) {
      throw const MailLaunchException();
    }

    _resolved.add(draft.id);
    try {
      await _ref.read(draftsRepositoryProvider).approve(
            draft.id,
            subject: editedSubject,
            body: editedBody,
          );
      _ref.invalidate(todayProvider);
    } catch (_) {
      _resolved.remove(draft.id);
      rethrow;
    }
  }

  /// Throw the draft away. Reversible on the server (it was never sent), so it
  /// applies immediately.
  Future<void> discard(PendingDraft draft) async {
    _resolved.add(draft.id);
    try {
      await _ref.read(draftsRepositoryProvider).discard(draft.id);
      _ref.invalidate(todayProvider);
    } catch (_) {
      _resolved.remove(draft.id);
      rethrow;
    }
  }

  /// Mark a reminder done (status 'done').
  Future<void> completeReminder(TodayReminder reminder) =>
      _setReminderStatus(reminder, done: true);

  /// Dismiss a reminder (status 'dismissed'). There is no snooze endpoint, so
  /// the queue offers Done and Dismiss only rather than a snooze that would
  /// quietly map to dismiss.
  Future<void> dismissReminder(TodayReminder reminder) =>
      _setReminderStatus(reminder, done: false);

  Future<void> _setReminderStatus(TodayReminder reminder, {required bool done}) async {
    _resolved.add(reminder.id);
    try {
      final repo = _ref.read(remindersRepositoryProvider);
      await (done ? repo.complete(reminder.id) : repo.dismiss(reminder.id));
      _ref.invalidate(todayProvider);
    } catch (_) {
      _resolved.remove(reminder.id);
      rethrow;
    }
  }
}

final actionsControllerProvider =
    Provider<ActionsController>(ActionsController.new);

/// Thrown when the mail client could not be opened, so the caller can show a
/// message and leave the draft un-approved.
class MailLaunchException implements Exception {
  const MailLaunchException();

  @override
  String toString() => 'Could not open your mail app.';
}
