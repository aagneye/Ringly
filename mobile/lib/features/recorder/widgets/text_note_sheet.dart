import 'package:flutter/material.dart';

/// The type-instead fallback: for a noisy room, a denied microphone, or a
/// server that can't transcribe right now. Returns the text, or null if
/// cancelled.
Future<String?> showTextNoteSheet(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _TextNoteSheet(),
    );

class _TextNoteSheet extends StatefulWidget {
  const _TextNoteSheet();

  @override
  State<_TextNoteSheet> createState() => _TextNoteSheetState();
}

class _TextNoteSheetState extends State<_TextNoteSheet> {
  static const _maxChars = 20000; // matches the server's limit
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Type a note', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Same as a voice memo — who, what happened, what\'s next.', style: textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            maxLength: _maxChars,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Spoke to Priya at Northwind. She wants the proposal by Friday…',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text.trim()),
            child: const Text('Send to Ringly'),
          ),
        ],
      ),
    );
  }
}
