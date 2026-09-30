import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/dashboard_card.dart';

/// The dashboard shown after a successful login or signup.
///
/// A greeting header followed by a two-column grid of placeholder cards. Each
/// card is a stand-in for a real feature surface (today's calls, pipeline,
/// drafts, etc.) and will be wired to live data in a later phase.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      // Leave room at the top so content clears the floating menu button.
      padding: const EdgeInsets.fromLTRB(20, 68, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Here is what needs your attention today.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.95,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              DashboardCard(
                icon: Icons.today_outlined,
                title: 'Today',
                subtitle: '3 calls to review',
              ),
              DashboardCard(
                icon: Icons.view_kanban_outlined,
                title: 'Pipeline',
                subtitle: '8 active deals',
              ),
              DashboardCard(
                icon: Icons.drafts_outlined,
                title: 'Drafts',
                subtitle: '2 awaiting approval',
              ),
              DashboardCard(
                icon: Icons.notifications_none,
                title: 'Reminders',
                subtitle: '1 due soon',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent activity', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          const _ActivityPlaceholder(),
        ],
      ),
    );
  }
}

/// A wide placeholder card standing in for a future activity feed.
class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.timeline, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your recent calls and actions will show up here.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
