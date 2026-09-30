import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/precall_brief.dart';
import '../../../providers/deal_providers.dart';

/// Opens the pre-call brief for [dealId] as a draggable modal sheet.
///
/// The brief is the highest-value screen in the product: five minutes before a
/// call, what do I need to know? It calls a Balanced-tier model server-side and
/// can take most of a minute, so the loading state names what's happening
/// rather than showing a bare spinner.
Future<void> showPrecallBrief(BuildContext context, String dealId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _PrecallBriefSheet(
        dealId: dealId,
        scrollController: scrollController,
      ),
    ),
  );
}

class _PrecallBriefSheet extends ConsumerWidget {
  const _PrecallBriefSheet({required this.dealId, required this.scrollController});

  final String dealId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brief = ref.watch(precallBriefProvider(dealId));
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: brief.when(
        loading: () => _LoadingBody(scrollController: scrollController),
        error: (error, _) => _ErrorBody(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(precallBriefProvider(dealId)),
          scrollController: scrollController,
        ),
        data: (data) => _BriefBody(brief: data, scrollController: scrollController),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const _Grabber(),
        const SizedBox(height: 40),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 24),
        Text(
          'Nemotron Super is reading your notes…',
          style: textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'This can take up to a minute. It\'s reading every call you\'ve had with this person.',
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.scrollController,
  });

  final String message;
  final VoidCallback onRetry;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const _Grabber(),
        const SizedBox(height: 40),
        Icon(Icons.error_outline, color: Colors.red.shade400),
        const SizedBox(height: 12),
        Text(message, style: textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

class _BriefBody extends StatelessWidget {
  const _BriefBody({required this.brief, required this.scrollController});

  final PrecallBrief brief;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final who = [
      brief.contactName,
      if (brief.company != null && brief.company!.isNotEmpty) brief.company!,
    ].join(' · ');

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const _Grabber(),
        const SizedBox(height: 8),
        Text(who, style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text('Pre-call brief · Nemotron Super', style: textTheme.bodySmall),
        const SizedBox(height: 20),
        if (brief.firstConversation)
          const _Banner(
            icon: Icons.waving_hand_outlined,
            text: 'First conversation — nothing on file yet.',
          ),
        if (brief.whereWeAre.isNotEmpty) ...[
          _SectionTitle('Where we are'),
          Text(brief.whereWeAre, style: textTheme.bodyMedium),
          const SizedBox(height: 20),
        ],
        if (brief.theyCareAbout.isNotEmpty) ...[
          _SectionTitle('They care about'),
          for (final item in brief.theyCareAbout) _Bullet(item),
          const SizedBox(height: 20),
        ],
        if (brief.youPromised.isNotEmpty) ...[
          _SectionTitle('You promised'),
          for (final promise in brief.openPromises) _PromiseRow(promise: promise),
          const SizedBox(height: 20),
        ],
        if (brief.askAbout.isNotEmpty) ...[
          _SectionTitle('Ask about'),
          for (var i = 0; i < brief.askAbout.length; i++)
            _Numbered(index: i + 1, text: brief.askAbout[i]),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

class _Numbered extends StatelessWidget {
  const _Numbered({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$index.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({required this.promise});

  final Promise promise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final done = promise.appearsDone;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size: 20,
            color: done ? AppColors.accent : Colors.red.shade400,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(promise.promise, style: textTheme.bodyMedium),
                if (!done)
                  Text(
                    'Not done yet',
                    style: textTheme.bodySmall?.copyWith(color: Colors.red.shade400),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
}
