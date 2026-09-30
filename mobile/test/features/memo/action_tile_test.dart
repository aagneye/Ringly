import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/models/memo_result.dart';
import 'package:ringly_mobile/features/memo/widgets/action_tile.dart';

ExecutedAction action(
  String tool,
  String status, {
  Map<String, dynamic> created = const {},
}) =>
    ExecutedAction(tool: tool, status: status, summary: '$tool $status', created: created);

void main() {
  group('undoFor', () {
    test('an applied set_reminder with a reminderId can be dismissed', () {
      final undo = undoFor(action('set_reminder', 'applied', created: {'reminderId': 'r1'}));
      expect(undo, UndoKind.dismissReminder);
    });

    test('an awaiting draft_email with a draftId can be discarded', () {
      final undo = undoFor(action('draft_email', 'awaiting_approval', created: {'draftId': 'x1'}));
      expect(undo, UndoKind.discardDraft);
    });

    test('update_deal, schedule_event and lookup_company have no undo', () {
      expect(undoFor(action('update_deal', 'applied', created: {'dealId': 'd1'})), isNull);
      expect(undoFor(action('schedule_event', 'applied', created: {'eventId': 'e1'})), isNull);
      expect(undoFor(action('lookup_company', 'applied')), isNull);
    });

    test('a failed reminder cannot be undone', () {
      expect(undoFor(action('set_reminder', 'failed', created: {'reminderId': 'r1'})), isNull);
    });

    test('a reminder that is only awaiting approval has no undo', () {
      expect(undoFor(action('set_reminder', 'awaiting_approval', created: {'reminderId': 'r1'})), isNull);
    });

    test('a set_reminder without a reminderId has nothing to dismiss', () {
      expect(undoFor(action('set_reminder', 'applied')), isNull);
    });

    test('a draft_email without a draftId has nothing to discard', () {
      expect(undoFor(action('draft_email', 'awaiting_approval')), isNull);
    });
  });
}
