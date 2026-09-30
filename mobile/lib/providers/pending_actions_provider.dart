import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Number of things waiting for the user's tap: email drafts to approve plus
/// reminders due today. Drives the badge on the Actions tab.
///
/// Starts at zero; the Actions feature overrides the source once the approval
/// queue is loaded from `/api/today`.
final pendingActionsCountProvider = Provider<int>((ref) => 0);
