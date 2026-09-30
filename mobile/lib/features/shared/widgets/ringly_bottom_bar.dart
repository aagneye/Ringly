import 'package:flutter/material.dart';
import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import 'nav_destinations.dart';

/// The white bottom bar with a raised circular Record button in the centre.
///
/// Built by hand rather than with [NavigationBar] because the Record action
/// needs to break the bar's top edge — it is the one tap the whole product is
/// designed around, so it must read as primary, not as a fifth equal tab.
class RinglyBottomBar extends StatelessWidget {
  const RinglyBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.actionsBadgeCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Pending approvals. Shown on the Actions tab; hidden when zero.
  final int actionsBadgeCount;

  static const double barHeight = 64;
  static const double recordSize = 60;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: barHeight + bottomInset + recordSize / 3,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: barHeight + bottomInset,
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < kNavDestinations.length; i++)
                  Expanded(
                    child: kNavDestinations[i].isPrimary
                        // Leave the slot empty; the raised button sits above it.
                        ? const SizedBox.shrink()
                        : _NavTab(
                            spec: kNavDestinations[i],
                            selected: i == selectedIndex,
                            badgeCount: kNavDestinations[i].routeName ==
                                    AppRoutes.actions
                                ? actionsBadgeCount
                                : 0,
                            onTap: () => onSelected(i),
                          ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: _RecordButton(
              selected: kNavDestinations[selectedIndex.clamp(0, 4)].isPrimary,
              onTap: () =>
                  onSelected(kNavDestinations.indexWhere((d) => d.isPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.spec,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final NavDestinationSpec spec;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '${spec.label}, $badgeCount pending' : spec.label,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text('$badgeCount'),
              backgroundColor: AppColors.accent,
              child: Icon(
                selected ? spec.selectedIcon : spec.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              spec.label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Record a memo',
      child: Material(
        color: AppColors.accent,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.surface, width: 4),
        ),
        elevation: 4,
        shadowColor: AppColors.accent.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: RinglyBottomBar.recordSize,
            height: RinglyBottomBar.recordSize,
            child: Icon(Icons.mic, color: AppColors.onAccent, size: 28),
          ),
        ),
      ),
    );
  }
}
