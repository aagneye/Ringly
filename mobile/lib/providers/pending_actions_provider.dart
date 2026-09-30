import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data_providers.dart';

/// Number of things waiting for the user's tap: email drafts to approve plus
/// reminders due today. Drives the badge on the Actions tab.
///
/// Derived from `/api/today`, so it stays zero (badge hidden) while loading or
/// when the server is unreachable.
final pendingActionsCountProvider = Provider<int>(
  (ref) => ref.watch(todayProvider).value?.pendingActionCount ?? 0,
);
