import 'package:flutter/material.dart';

import '../../../data/models/today.dart';

/// A bottom sheet for editing a draft's subject and body before approving it.
///
/// Returns the edited [PendingDraft] (via [PendingDraft.copyWith]) when the
/// user taps Save, or null if they dismiss the sheet. The edit stays local —
/// nothing is sent to the server until the user approves.
Future<PendingDraft?> showEditDraftSheet(
  BuildContext context,
  PendingDraft draft,
) {
  return showModalBottomSheet<PendingDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => EditDraftSheet(draft: draft),
  );
}

class EditDraftSheet extends StatefulWidget {
  const EditDraftSheet({super.key, required this.draft});

  final PendingDraft draft;

  @override
  State<EditDraftSheet> createState() => _EditDraftSheetState();
}

class _EditDraftSheetState extends State<EditDraftSheet> {
  late final TextEditingController _subject =
      TextEditingController(text: widget.draft.subject);
  late final TextEditingController _body =
      TextEditingController(text: widget.draft.body);

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      widget.draft.copyWith(subject: _subject.text, body: _body.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Lift the sheet above the keyboard.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit email', style: textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            decoration: const InputDecoration(labelText: 'Body'),
            minLines: 4,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
