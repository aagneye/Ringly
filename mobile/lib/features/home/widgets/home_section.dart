import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error_message.dart';
import '../../../core/theme/app_colors.dart';

/// A titled block on the Home screen, with an optional trailing link.
class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: textTheme.titleMedium)),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A white rounded panel used as the body of most sections.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading, error and
/// "not configured" states, so every section degrades the same way when the
/// backend is down or missing a key.
class AsyncSectionBody<T> extends StatelessWidget {
  const AsyncSectionBody({
    super.key,
    required this.value,
    required this.builder,
    this.loadingHeight = 72,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    // Show stale data while a refresh is in flight rather than flashing a
    // spinner over content the user was already reading.
    final data = value.value;
    if (data != null && !value.hasError) return builder(data);

    if (value.hasError) {
      final error = value.error!;
      return SectionNotice(
        icon: isNotConfigured(error) ? Icons.settings_outlined : Icons.cloud_off_outlined,
        message: friendlyError(error),
      );
    }

    return SizedBox(
      height: loadingHeight,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// A quiet one-line message in a card: empty states, setup notices, errors.
class SectionNotice extends StatelessWidget {
  const SectionNotice({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
