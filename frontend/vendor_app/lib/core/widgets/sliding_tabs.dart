// Tab controls with one smooth, shared motion (like the student app's category pills): the selection indicator
// slides to the tapped tab and the label colours cross-fade. Tabs are equal width, so no measuring is needed.
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

const _duration = Duration(milliseconds: 300);
const _curve = Curves.easeOutCubic;

enum SlidingTabsStyle {
  /// A filled teal pill slides on a white track (period switches, metric toggles).
  pill,

  /// A teal underline slides under the labels (filter tabs at the top of a list).
  underline,
}

class SlidingTabs extends StatelessWidget {
  const SlidingTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.style = SlidingTabsStyle.pill,
    this.height = 32,
    this.fontSize = 12.5,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final SlidingTabsStyle style;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final pill = style == SlidingTabsStyle.pill;
    final n = labels.length;
    // Alignment of the selected slot: -1 (first) .. 1 (last).
    final x = n == 1 ? 0.0 : -1 + 2 * selected / (n - 1);

    final tabs = Stack(children: [
      // The indicator
      Positioned.fill(
        child: AnimatedAlign(
          duration: _duration,
          curve: _curve,
          alignment: Alignment(x, pill ? 0 : 1),
          child: FractionallySizedBox(
            widthFactor: 1 / n,
            heightFactor: 1,
            child: pill
                ? Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 0.6,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
          ),
        ),
      ),
      // The labels
      Row(children: [
        for (var i = 0; i < n; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (i != selected) onChanged(i);
              },
              child: SizedBox(
                height: height,
                child: Center(
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      end: i == selected ? (pill ? AppColors.white : AppColors.primary) : AppColors.textSecondary,
                    ),
                    duration: _duration,
                    curve: _curve,
                    builder: (_, color, __) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: color),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    ]);

    if (!pill) return tabs;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: tabs,
    );
  }
}

/// One tab in [AnimatedDock].
class DockItem {
  const DockItem({required this.icon, required this.activeIcon, required this.label, this.badge = 0});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

/// The bottom navigation: a soft teal pill slides behind the active tab, its icon pops from outline to filled
/// and lifts a little, and the label colour fades in.
class AnimatedDock extends StatelessWidget {
  const AnimatedDock({super.key, required this.items, required this.currentIndex, required this.onTap});
  final List<DockItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    final x = n == 1 ? 0.0 : -1 + 2 * currentIndex / (n - 1);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Stack(children: [
            // Sliding highlight behind the active icon
            Positioned.fill(
              top: 6,
              bottom: 24,
              child: AnimatedAlign(
                duration: _duration,
                curve: _curve,
                alignment: Alignment(x, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  child: Center(
                    child: Container(
                      width: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < n; i++) Expanded(child: _tab(items[i], i == currentIndex, () => onTap(i))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _tab(DockItem item, bool active, VoidCallback tap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedSlide(
          duration: _duration,
          curve: _curve,
          offset: active ? const Offset(0, -0.06) : Offset.zero,
          child: SizedBox(
            height: 28,
            child: Center(
              child: Badge(
                isLabelVisible: item.badge > 0,
                label: Text('${item.badge}'),
                child: AnimatedSwitcher(
                  duration: _duration,
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    key: ValueKey(active),
                    size: 22,
                    color: active ? AppColors.primary : AppColors.grey500,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: active ? AppColors.primary : AppColors.grey500),
          duration: _duration,
          curve: _curve,
          builder: (_, color, __) => Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color),
          ),
        ),
      ]),
    );
  }
}
