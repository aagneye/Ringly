import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/today.dart';
import '../../home/widgets/home_section.dart';

/// One email draft awaiting the human tap.
///
/// Shows the recipient, the subject in bold, an expandable body preview, the
/// model's reasoning if present, and the three choices: approve (opens the
/// mail client), edit (opens the edit sheet), or discard. When the draft has
/// no contact email on file it warns that the user will add the recipient in
/// their mail app — [buildMailto] still produces a valid blank-recipient link.
class DraftCard extends StatefulWidget {
  const DraftCard({
    super.key,
    required this.draft,
    required this.busy,
    required this.onApprove,
    required this.onEdit,
    required this.onDiscard,
  });

  final PendingDraft draft;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onDiscard;

  @override
  State<DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<DraftCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final draft = widget.draft;
    final hasEmail = draft.contactEmail != null && draft.contactEmail!.isNotEmpty;
    final recipient = hasEmail
        ? '${draft.contactName} <${draft.contactEmail}>'
        : draft.contactName;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To: $recipient',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            draft.subject,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            draft.body,
            maxLines: _expanded ? null : 6,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _expanded ? 'Show less' : 'Show more',
                style: textTheme.bodySmall?.copyWith(color: AppColors.accent),
              ),
            ),
          ),
          if (draft.reasoning != null && draft.reasoning!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Why: ${draft.reasoning}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (!hasEmail) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No email on file — you\'ll add the recipient in your mail app',
                    style: textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (widget.busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Row(
              children: [
                TextButton(onPressed: widget.onDiscard, child: const Text('Discard')),
                const Spacer(),
                TextButton(onPressed: widget.onEdit, child: const Text('Edit')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: widget.onApprove,
                  child: const Text('Approve & open mail'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
